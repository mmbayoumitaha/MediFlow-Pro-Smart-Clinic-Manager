#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${GCLOUD_PROJECT:-}" != "demo-mediflow" || -z "${FIREBASE_AUTH_EMULATOR_HOST:-}" || -z "${FIRESTORE_EMULATOR_HOST:-}" ]]; then
  echo 'Run through Auth/Firestore emulators for demo-mediflow only.' >&2
  exit 1
fi
task_driver_port="${MEDIFLOW_DRIVER_PORT:-14444}"
chromedriver --port="$task_driver_port" > /tmp/mediflow-spark-chromedriver.log 2>&1 &
task_driver_pid=$!
trap 'kill "$task_driver_pid" 2>/dev/null || true; wait "$task_driver_pid" 2>/dev/null || true' EXIT
for ((attempt=0; attempt<50; attempt++)); do
  if ! kill -0 "$task_driver_pid" 2>/dev/null; then exit 1; fi
  if curl --silent --fail "http://127.0.0.1:$task_driver_port/status" > /dev/null; then break; fi
  sleep .1
done
flutter drive --no-pub -d web-server --headless --browser-name=chrome \
  --chrome-binary="${CHROME_EXECUTABLE:-/usr/bin/chromium}" --driver-port="$task_driver_port" \
  --driver=test_driver/integration_test.dart --target=integration_test/spark_registration_test.dart \
  --dart-define-from-file=config/firebase.emulator.json
