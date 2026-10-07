#!/usr/bin/env bash
# Local: build-commit.sh COMMIT TAG -> campfire-reference:TAG on the box from apps/rails-opt at COMMIT.
set -euo pipefail
commit=$1 tag=$2
cd ~/Projects/campfire-perf/apps/rails-opt
git archive "$commit" | ssh ${BOX:?set BOX=user@host} "rm -rf /opt/campfire-perf/apps/build-$tag && mkdir -p /opt/campfire-perf/apps/build-$tag && tar -x -C /opt/campfire-perf/apps/build-$tag && cd /opt/campfire-perf/apps/build-$tag && flock /tmp/campfire-bench.lock docker buildx build --load --network host --label org.opencontainers.image.revision=$(git rev-parse "$commit") -t campfire-reference:$tag . > /tmp/build-$tag.log 2>&1 && echo built campfire-reference:$tag || { tail -20 /tmp/build-$tag.log; exit 1; }"
