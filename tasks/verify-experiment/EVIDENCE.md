# Verify an experiment — evidence

## Command

One command runs the analysis and its verification against the real PostgreSQL and MongoDB
containers (stack started with `./start.sh`; rebuild with `./start.sh --build` after code changes,
because the image contains the source code):

~~~bash
./verify-experiment.sh [--timeout SECONDS] [--expected-model-sha256 HEX] [--experiment-id ID]
~~~

It runs `docker exec teracyte-api uv run python -m tests.e2e_verify "$@"`, without `-t`,
so it works in CI and passes the verifier's exit status through.
Without the wrapper, from a shell where `POSTGRES_URL`/`MONGO_URL` reach the databases, run:
`python -m tests.e2e_verify`.

| Exit status | Meaning |
|---|---|
| 0 | all checks passed |
| 1 | analysis ran, at least one result check failed |
| 2 | analysis runner exited nonzero |
| 3 | analysis exceeded the timeout and was killed |
| 4 | setup error (fixtures, database connection, invalid digest argument) |

## What tests/e2e_verify.py does

1. **Setup (not timed):** generates fixtures if `data/manifest.json` is missing and works out the expected digest:
   - from `--expected-model-sha256` or `EXPECTED_MODEL_SHA256`, if one is supplied;
   - otherwise as the SHA-256 of the fixture model file listed in the manifest, computed before the pipeline runs.

   The expected digest never comes from output rows.
2. **Isolation:** each run uses a new ID, `e2e-<UTC timestamp>-<random>`. Before the run, any MongoDB document, PostgreSQL rows, work directory and masks for that ID are deleted, so stale results can't satisfy the checks, even with a reused `--experiment-id`.
3. **Timed run:** starts `python -m scripts.run_local --experiment-id <id>` in its own process group and times it with `time.monotonic()`. The default limit is 180 s; change it with `--timeout` or `E2E_TIMEOUT_SECONDS`. On timeout the whole process group is sent SIGTERM, then SIGKILL, so step subprocesses don't keep running.
4. **Checks:**
   - PostgreSQL `image_metrics` has exactly 5 rows for the ID, `image-001` through `image-005`.
   - Every row's `model_sha256` equals the expected digest.
   - Metrics are in range: `foreground_fraction` between 0 and 1, `mean_intensity` between 0 and 255.
   - The MongoDB document has `status == "COMPLETED"` and `result_count == 5`.

The file is deliberately not named `test_*.py`, so the unit suite (`pytest -q`, 6 passed) doesn't collect it. It needs live databases.

## Successful five-image run

Per-step JSON lines from the runner are omitted for brevity.

~~~text
$ ./verify-experiment.sh
[e2e] fixtures missing; generating (not timed)
[e2e] experiment_id=e2e-20261125T192251Z-dc4e96
[e2e] expected model_sha256=70b292c8f995c6aa958263c61bbfd4a96a3334466f78b158f7f5015035cbf95f (computed from fixture /app/data/model/model.weights)
[e2e] running: /app/.venv/bin/python -m scripts.run_local --experiment-id e2e-20261125T192251Z-dc4e96 (timeout 180s)
{"experiment_id": "e2e-20261125T192251Z-dc4e96", "written": 5}
{"experiment_id": "e2e-20261125T192251Z-dc4e96", "image_count": 5, "status": "COMPLETED"}
[e2e] pipeline elapsed 5.69s (monotonic clock, limit 180s)
[e2e] PASS  postgres: exactly 5 rows -- found 5
[e2e] PASS  postgres: image ids are image-001..image-005 -- found ['image-001', 'image-002', 'image-003', 'image-004', 'image-005']
[e2e] PASS  postgres: every model_sha256 matches expected digest -- expected 70b292c8f995c6aa958263c61bbfd4a96a3334466f78b158f7f5015035cbf95f
[e2e] PASS  postgres: metrics in range (fraction 0..1, intensity 0..255)
[e2e] PASS  mongo: status COMPLETED -- found 'COMPLETED'
[e2e] PASS  mongo: result_count == 5 -- found 5
[e2e] RESULT: PASSED
{"experiment_id": "e2e-20261125T192251Z-dc4e96", "elapsed_seconds": 5.69, "timeout_seconds": 180.0, "result": "PASSED", "failed_checks": []}
exit status: 0
~~~

The pipeline took **5.69 s**, well under the 180 s default, so the default was not changed.
This was measured on a laptop with Docker Desktop; the number will differ on other machines.

## Deliberately failing check: wrong expected digest

~~~text
$ ./verify-experiment.sh --expected-model-sha256 0000000000000000000000000000000000000000000000000000000000000000
[e2e] experiment_id=e2e-20261125T192304Z-75403d
[e2e] expected model_sha256=0000000000000000000000000000000000000000000000000000000000000000 (supplied)
[e2e] pipeline elapsed 5.47s (monotonic clock, limit 180s)
[e2e] PASS  postgres: exactly 5 rows -- found 5
[e2e] PASS  postgres: image ids are image-001..image-005 -- found [...]
[e2e] FAIL  postgres: every model_sha256 matches expected digest -- expected 0000000000000000000000000000000000000000000000000000000000000000; mismatched rows ['image-001', 'image-002', 'image-003', 'image-004', 'image-005']: ['70b292c8f995c6aa958263c61bbfd4a96a3334466f78b158f7f5015035cbf95f']
[e2e] PASS  postgres: metrics in range (fraction 0..1, intensity 0..255)
[e2e] PASS  mongo: status COMPLETED -- found 'COMPLETED'
[e2e] PASS  mongo: result_count == 5 -- found 5
[e2e] RESULT: FAILED (1 check(s))
{"experiment_id": "e2e-20261125T192304Z-75403d", "elapsed_seconds": 5.47, "timeout_seconds": 180.0, "result": "FAILED", "failed_checks": ["postgres: every model_sha256 matches expected digest"]}
exit status: 1
~~~

## Extra negative case: timeout enforcement

~~~text
$ ./verify-experiment.sh --timeout 2
[e2e] running: /app/.venv/bin/python -m scripts.run_local --experiment-id e2e-20261125T192310Z-1de7a7 (timeout 2s)
[e2e] pipeline elapsed 2.01s (monotonic clock, limit 2s)
[e2e] RESULT: TIMEOUT -- pipeline terminated after 2.01s
{"experiment_id": "e2e-20261125T192310Z-1de7a7", "elapsed_seconds": 2.01, "timeout_seconds": 2.0, "result": "TIMEOUT"}
exit status: 3
~~~

Afterwards, a scan of `/proc` inside the container found no `run_local` or `pipelines.steps` processes left running.

## Limits

- The verifier runs inside the `api` container because the image has no source bind mount. Code changes need `./start.sh --build` before verifying.
- The default expected digest is computed from the fixture model, which checks that the pipeline recorded the artifact it was given. To pin a specific released model, pass its published digest with `--expected-model-sha256` or `EXPECTED_MODEL_SHA256`. The model-handoff task does this.
- Elapsed time covers only the analysis run (`scripts/run_local`). Builds, fixture generation, database startup and the reset step are excluded.
- Exit status 2 (analysis failure) is implemented but wasn't demonstrated here.
- E2E experiment records stay in the databases for inspection. Unique IDs keep them from affecting later runs.
