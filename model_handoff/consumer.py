"""Consumer side of the handoff, used by Dev's analysis runner.

Dependency-free on purpose (hashlib/json only) so production steps do not import any
Data/ML training code. Selection is configuration: MODEL_SELECTION_FILE points at a
channel file such as data/model-registry/toy-linear/channels/production.json.
"""

import hashlib
import json
import os
from pathlib import Path

from . import CHANNEL_SCHEMA

SELECTION_ENV = "MODEL_SELECTION_FILE"


class SelectionError(RuntimeError):
    """The configured model selection is missing, malformed or fails its digest check."""


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_selection(selection_file: Path) -> dict:
    """Read a channel file without touching the artifact (used for the expected digest)."""
    try:
        channel = json.loads(Path(selection_file).read_text())
    except FileNotFoundError as error:
        raise SelectionError(f"model selection file not found: {selection_file}") from error
    except json.JSONDecodeError as error:
        raise SelectionError(f"model selection file is not valid JSON: {selection_file}") from error
    if channel.get("schema") != CHANNEL_SCHEMA:
        raise SelectionError(f"unsupported channel schema in {selection_file}: {channel.get('schema')!r}")
    for field in ("model", "version", "sha256", "artifact"):
        if not channel.get(field):
            raise SelectionError(f"channel {selection_file} is missing {field!r}")
    return channel


def resolve_selection(selection_file: Path) -> dict:
    """Return the selected artifact after verifying its bytes against the selected digest."""
    selection_file = Path(selection_file)
    channel = read_selection(selection_file)
    # channels/<name>.json lives in the model directory; artifact paths are relative to it,
    # so the same registry works on the host, in a container or synced from object storage.
    model_dir = selection_file.resolve().parent.parent
    artifact = (model_dir / channel["artifact"]).resolve()
    if model_dir not in artifact.parents:
        raise SelectionError(f"artifact path escapes the model directory: {channel['artifact']}")
    if not artifact.is_file():
        raise SelectionError(f"selected artifact not found: {artifact}")
    actual = sha256_file(artifact)
    if actual != channel["sha256"]:
        raise SelectionError(
            f"selected artifact digest mismatch for {channel['model']} {channel['version']}: "
            f"expected {channel['sha256']}, found {actual}"
        )
    return {
        "source": "selection",
        "selection_file": str(selection_file),
        "model": channel["model"],
        "version": channel["version"],
        "path": str(artifact),
        "sha256": actual,
    }


def resolve_model(fixture_model_path: str | Path) -> dict:
    """Resolve the model for an analysis run.

    MODEL_SELECTION_FILE set  -> the selected, digest-verified release (fails loudly if broken).
    MODEL_SELECTION_FILE unset -> the generated fixture weights (original starter behaviour).
    """
    selection_file = os.getenv(SELECTION_ENV, "").strip()
    if selection_file:
        return resolve_selection(Path(selection_file))
    path = Path(fixture_model_path)
    return {"source": "fixture", "model": "fixture", "version": None, "path": str(path), "sha256": sha256_file(path)}
