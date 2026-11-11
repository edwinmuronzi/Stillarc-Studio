#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
simulator_id="${1:?Pass a booted simulator UDID}"
derived_dir="${TMPDIR:-/tmp}/StillarcStudioQA"
bundle_id="com.edwinmuronzipersonalteam.StillarcStudio"
xcodebuild -project StillarcStudio.xcodeproj -scheme StillarcStudio -configuration Debug -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath "$derived_dir" build > "$derived_dir.log" 2>&1
xcrun simctl install "$simulator_id" "$derived_dir/Build/Products/Debug-iphonesimulator/StillarcStudio.app"
data_dir="$(xcrun simctl get_app_container "$simulator_id" "$bundle_id" data)"
rm -f "$data_dir/Documents/studio-verification.json" "$data_dir/Documents/preview-verification.json"
xcrun simctl launch --terminate-running-process "$simulator_id" "$bundle_id" --verify-studio --demo-editor --verify-preview
for attempt in $(seq 1 60); do
  if [[ -f "$data_dir/Documents/preview-verification.json" ]]; then break; fi
  sleep 1
done
python3 - "$data_dir" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1]) / 'Documents'
correctness = json.loads((root / 'studio-verification.json').read_text())
preview = json.loads((root / 'preview-verification.json').read_text())
assert correctness['passed'], correctness
assert preview['gpuFailures'] == 0, preview
assert preview['extraIdleFrames'] == 0, preview
assert preview['rendered'] > 0, preview
print(json.dumps({'correctness': correctness, 'preview': preview}, indent=2))
PY
