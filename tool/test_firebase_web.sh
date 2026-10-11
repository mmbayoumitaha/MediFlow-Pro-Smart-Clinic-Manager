#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export MEDIFLOW_SPARK_TARGET=workflows
exec bash tool/test_spark_web.sh
