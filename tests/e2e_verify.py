"""End-to-end verification of one experiment against real PostgreSQL and MongoDB.

Runs scripts/run_local.py for a fresh experiment ID, enforces a wall-clock timeout
measured with a monotonic clock, then checks the persisted results.

Usage (from the repository root, where POSTGRES_URL / MONGO_URL reach the databases):

    python -m tests.e2e_verify [--timeout 180] [--expected-model-sha256 HEX] [--experiment-id ID]

Exit codes:
    0  every check passed
    1  the analysis ran but at least one result check failed
    2  the analysis process exited with an error
    3  the analysis exceeded the timeout and was terminated
    4  setup error (fixtures, database connectivity, invalid arguments)

This file is deliberately not named test_*.py: it needs live databases and is run as a
command, not collected by the unit-test suite.
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
EXPECTED_IMAGE_IDS = [f"image-{number:03d}" for number in range(1, 6)]
DEFAULT_TIMEOUT_SECONDS = 180.0

EXIT_OK, EXIT_CHECK_FAILED, EXIT_ANALYSIS_FAILED, EXIT_TIMEOUT, EXIT_SETUP = 0, 1, 2, 3, 4


def log(message: str) -> None:
    print(f"[e2e] {message}", flush=True)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def database_urls() -> tuple[str, str]:
    # Same variables and defaults as the pipeline steps (Compose service names).
    postgres_url = os.getenv("POSTGRES_URL", "postgresql://starter:starter@postgres:5432/experiments")
    mongo_url = os.getenv("MONGO_URL", "mongodb://mongo:27017")
    return postgres_url, mongo_url


def prepare_fixtures() -> dict:
    """Generate fixtures if absent. Runs before the timer starts."""
    from scripts.generate_mock_data import generate_data

    manifest_path = DATA_DIR / "manifest.json"
    if not manifest_path.exists():
        log("fixtures missing; generating (not timed)")
        generate_data(DATA_DIR)
    return json.loads(manifest_path.read_text())


def reset_experiment_state(experiment_id: str, postgres_url: str, mongo_url: str) -> None:
    """Remove any state for this ID so stale results cannot satisfy the checks."""
    import psycopg
    from pymongo import MongoClient

    with MongoClient(mongo_url, serverSelectionTimeoutMS=5000) as mongo:
        mongo["experiments"]["experiments"].delete_one({"_id": experiment_id})
    with psycopg.connect(postgres_url, connect_timeout=5) as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT to_regclass('image_metrics')")
            if cursor.fetchone()[0] is not None:
                cursor.execute("DELETE FROM image_metrics WHERE experiment_id = %s", (experiment_id,))
    shutil.rmtree(DATA_DIR / "work" / experiment_id, ignore_errors=True)
    shutil.rmtree(DATA_DIR / "objects" / "masks" / experiment_id, ignore_errors=True)


def terminate_tree(process: subprocess.Popen) -> None:
    """Stop the runner and the step subprocesses it started."""
    if os.name == "posix":
        for sig in (signal.SIGTERM, signal.SIGKILL):
            try:
                os.killpg(process.pid, sig)
            except ProcessLookupError:
                return
            try:
                process.wait(timeout=5)
                return
            except subprocess.TimeoutExpired:
                continue
    else:
        subprocess.run(["taskkill", "/F", "/T", "/PID", str(process.pid)], capture_output=True)
        process.wait()


def run_analysis(experiment_id: str, timeout: float) -> tuple[str, float, int | None]:
    """Run the pipeline; return (outcome, elapsed_seconds, returncode)."""
    command = [sys.executable, "-m", "scripts.run_local", "--experiment-id", experiment_id]
    log(f"running: {' '.join(command)} (timeout {timeout:g}s)")
    started = time.monotonic()
    process = subprocess.Popen(command, cwd=ROOT, start_new_session=(os.name == "posix"))
    try:
        returncode = process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        terminate_tree(process)
        return "timeout", time.monotonic() - started, None
    elapsed = time.monotonic() - started
    return ("ok" if returncode == 0 else "failed"), elapsed, returncode


class Checks:
    def __init__(self) -> None:
        self.results: list[dict] = []

    def check(self, name: str, passed: bool, detail: str = "") -> None:
        self.results.append({"check": name, "passed": bool(passed), "detail": detail})
        log(f"{'PASS' if passed else 'FAIL'}  {name}" + (f" -- {detail}" if detail else ""))

    @property
    def passed(self) -> bool:
        return all(item["passed"] for item in self.results)


def verify_results(experiment_id: str, expected_sha256: str, postgres_url: str, mongo_url: str) -> Checks:
    import psycopg
    from pymongo import MongoClient

    checks = Checks()
    with psycopg.connect(postgres_url, connect_timeout=5) as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT image_id, foreground_fraction, mean_intensity, model_sha256 "
                "FROM image_metrics WHERE experiment_id = %s ORDER BY image_id",
                (experiment_id,),
            )
            rows = cursor.fetchall()

    image_ids = [row[0] for row in rows]
    checks.check("postgres: exactly 5 rows", len(rows) == 5, f"found {len(rows)}")
    checks.check("postgres: image ids are image-001..image-005", image_ids == EXPECTED_IMAGE_IDS, f"found {image_ids}")
    wrong_digest = [row[0] for row in rows if row[3] != expected_sha256]
    checks.check(
        "postgres: every model_sha256 matches expected digest",
        bool(rows) and not wrong_digest,
        f"expected {expected_sha256}" + (f"; mismatched rows {wrong_digest}: {sorted({r[3] for r in rows})}" if wrong_digest else ""),
    )
    bad_metrics = [row[0] for row in rows if not (0.0 <= row[1] <= 1.0 and 0.0 <= row[2] <= 255.0)]
    checks.check(
        "postgres: metrics in range (fraction 0..1, intensity 0..255)",
        bool(rows) and not bad_metrics,
        f"out of range: {bad_metrics}" if bad_metrics else "",
    )

    with MongoClient(mongo_url, serverSelectionTimeoutMS=5000) as mongo:
        experiment = mongo["experiments"]["experiments"].find_one({"_id": experiment_id})
    experiment = experiment or {}
    checks.check("mongo: status COMPLETED", experiment.get("status") == "COMPLETED", f"found {experiment.get('status')!r}")
    checks.check("mongo: result_count == 5", experiment.get("result_count") == 5, f"found {experiment.get('result_count')!r}")
    return checks


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the analysis and verify results in PostgreSQL and MongoDB")
    parser.add_argument("--experiment-id", help="default: e2e-<UTC timestamp>-<random suffix>, unique per run")
    parser.add_argument(
        "--timeout", type=float,
        default=float(os.getenv("E2E_TIMEOUT_SECONDS", DEFAULT_TIMEOUT_SECONDS)),
        help="pipeline timeout in seconds (default 180, env E2E_TIMEOUT_SECONDS)",
    )
    parser.add_argument(
        "--expected-model-sha256",
        default=os.getenv("EXPECTED_MODEL_SHA256"),
        help="expected model digest (env EXPECTED_MODEL_SHA256); default: SHA-256 of the fixture model, "
             "computed before the pipeline runs",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.timeout <= 0:
        log("--timeout must be positive")
        return EXIT_SETUP
    experiment_id = args.experiment_id or (
        f"e2e-{datetime.now(timezone.utc):%Y%m%dT%H%M%SZ}-{uuid.uuid4().hex[:6]}"
    )
    postgres_url, mongo_url = database_urls()

    # --- Setup: not part of the timed window ---------------------------------------
    try:
        manifest = prepare_fixtures()
        if args.expected_model_sha256:
            expected_sha256 = args.expected_model_sha256.strip().lower()
            source = "supplied"
        else:
            expected_sha256 = sha256_file(Path(manifest["model_path"]))
            source = f"computed from fixture {manifest['model_path']}"
        if not re.fullmatch(r"[0-9a-f]{64}", expected_sha256):
            log(f"expected digest is not a SHA-256 hex string: {expected_sha256!r}")
            return EXIT_SETUP
        reset_experiment_state(experiment_id, postgres_url, mongo_url)
    except Exception as error:  # noqa: BLE001 - report any setup problem as a setup failure
        log(f"setup failed: {type(error).__name__}: {error}")
        return EXIT_SETUP
    log(f"experiment_id={experiment_id}")
    log(f"expected model_sha256={expected_sha256} ({source})")

    # --- Timed pipeline execution ---------------------------------------------------
    outcome, elapsed, returncode = run_analysis(experiment_id, args.timeout)
    log(f"pipeline elapsed {elapsed:.2f}s (monotonic clock, limit {args.timeout:g}s)")
    summary = {"experiment_id": experiment_id, "elapsed_seconds": round(elapsed, 2), "timeout_seconds": args.timeout}
    if outcome == "timeout":
        log(f"RESULT: TIMEOUT -- pipeline terminated after {elapsed:.2f}s")
        print(json.dumps({**summary, "result": "TIMEOUT"}))
        return EXIT_TIMEOUT
    if outcome == "failed":
        log(f"RESULT: ANALYSIS FAILED -- runner exited with status {returncode}")
        print(json.dumps({**summary, "result": "ANALYSIS_FAILED", "returncode": returncode}))
        return EXIT_ANALYSIS_FAILED

    # --- Result checks --------------------------------------------------------------
    try:
        checks = verify_results(experiment_id, expected_sha256, postgres_url, mongo_url)
    except Exception as error:  # noqa: BLE001
        log(f"verification could not query databases: {type(error).__name__}: {error}")
        return EXIT_SETUP
    failed = [item["check"] for item in checks.results if not item["passed"]]
    log("RESULT: " + ("PASSED" if checks.passed else f"FAILED ({len(failed)} check(s))"))
    print(json.dumps({**summary, "result": "PASSED" if checks.passed else "FAILED", "failed_checks": failed}))
    return EXIT_OK if checks.passed else EXIT_CHECK_FAILED


if __name__ == "__main__":
    sys.exit(main())
