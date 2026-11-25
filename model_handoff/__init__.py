"""Local model handoff between Data/ML (producer) and Dev (consumer).

Ownership: shared contract, maintained by DevOps/MLOps. Changes here run both the
Dev workflow (ci-core-dev.yml) and the Data/ML workflow (ci-data-ml.yml).

Registry layout (MODEL_REGISTRY_DIR, default data/model-registry):

    <registry>/<model>/candidates/<version>/model.json      published artifact (immutable)
    <registry>/<model>/candidates/<version>/evaluation.json evaluation report
    <registry>/<model>/candidates/<version>/handoff.json    handoff metadata
    <registry>/<model>/gate/<version>.json                  ACCEPTED / REJECTED gate record
    <registry>/<model>/channels/production.json             selected version (+ history)

Publishing a candidate never changes a channel. Only `promote` does, and only for an
ACCEPTED candidate whose artifact still matches the accepted digest.
"""

HANDOFF_SCHEMA = "model-handoff-v1"
CHANNEL_SCHEMA = "model-channel-v1"
GATE_SCHEMA = "model-gate-v1"
