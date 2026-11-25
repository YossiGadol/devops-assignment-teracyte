# Notebook-to-model delivery — evidence

[Task](README.md) · [Design (diagram, handoff contract, promotion/rollback, provider move, ownership)](DESIGN.md)

All output below was captured on 2026-11-25 on Windows 11 + Git Bash + Docker Desktop. The stack ran from the rebuilt `api-image` (`./start.sh --build`). Long JSON is trimmed where marked.

## What was added

| Piece | Owner | Purpose |
|---|---|---|
| `model_handoff/` (`registry.py`, `consumer.py`, `policy.json`, CLI `python -m model_handoff`) | Shared | train (with environment record) → publish → accept/reject → promote/rollback → resolve |
| `model-handoff.sh` | Shared | Runs the CLI in the api container (the training image), on the `data-model-registry` volume |
| `scripts/run_local.py`, `pipelines/steps/ml_infer/run.py`, `services/api/main.py` | Dev | Select the model through `MODEL_SELECTION_FILE`, verify the digest before work, record `model{source,model,version,sha256}` in MongoDB and return it from the API |
| `tests/e2e_verify.py` | Dev | Expected digest comes from the channel record when a selection is configured. New check: the MongoDB model digest |
| `tests/test_model_handoff.py` | Shared | 8 tests: publish ≠ select, immutability, digest/threshold/misreported-metric rejections, rollback, consumer tamper detection |
| `compose.yaml` | Shared runtime | `data-model-registry` volume, `MODEL_REGISTRY_DIR`, `MODEL_SELECTION_FILE` (empty = fixture weights) |
| `.github/workflows/ci-core-dev.yml`, `ci-data-ml.yml` | Dev / Data/ML | See [Ownership](#which-workflow-owns-which-change) |

## 1. Train, evaluate and benchmark

~~~text
$ ./model-handoff.sh train --run-dir data/model-lifecycle/runs/r1
{
  "environment": {
    "accelerator": "cpu",
    "code_revision": "224fbdb27ffeeb62fc7fb657c48876a1ea390849",
    "command": "python -m model_handoff train",
    "image": "api-image",
    "numpy": "2.5.5",
    "platform": "Linux-6.18.58.1-microsoft-standard-WSL2-x86_64-with-glibc2.41",
    "python": "3.15.2",
    "trained_at": "2026-11-25T19:59:04+00:00"
  },
  "evaluation": {
    "baseline_test_mse": 2.6468672472,
    "dataset": "synthetic-linear-v1",
    "seed": 2026,
    "test_mse": 0.000111415,
    "test_rows": 64,
    "train_rows": 128
  },
  "run_dir": "data/model-lifecycle/runs/r1"
}
~~~

`train` calls the supplied `run_experiment` unchanged. **Benchmark:** held-out MSE is 0.000111 for the model against 2.647 for the training-mean baseline, about 23,800× lower. A second run (`r2`) produced byte-identical `model.json` (same SHA-256), so the training is reproducible within this image. `code_revision` is HEAD; the working tree was uncommitted at the time.

## 2. Publish the candidate with handoff metadata (does not select it)

~~~text
$ ./model-handoff.sh publish --run-dir data/model-lifecycle/runs/r1 --version 1.0.0
{
  "artifact": {
    "format": "toy-linear-v1",
    "media_type": "application/json",
    "path": "model.json",
    "sha256": "40bfe02753cb2b202f626f9d672dc49be7f780d7b17542cb9b8986604d48b10f",
    "size_bytes": 175,
    "uri": "toy-linear/candidates/1.0.0/model.json"
  },
  "contract": {
    "input": {"dtype": "finite float", "features": ["feature_a", "feature_b"], "shape": "(n, 2)"},
    "loader": "examples.model_lifecycle.train:load_model",
    "output": {"dtype": "float", "meaning": "one regression prediction per row", "shape": "(n,)"}
  },
  "evaluation": {
    "baseline_test_mse": 2.6468672472, "dataset": "synthetic-linear-v1", "metric": "test_mse",
    "path": "evaluation.json", "seed": 2026,
    "sha256": "2f9a6be9de28ad5db77b4339a1efe22acfa4381fd0a0bd8e1fede7ed21f87463",
    "test_mse": 0.000111415
  },
  "model": "toy-linear",
  "published_at": "2026-11-25T19:59:04+00:00",
  "schema": "model-handoff-v1",
  "status": "candidate",
  "training": { ...same as environment above... },
  "version": "1.0.0"
}

$ ./model-handoff.sh status
{
  "candidates": {"1.0.0": "NOT_GATED"},
  "model": "toy-linear",
  "production": null,
  "registry": "/app/data/model-registry"
}
~~~

(Nested objects are collapsed onto one line here; the command prints them indented.)

## 3. Gate, then promote

~~~text
$ ./model-handoff.sh accept --version 1.0.0
[gate] PASS  handoff metadata complete
[gate] PASS  artifact digest matches handoff -- handoff 40bfe027…b10f, artifact 40bfe027…b10f
[gate] PASS  evaluation report digest matches handoff
[gate] PASS  artifact format -- found 'toy-linear-v1'
[gate] PASS  supplied loader accepts artifact -- format toy-linear-v1, features ['feature_a', 'feature_b']
[gate] PASS  prediction contract (n, 2) -> (n,) -- output shape (3,)
[gate] PASS  evaluation dataset identity -- synthetic-linear-v1 seed 2026
[gate] PASS  re-evaluated test_mse matches report -- reported 0.000111415, re-evaluated 0.000111415
[gate] PASS  test_mse threshold -- 0.000111415 <= 0.001
[gate] PASS  beats baseline -- 0.000111415 <= 2.6468672472 x 0.01
{"failed_checks": [], "model": "toy-linear", "sha256": "40bfe02753cb2b202f626f9d672dc49be7f780d7b17542cb9b8986604d48b10f", "status": "ACCEPTED", "version": "1.0.0"}
exit 0

$ ./model-handoff.sh promote --version 1.0.0 --reason "first toy release"
{
  "artifact": "candidates/1.0.0/model.json",
  "channel": "production",
  "format": "toy-linear-v1",
  "history": [{"action": "promote", "at": "2026-11-25T19:59:05+00:00", "by": "yossi",
               "reason": "first toy release", "sha256": "40bfe027…b10f", "version": "1.0.0"}],
  "model": "toy-linear",
  "previous_version": null,
  "schema": "model-channel-v1",
  "sha256": "40bfe02753cb2b202f626f9d672dc49be7f780d7b17542cb9b8986604d48b10f",
  "updated_at": "2026-11-25T19:59:05+00:00",
  "version": "1.0.0"
}
~~~

The loader and prediction checks are the toy artifact being loaded through its **supplied helper** (`load_model`, `predict`, `evaluate`).

## 4. Selected digest in the pipeline results (configuration only)

~~~text
$ MODEL_SELECTION_FILE=/app/data/model-registry/toy-linear/channels/production.json ./verify-experiment.sh --experiment-id handoff-demo
[e2e] experiment_id=handoff-demo
[e2e] expected model_sha256=40bfe02753cb2b202f626f9d672dc49be7f780d7b17542cb9b8986604d48b10f (selected toy-linear 1.0.0 via /app/data/model-registry/toy-linear/channels/production.json)
[e2e] running: /app/.venv/bin/python -m scripts.run_local --experiment-id handoff-demo (timeout 180s)
{"model_source": "selection", "model": "toy-linear", "model_version": "1.0.0", "model_sha256": "40bfe02753cb2b202f626f9d672dc49be7f780d7b17542cb9b8986604d48b10f", "model_path": "/app/data/model-registry/toy-linear/candidates/1.0.0/model.json"}
... per-step JSON lines omitted ...
{"experiment_id": "handoff-demo", "written": 5}
{"experiment_id": "handoff-demo", "image_count": 5, "status": "COMPLETED"}
[e2e] pipeline elapsed 5.87s (monotonic clock, limit 180s)
[e2e] PASS  postgres: exactly 5 rows -- found 5
[e2e] PASS  postgres: image ids are image-001..image-005 -- found ['image-001', 'image-002', 'image-003', 'image-004', 'image-005']
[e2e] PASS  postgres: every model_sha256 matches expected digest -- expected 40bfe02753cb2b202f626f9d672dc49be7f780d7b17542cb9b8986604d48b10f
[e2e] PASS  postgres: metrics in range (fraction 0..1, intensity 0..255)
[e2e] PASS  mongo: status COMPLETED -- found 'COMPLETED'
[e2e] PASS  mongo: result_count == 5 -- found 5
[e2e] PASS  mongo: recorded model digest matches expected -- found 'toy-linear' '1.0.0' '40bfe02753cb2b202f626f9d672dc49be7f780d7b17542cb9b8986604d48b10f'
[e2e] RESULT: PASSED
exit 0

$ ./show-results.sh handoff-demo
{
  "experiment_id": "handoff-demo",
  "status": "COMPLETED",
  "model": {"source": "selection", "model": "toy-linear", "version": "1.0.0",
            "sha256": "40bfe02753cb2b202f626f9d672dc49be7f780d7b17542cb9b8986604d48b10f"},
  "results": [
    {"image_id": "image-001", "foreground_fraction": 0.501758, "mean_intensity": 191.511,
     "model_sha256": "40bfe02753cb2b202f626f9d672dc49be7f780d7b17542cb9b8986604d48b10f"},
    ... image-002 … image-005, same model_sha256 ...
  ]
}
~~~

The expected digest is read from the channel record, not from the artifact or the output rows. The image pipeline is a mock: this proves **selection and digest propagation**, not model accuracy. Accuracy evidence is the gate's re-evaluation in step 3.

Without `MODEL_SELECTION_FILE`, the original behaviour is unchanged:

~~~text
$ ./verify-experiment.sh
[e2e] expected model_sha256=70b292c8f995c6aa958263c61bbfd4a96a3334466f78b158f7f5015035cbf95f (computed from fixture /app/data/model/model.weights)
...
[e2e] PASS  mongo: recorded model digest matches expected -- found 'fixture' None '70b292c8…f95f'
[e2e] RESULT: PASSED
exit 0
~~~

## 5. Rejected handoff (digest mismatch, before acceptance)

Candidate 1.1.0 was published correctly. Its stored bytes were then altered, simulating corruption or substitution between publication and review. The gate runs before the candidate can be accepted, so it is never selectable:

~~~text
$ ./model-handoff.sh publish --run-dir data/model-lifecycle/runs/r2 --version 1.1.0 | jq -c .artifact
{"format":"toy-linear-v1","media_type":"application/json","path":"model.json","sha256":"40bfe02753cb2b202f626f9d672dc49be7f780d7b17542cb9b8986604d48b10f","size_bytes":175,"uri":"toy-linear/candidates/1.1.0/model.json"}

$ docker exec teracyte-api sed -i 's/"intercept": 2.0/"intercept": 2.5/' data/model-registry/toy-linear/candidates/1.1.0/model.json

$ ./model-handoff.sh accept --version 1.1.0
[gate] PASS  handoff metadata complete
[gate] FAIL  artifact digest matches handoff -- handoff 40bfe02753cb2b202f626f9d672dc49be7f780d7b17542cb9b8986604d48b10f, artifact af3a74bd0be287133721175429b0796f272add45161f0335edc032f5f3d0acb8
{"failed_checks": ["artifact digest matches handoff"], "model": "toy-linear", "sha256": "40bfe027…b10f", "status": "REJECTED", "version": "1.1.0"}
exit 1

$ ./model-handoff.sh promote --version 1.1.0
[handoff] REFUSED: toy-linear 1.1.0 is REJECTED; only ACCEPTED candidates can be selected
exit 2

$ ./model-handoff.sh status
{"candidates": {"1.0.0": "ACCEPTED", "1.1.0": "REJECTED"}, "model": "toy-linear",
 "production": {"sha256": "40bfe027…b10f", "version": "1.0.0"}, "registry": "/app/data/model-registry"}
~~~

The gate stops at the digest failure and never loads or scores unverified bytes. Unit tests also cover a **failed evaluation threshold** (coefficients halved, report regenerated consistently → `test_mse threshold` and `beats baseline` fail), a **misreported metric** and a **producer digest mismatch** (`--expected-sha256`).

## 6. Promotion and rollback

~~~text
$ ./model-handoff.sh promote --version 1.2.0 --reason "release 1.2.0" | jq -c "{version, previous_version, sha256}"
{"version":"1.2.0","previous_version":"1.0.0","sha256":"40bfe02753cb2b202f626f9d672dc49be7f780d7b17542cb9b8986604d48b10f"}

$ ./model-handoff.sh rollback --reason "rollback drill" | jq -c "{version, previous_version, history: [.history[] | {action, version}]}"
{"version":"1.0.0","previous_version":"1.2.0","history":[{"action":"promote","version":"1.0.0"},{"action":"promote","version":"1.2.0"},{"action":"rollback","version":"1.0.0"}]}

$ ./model-handoff.sh rollback --to-version 1.1.0
[handoff] REFUSED: toy-linear 1.1.0 is REJECTED; only ACCEPTED candidates can be selected
exit 2
~~~

1.2.0 was accepted first (all 10 checks passed). Training is deterministic, so 1.0.0 and 1.2.0 have the same digest. The drill shows the selection mechanics only.

## 7. Unit tests

~~~text
$ docker exec teracyte-api uv run python -m pytest -q
..............                                                           [100%]
14 passed in 0.40s
~~~

## 8. CI workflows

### Which workflow owns which change

| Change | Example paths | Workflow → jobs/steps |
|---|---|---|
| Application (API, Celery) | `services/**` | `ci-core-dev` → build image, unit tests (no E2E) |
| Production analysis step | `pipelines/**`, `scripts/**`, `tests/e2e_verify.py` | `ci-core-dev` → build, unit tests, E2E (fixture model), model-consumer compatibility (train → publish → accept → promote toy model → E2E with `MODEL_SELECTION_FILE`) |
| Terraform storage | `infra/**` | `ci-core-dev` → `terraform` job: `fmt -check -recursive`, `init -backend=false`, `validate`. No credentials, plan or apply. The job only runs once `infra/` exists (Terraform task). |
| Notebook, training, evaluation | `examples/model_lifecycle/**`, `tests/test_model_lifecycle.py` | `ci-data-ml` → unit tests, train/evaluate, publish, gate, tampered negative control, assert no production selection, upload `model-candidate` |
| Model-only candidate | none (manual `workflow_dispatch` with `source_run_id`, optional `expected_sha256`) | `ci-data-ml` → download the candidate artifact, publish, gate (digest + supplied-loader contract + thresholds). No training, no image build, no selection |
| Shared code, runtime, handoff contract | `model_handoff/**`, `examples/model_lifecycle/train.py`, `Dockerfile`, `requirements-local.txt` | **Both** workflows |

Both workflows use `shell: bash` (so `-eo pipefail`, and `cmd | tee logs/x.log` still fails the step). They always upload `logs/`, and `ci-core-dev` also uploads `docker compose logs`. Dispatch inputs reach scripts only through `env:`, never inline `${{ }}`.

### Limitation: no GitHub Actions run yet

There is no `gh` CLI in this environment and the branch was not pushed, so neither workflow has run on GitHub. Instead:

**Lint** — `docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest -no-color` → exit 0 (includes shellcheck). The first version had SC2086 notices and an inlined `${{ inputs.expected_sha256 }}`; both were fixed.

**`ci-data-ml` / `candidate` job replayed locally.** A throwaway helper (not committed) parsed the workflow YAML and executed each `run:` step with `bash --noprofile --norc -eo pipefail`. It ran in a fresh copy of the working tree inside a clean container, with its own `uv venv --python 3.15`. `uses:` steps and model-only steps were skipped. Trimmed output:

~~~text
### STEP  Reproducible environment (pinned interpreter, requirements-local.txt)
... numpy==2.5.5, pillow==12.3.0, ... (uv pip freeze -> logs/environment.txt)
### STEP  Unit tests (supplied helpers + handoff gate)
11 passed in 0.41s
### STEP  Train and evaluate (benchmark against the baseline)
"test_mse": 0.000111415, "baseline_test_mse": 2.6468672472
### STEP  Publish candidate (local directory registry)
"sha256": "40bfe02753cb2b202f626f9d672dc49be7f780d7b17542cb9b8986604d48b10f", "version": "ci-local"
### STEP  Handoff gate - digest, consumer contract (supplied loader), evaluation thresholds
[gate] PASS  ... (10/10)   "status": "ACCEPTED"
### STEP  Negative control - a tampered copy must be rejected before acceptance
[gate] FAIL  artifact digest matches handoff -- handoff 40bfe027…b10f, artifact af3a74bd…acb8
"status": "REJECTED", "version": "ci-local-tampered"
[handoff] REFUSED: toy-linear ci-local-tampered is REJECTED; only ACCEPTED candidates can be selected
### STEP  Publication did not select the candidate for production
{"candidates": {"ci-local": "ACCEPTED"}, "model": "toy-linear", "production": null, ...}
### JOB SUCCEEDED
~~~

**`ci-core-dev` / `build-test-e2e` job replayed on the host** with the same approach, all E2E steps enabled:

~~~text
### STEP  Build shared image (same script as local)        BUILD_ATTESTATIONS=false BUILD_NO_CACHE=false ./build.sh
### STEP  Unit tests in the image (...)                    14 passed in 0.41s
### STEP  Start stack                                      ./start.sh  (now `up -d --wait`: all 5 containers Healthy)
### STEP  Pipeline E2E with fixture model                  [e2e] RESULT: PASSED (expected 70b292c8…f95f, fixture)
### STEP  Model-consumer compatibility - publish, gate and promote the toy model   ci-local ACCEPTED, promoted
### STEP  Pipeline E2E with the selected model (...)       [e2e] RESULT: PASSED (expected 40bfe027…b10f, selected toy-linear ci-local)
### STEP  Collect container logs                           logs/compose.log
### STEP  Stop stack
### JOB SUCCEEDED      (logs/: build, unit-tests, start, e2e-fixture, handoff, e2e-selected, compose)
~~~

**Failure propagation** through a `| tee` step, with the workflow's shell flags:

~~~text
$ bash --noprofile --norc -eo pipefail -c "./verify-experiment.sh --expected-model-sha256 000…000 2>&1 | tee logs/e2e.log"
[e2e] FAIL  postgres: every model_sha256 matches expected digest -- expected 0000…0000; mismatched rows ['image-001', …, 'image-005']: ['70b292c8…f95f']
[e2e] FAIL  mongo: recorded model digest matches expected -- found 'fixture' None '70b292c8…f95f'
[e2e] RESULT: FAILED (2 check(s))
step exit status: 1
~~~

Not verified until a real Actions run: `dorny/paths-filter` change detection, `actions/download-artifact` across runs (model-only path), and whether the runner image provides Python 3.15 through uv.

## Issue encountered: Git Bash rewrote the selection path

The first selected-model run failed in setup:

~~~text
[e2e] setup failed: SelectionError: model selection file not found: C:/Program Files/Git/app/data/model-registry/toy-linear/channels/production.json
exit 4
~~~

MSYS path conversion in Git Bash on Windows rewrote the container path `/app/...` passed to `docker exec -e`. The consumer correctly refused, with no silent fallback to the fixture. **Fix:** `export MSYS_NO_PATHCONV=1` in `verify-experiment.sh`, `run-experiment.sh` and `model-handoff.sh` (no effect on Linux/CI). **Verified:** the same command then passed (section 4), and the MongoDB check showed `toy-linear 1.0.0 40bfe027…`.

## Reproduce

~~~bash
./start.sh --build
./model-handoff.sh train   --run-dir data/model-lifecycle/runs/r1
./model-handoff.sh publish --run-dir data/model-lifecycle/runs/r1 --version 1.0.0
./model-handoff.sh accept  --version 1.0.0
./model-handoff.sh promote --version 1.0.0 --reason "first toy release"
MODEL_SELECTION_FILE=/app/data/model-registry/toy-linear/channels/production.json ./verify-experiment.sh
./show-results.sh <experiment-id>
~~~

To make a selection the default for every run, put `MODEL_SELECTION_FILE=/app/data/model-registry/toy-linear/channels/production.json` in `.env` and run `./start.sh`. The registry lives in the `data-model-registry` volume and is not in Git.
