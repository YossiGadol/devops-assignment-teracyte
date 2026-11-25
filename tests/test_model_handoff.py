import json

import pytest

from model_handoff.consumer import SelectionError, resolve_model, resolve_selection
from model_handoff.registry import HandoffError, accept, channel_file, promote, publish, rollback, status, train
from pipelines.steps.ml_infer.run import infer_image


@pytest.fixture()
def run_dir(tmp_path):
    train(tmp_path / "run")
    return tmp_path / "run"


def published(run_dir, registry, version):
    publish(run_dir, "toy-linear", version, registry)
    return registry / "toy-linear" / "candidates" / version


def test_publish_accept_promote_and_rollback(run_dir, tmp_path):
    registry = tmp_path / "registry"
    published(run_dir, registry, "1.0.0")
    assert not channel_file(registry, "toy-linear").exists(), "publication must not select a version"
    assert accept("toy-linear", "1.0.0", registry)["status"] == "ACCEPTED"
    first = promote("toy-linear", "1.0.0", registry)
    published(run_dir, registry, "1.1.0")
    assert accept("toy-linear", "1.1.0", registry)["status"] == "ACCEPTED"
    assert status("toy-linear", registry)["production"]["version"] == "1.0.0"
    promote("toy-linear", "1.1.0", registry)
    back = rollback("toy-linear", registry)
    assert back["version"] == "1.0.0" and back["sha256"] == first["sha256"]
    assert [item["action"] for item in back["history"]] == ["promote", "promote", "rollback"]
    assert resolve_selection(channel_file(registry, "toy-linear"))["version"] == "1.0.0"


def test_versions_are_immutable(run_dir, tmp_path):
    published(run_dir, tmp_path / "registry", "1.0.0")
    with pytest.raises(HandoffError, match="immutable"):
        publish(run_dir, "toy-linear", "1.0.0", tmp_path / "registry")


def test_digest_mismatch_is_rejected_and_cannot_be_promoted(run_dir, tmp_path):
    registry = tmp_path / "registry"
    candidate = published(run_dir, registry, "2.0.0")
    model = json.loads((candidate / "model.json").read_text())
    model["intercept"] += 0.5
    (candidate / "model.json").write_text(json.dumps(model))
    record = accept("toy-linear", "2.0.0", registry)
    assert record["status"] == "REJECTED"
    assert [c["check"] for c in record["checks"] if not c["passed"]] == ["artifact digest matches handoff"]
    with pytest.raises(HandoffError, match="REJECTED"):
        promote("toy-linear", "2.0.0", registry)


def test_producer_digest_must_match(run_dir, tmp_path):
    registry = tmp_path / "registry"
    published(run_dir, registry, "1.0.0")
    assert accept("toy-linear", "1.0.0", registry, expected_sha256="0" * 64)["status"] == "REJECTED"


def test_failed_threshold_is_rejected(run_dir, tmp_path):
    # Re-scaled coefficients with a consistent (re-generated) report: integrity passes, quality fails.
    model = json.loads((run_dir / "model.json").read_text())
    model["coefficients"] = [value * 0.5 for value in model["coefficients"]]
    (run_dir / "model.json").write_text(json.dumps(model))
    report = json.loads((run_dir / "evaluation.json").read_text())
    from examples.model_lifecycle.train import evaluate, load_model, make_dataset
    _, _, test_x, test_y = make_dataset()
    report["test_mse"] = evaluate(load_model(run_dir / "model.json"), test_x, test_y)
    (run_dir / "evaluation.json").write_text(json.dumps(report))
    registry = tmp_path / "registry"
    published(run_dir, registry, "0.9.0")
    failed = [c["check"] for c in accept("toy-linear", "0.9.0", registry)["checks"] if not c["passed"]]
    assert failed == ["test_mse threshold", "beats baseline"]


def test_misreported_metric_is_rejected(run_dir, tmp_path):
    report = json.loads((run_dir / "evaluation.json").read_text())
    report["test_mse"] = report["test_mse"] / 10
    (run_dir / "evaluation.json").write_text(json.dumps(report))
    registry = tmp_path / "registry"
    published(run_dir, registry, "1.0.0")
    failed = [c["check"] for c in accept("toy-linear", "1.0.0", registry)["checks"] if not c["passed"]]
    assert failed == ["re-evaluated test_mse matches report"]


def test_consumer_refuses_tampered_selection_and_falls_back_without_config(run_dir, tmp_path, monkeypatch):
    registry = tmp_path / "registry"
    candidate = published(run_dir, registry, "1.0.0")
    accept("toy-linear", "1.0.0", registry)
    promote("toy-linear", "1.0.0", registry)
    selection = channel_file(registry, "toy-linear")
    monkeypatch.setenv("MODEL_SELECTION_FILE", str(selection))
    assert resolve_model("unused")["version"] == "1.0.0"
    (candidate / "model.json").write_text("{}")
    with pytest.raises(SelectionError, match="digest mismatch"):
        resolve_model("unused")
    fixture = tmp_path / "fixture.weights"
    fixture.write_bytes(b"fixture")
    monkeypatch.setenv("MODEL_SELECTION_FILE", "")
    assert resolve_model(fixture)["source"] == "fixture"


def test_inference_step_enforces_expected_digest(tmp_path):
    import numpy as np
    from PIL import Image
    from pipelines.steps.preprocess.run import preprocess_image

    raw, mask, pre, model = (tmp_path / name for name in ("raw.png", "mask.png", "pre.json", "model.json"))
    Image.fromarray(np.array([[0, 255]], dtype=np.uint8)).save(raw)
    model.write_bytes(b"model")
    preprocess_image("exp-1", "image-1", raw, mask, pre)
    with pytest.raises(ValueError, match="does not match selected"):
        infer_image("exp-1", "image-1", raw, pre, model, tmp_path / "out.json", expected_sha256="0" * 64)
