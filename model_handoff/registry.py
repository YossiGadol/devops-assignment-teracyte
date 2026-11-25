"""Publication, acceptance gate, promotion and rollback on a local directory registry."""

import importlib
import json
import os
import platform
import re
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from . import CHANNEL_SCHEMA, GATE_SCHEMA, HANDOFF_SCHEMA
from .consumer import read_selection, sha256_file

ROOT = Path(__file__).resolve().parents[1]
POLICY_FILE = Path(__file__).with_name("policy.json")
VERSION_PATTERN = re.compile(r"[0-9A-Za-z][0-9A-Za-z._-]{0,63}\Z")
NAME_PATTERN = re.compile(r"[a-z0-9][a-z0-9-]{0,63}\Z")


class HandoffError(RuntimeError):
    """A handoff operation was refused."""


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def registry_dir(value: str | Path | None = None) -> Path:
    return Path(value or os.getenv("MODEL_REGISTRY_DIR") or ROOT / "data" / "model-registry")


def load_policy(model: str) -> dict:
    policies = json.loads(POLICY_FILE.read_text())["models"]
    if model not in policies:
        raise HandoffError(f"no policy for model {model!r}; known: {sorted(policies)}")
    return policies[model]


def write_json(path: Path, payload: dict) -> None:
    """Atomic write so a reader never sees a half-written channel or record."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    os.replace(temporary, path)


def check_names(model: str, version: str) -> None:
    if not NAME_PATTERN.fullmatch(model):
        raise HandoffError(f"invalid model name {model!r}")
    if not VERSION_PATTERN.fullmatch(version):
        raise HandoffError(f"invalid version {version!r}")


def git_revision() -> str:
    if os.getenv("GIT_COMMIT"):
        return os.environ["GIT_COMMIT"]
    try:
        return subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True,
                              check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def environment_record() -> dict:
    import numpy

    return {
        "code_revision": git_revision(),
        "python": platform.python_version(),
        "numpy": numpy.__version__,
        "platform": platform.platform(),
        "image": os.getenv("TRAINING_IMAGE", "unknown"),
        "accelerator": os.getenv("TRAINING_ACCELERATOR", "cpu"),
    }


# --- Data/ML: train ---------------------------------------------------------------------

def train(run_dir: Path) -> dict:
    """Run the supplied experiment unchanged and record the training environment beside it."""
    from examples.model_lifecycle.train import run_experiment

    report = run_experiment(run_dir)
    environment = {**environment_record(), "command": "python -m model_handoff train", "trained_at": now()}
    write_json(run_dir / "environment.json", environment)
    return {"run_dir": str(run_dir), "evaluation": report, "environment": environment}


# --- Data/ML: publish a candidate ---------------------------------------------------------

def publish(run_dir: Path, model: str, version: str, registry: Path) -> dict:
    """Copy a training run into the registry as an immutable candidate. Never selects it."""
    check_names(model, version)
    policy = load_policy(model)
    model_file, evaluation_file = run_dir / "model.json", run_dir / "evaluation.json"
    for required in (model_file, evaluation_file):
        if not required.is_file():
            raise HandoffError(f"training run is missing {required}")
    target = registry / model / "candidates" / version
    if target.exists():
        raise HandoffError(f"{model} {version} is already published; versions are immutable")

    evaluation = json.loads(evaluation_file.read_text())
    environment_file = run_dir / "environment.json"
    environment = json.loads(environment_file.read_text()) if environment_file.is_file() else {}
    feature_names = json.loads(model_file.read_text()).get("feature_names")
    handoff = {
        "schema": HANDOFF_SCHEMA,
        "model": model,
        "version": version,
        "status": "candidate",
        "published_at": now(),
        "artifact": {
            "path": "model.json",
            "uri": f"{model}/candidates/{version}/model.json",
            "media_type": "application/json",
            "format": policy["format"],
            "sha256": sha256_file(model_file),
            "size_bytes": model_file.stat().st_size,
        },
        "contract": {
            "loader": f"{policy['adapter']}:load_model",
            "input": {"features": feature_names, "shape": "(n, 2)", "dtype": "finite float"},
            "output": {"shape": "(n,)", "dtype": "float", "meaning": "one regression prediction per row"},
        },
        "evaluation": {
            "path": "evaluation.json",
            "sha256": sha256_file(evaluation_file),
            "dataset": evaluation.get("dataset"),
            "seed": evaluation.get("seed"),
            "metric": "test_mse",
            "test_mse": evaluation.get("test_mse"),
            "baseline_test_mse": evaluation.get("baseline_test_mse"),
        },
        "training": environment or {"note": "no environment.json in training run"},
    }
    staging = target.with_name(version + ".staging")
    shutil.rmtree(staging, ignore_errors=True)
    staging.mkdir(parents=True)
    shutil.copyfile(model_file, staging / "model.json")
    shutil.copyfile(evaluation_file, staging / "evaluation.json")
    write_json(staging / "handoff.json", handoff)
    os.replace(staging, target)
    return handoff


# --- Gate: accept or reject a candidate -------------------------------------------------

class Gate:
    def __init__(self) -> None:
        self.checks: list[dict] = []

    def check(self, name: str, passed: bool, detail: str = "") -> bool:
        self.checks.append({"check": name, "passed": bool(passed), "detail": detail})
        print(f"[gate] {'PASS' if passed else 'FAIL'}  {name}" + (f" -- {detail}" if detail else ""), flush=True)
        return bool(passed)

    @property
    def passed(self) -> bool:
        return bool(self.checks) and all(item["passed"] for item in self.checks)


def evaluate_candidate(candidate: Path, handoff: dict, policy: dict, expected_sha256: str | None) -> Gate:
    gate = Gate()
    artifact = candidate / handoff.get("artifact", {}).get("path", "model.json")
    report_file = candidate / handoff.get("evaluation", {}).get("path", "evaluation.json")

    # 1. Metadata and integrity: the bytes are exactly what Data/ML published.
    required = all(handoff.get(key) for key in ("schema", "model", "version", "artifact", "evaluation", "contract"))
    gate.check("handoff metadata complete", required and handoff["schema"] == HANDOFF_SCHEMA)
    published = handoff.get("artifact", {}).get("sha256")
    actual = sha256_file(artifact) if artifact.is_file() else None
    if not gate.check("artifact digest matches handoff", actual is not None and actual == published,
                      f"handoff {published}, artifact {actual}"):
        return gate  # never load or score bytes that are not the published artifact
    if expected_sha256 is not None:
        gate.check("artifact digest matches producer-supplied digest", actual == expected_sha256.lower(),
                   f"expected {expected_sha256.lower()}, artifact {actual}")
    report_digest = sha256_file(report_file) if report_file.is_file() else None
    gate.check("evaluation report digest matches handoff", report_digest == handoff["evaluation"].get("sha256"))
    if not gate.passed:
        return gate

    # 2. Consumer contract, using the supplied loader/predict helpers.
    adapter = importlib.import_module(policy["adapter"])
    gate.check("artifact format", handoff["artifact"].get("format") == policy["format"],
               f"found {handoff['artifact'].get('format')!r}")
    try:
        model = adapter.load_model(artifact)
    except ValueError as error:
        gate.check("supplied loader accepts artifact", False, str(error))
        return gate
    gate.check("supplied loader accepts artifact", True, f"format {model['format']}, features {model['feature_names']}")
    _, _, test_x, test_y = adapter.make_dataset()
    predictions = adapter.predict(model, test_x[:3])
    gate.check("prediction contract (n, 2) -> (n,)", predictions.shape == (3,), f"output shape {predictions.shape}")

    # 3. Evaluation: re-score on held-out data, then apply the approval thresholds.
    report = json.loads(report_file.read_text())
    gate.check("evaluation dataset identity", (report.get("dataset"), report.get("seed")) ==
               (policy["dataset"], policy["seed"]), f"{report.get('dataset')} seed {report.get('seed')}")
    rescored = adapter.evaluate(model, test_x, test_y)
    reported = report.get("test_mse")
    gate.check("re-evaluated test_mse matches report",
               isinstance(reported, (int, float)) and abs(rescored - reported) <= policy["reevaluation_tolerance"],
               f"reported {reported}, re-evaluated {rescored}")
    gate.check("test_mse threshold", rescored <= policy["max_test_mse"],
               f"{rescored} <= {policy['max_test_mse']}")
    baseline = report.get("baseline_test_mse")
    gate.check("beats baseline", isinstance(baseline, (int, float)) and rescored <= baseline * policy["max_mse_to_baseline_ratio"],
               f"{rescored} <= {baseline} x {policy['max_mse_to_baseline_ratio']}")
    return gate


def accept(model: str, version: str, registry: Path, expected_sha256: str | None = None) -> dict:
    """Run the handoff gate; record ACCEPTED or REJECTED. Only ACCEPTED can be promoted."""
    check_names(model, version)
    policy = load_policy(model)
    candidate = registry / model / "candidates" / version
    handoff_file = candidate / "handoff.json"
    if not handoff_file.is_file():
        raise HandoffError(f"{model} {version} is not published")
    handoff = json.loads(handoff_file.read_text())
    if (handoff.get("model"), handoff.get("version")) != (model, version):
        raise HandoffError("handoff metadata does not match its registry location")
    gate = evaluate_candidate(candidate, handoff, policy, expected_sha256)
    record = {
        "schema": GATE_SCHEMA,
        "model": model,
        "version": version,
        "status": "ACCEPTED" if gate.passed else "REJECTED",
        "sha256": handoff["artifact"].get("sha256"),
        "policy": policy,
        "checks": gate.checks,
        "decided_at": now(),
    }
    write_json(registry / model / "gate" / f"{version}.json", record)
    return record


# --- Promotion and rollback -------------------------------------------------------------

def channel_file(registry: Path, model: str, channel: str = "production") -> Path:
    return registry / model / "channels" / f"{channel}.json"


def _select(registry: Path, model: str, version: str, action: str, reason: str, channel: str) -> dict:
    check_names(model, version)
    gate_file = registry / model / "gate" / f"{version}.json"
    if not gate_file.is_file():
        raise HandoffError(f"{model} {version} has not been through the gate; run accept first")
    gate = json.loads(gate_file.read_text())
    if gate.get("status") != "ACCEPTED":
        raise HandoffError(f"{model} {version} is {gate.get('status')}; only ACCEPTED candidates can be selected")
    artifact = registry / model / "candidates" / version / "model.json"
    if not artifact.is_file() or sha256_file(artifact) != gate["sha256"]:
        raise HandoffError(f"{model} {version} artifact no longer matches its accepted digest {gate['sha256']}")
    target = channel_file(registry, model, channel)
    previous = read_selection(target) if target.is_file() else None
    history = (previous or {}).get("history", [])
    entry = {"version": version, "sha256": gate["sha256"], "action": action, "at": now(),
             "by": os.getenv("PROMOTED_BY") or os.getenv("GITHUB_ACTOR") or os.getenv("USER") or "unknown",
             "reason": reason}
    selection = {
        "schema": CHANNEL_SCHEMA,
        "model": model,
        "channel": channel,
        "version": version,
        "sha256": gate["sha256"],
        "artifact": f"candidates/{version}/model.json",
        "format": gate["policy"]["format"],
        "previous_version": previous["version"] if previous else None,
        "updated_at": entry["at"],
        "history": history + [entry],
    }
    write_json(target, selection)
    return selection


def promote(model: str, version: str, registry: Path, reason: str = "", channel: str = "production") -> dict:
    return _select(registry, model, version, "promote", reason, channel)


def rollback(model: str, registry: Path, to_version: str | None = None, reason: str = "",
             channel: str = "production") -> dict:
    """Re-select an earlier accepted version (default: the one before the current selection)."""
    target = channel_file(registry, model, channel)
    if not target.is_file():
        raise HandoffError(f"{model} has no {channel} selection to roll back")
    current = read_selection(target)
    if to_version is None:
        earlier = [item["version"] for item in current.get("history", []) if item["version"] != current["version"]]
        if not earlier:
            raise HandoffError(f"{model} has no earlier {channel} version to roll back to")
        to_version = earlier[-1]
    if to_version == current["version"]:
        raise HandoffError(f"{model} {to_version} is already selected")
    return _select(registry, model, to_version, "rollback", reason or f"rollback from {current['version']}", channel)


def status(model: str, registry: Path) -> dict:
    base = registry / model
    candidates = sorted(path.name for path in (base / "candidates").glob("*") if path.is_dir()
                        and not path.name.endswith(".staging"))
    gates = {}
    for version in candidates:
        gate_file = base / "gate" / f"{version}.json"
        gates[version] = json.loads(gate_file.read_text())["status"] if gate_file.is_file() else "NOT_GATED"
    selection = channel_file(registry, model)
    current = read_selection(selection) if selection.is_file() else None
    return {"model": model, "registry": str(registry), "candidates": gates,
            "production": {"version": current["version"], "sha256": current["sha256"]} if current else None}
