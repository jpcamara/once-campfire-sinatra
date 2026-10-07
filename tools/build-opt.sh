#!/usr/bin/env bash
# build-opt.sh [TAG] -> campfire-reference:TAG from /opt/campfire-perf/apps/rails-opt (default rails-opt)
set -euo pipefail
tag=${1:-rails-opt}
cd /opt/campfire-perf/apps/rails-opt
flock /tmp/campfire-bench.lock docker buildx build --load --network host -t "campfire-reference:$tag" . > /tmp/build-$tag.log 2>&1 \
  || { tail -30 /tmp/build-$tag.log; exit 1; }
echo "built campfire-reference:$tag"
