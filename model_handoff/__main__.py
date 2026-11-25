"""CLI: python -m model_handoff {train,publish,accept,promote,rollback,resolve,status}.

Exit status: 0 success, 1 gate rejected the candidate, 2 operation refused or invalid input.
"""

import argparse
import json
import sys
from pathlib import Path

from .consumer import SelectionError, resolve_selection
from .registry import HandoffError, accept, channel_file, promote, publish, registry_dir, rollback, status, train


def emit(payload: dict) -> None:
    print(json.dumps(payload, indent=2, sort_keys=True), flush=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m model_handoff", description=__doc__)
    parser.add_argument("--registry", help="registry directory (default: $MODEL_REGISTRY_DIR or data/model-registry)")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("train", help="Data/ML: run the supplied experiment and record its environment")
    p.add_argument("--run-dir", type=Path, required=True)

    p = sub.add_parser("publish", help="Data/ML: publish a training run as an immutable candidate (no selection)")
    p.add_argument("--run-dir", type=Path, required=True)
    p.add_argument("--model", default="toy-linear")
    p.add_argument("--version", required=True)

    p = sub.add_parser("accept", help="Gate: verify digest, consumer contract and evaluation thresholds")
    p.add_argument("--model", default="toy-linear")
    p.add_argument("--version", required=True)
    p.add_argument("--expected-sha256", help="digest communicated by the producer, checked against the artifact")

    p = sub.add_parser("promote", help="Select an ACCEPTED version for production analysis")
    p.add_argument("--model", default="toy-linear")
    p.add_argument("--version", required=True)
    p.add_argument("--reason", default="")

    p = sub.add_parser("rollback", help="Re-select the previous (or a given) ACCEPTED version")
    p.add_argument("--model", default="toy-linear")
    p.add_argument("--to-version")
    p.add_argument("--reason", default="")

    p = sub.add_parser("resolve", help="Consumer: show and digest-verify what a channel file selects")
    p.add_argument("--model", default="toy-linear")

    p = sub.add_parser("status", help="List candidates, gate decisions and the production selection")
    p.add_argument("--model", default="toy-linear")

    args = parser.parse_args(argv)
    registry = registry_dir(args.registry)
    try:
        if args.command == "train":
            emit(train(args.run_dir))
        elif args.command == "publish":
            emit(publish(args.run_dir, args.model, args.version, registry))
        elif args.command == "accept":
            record = accept(args.model, args.version, registry, args.expected_sha256)
            emit({key: record[key] for key in ("model", "version", "status", "sha256")}
                 | {"failed_checks": [c["check"] for c in record["checks"] if not c["passed"]]})
            return 0 if record["status"] == "ACCEPTED" else 1
        elif args.command == "promote":
            emit(promote(args.model, args.version, registry, args.reason))
        elif args.command == "rollback":
            emit(rollback(args.model, registry, args.to_version, args.reason))
        elif args.command == "resolve":
            emit(resolve_selection(channel_file(registry, args.model)))
        elif args.command == "status":
            emit(status(args.model, registry))
    except (HandoffError, SelectionError) as error:
        print(f"[handoff] REFUSED: {error}", file=sys.stderr, flush=True)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
