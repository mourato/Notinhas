#!/bin/bash
# Legacy compatibility wrapper. Canonical local launch: ./scripts/build_and_run.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/build_and_run.sh" --logs "$@"
