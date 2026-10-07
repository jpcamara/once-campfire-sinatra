#!/usr/bin/env bash
# Local: push apps/rails-opt and tools/ to the box.
set -euo pipefail
cd ~/Projects/campfire-perf
rsync -a --delete --exclude .git --exclude tmp --exclude log apps/rails-opt/ ${BOX:?set BOX=user@host}:/opt/campfire-perf/apps/rails-opt/
rsync -a tools/ ${BOX:?set BOX=user@host}:/opt/campfire-perf/tools/
