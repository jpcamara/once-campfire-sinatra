#!/usr/bin/env bash
# Local: build-roda.sh TAG -> campfire-roda:TAG and campfire-roda-candidate:TAG on the box, from
# apps/roda at HEAD (git archive, so only committed files), labelled with the commit.
set -euo pipefail
tag=$1
cd ~/Projects/campfire-perf/apps/roda
rev=$(git rev-parse HEAD)
git archive HEAD | ssh ${BOX:?set BOX=user@host} "set -e; d=/opt/campfire-perf/apps/roda-build-$tag; rm -rf \$d; mkdir -p \$d; tar -x -C \$d; cd \$d
  while [ -e /tmp/box-busy.sq ]; do sleep 30; done
  flock /tmp/campfire-bench.lock docker buildx build --load --network host --label org.opencontainers.image.revision=$rev -t campfire-roda:$tag . > /tmp/build-roda-$tag.log 2>&1 || { tail -20 /tmp/build-roda-$tag.log; exit 1; }
  cd /opt/campfire-perf/once-campfire-rust/parity/docker/candidate
  flock /tmp/campfire-bench.lock docker buildx build --load --network host -q -t campfire-roda-candidate:$tag --build-arg BASE_IMAGE=campfire-roda:$tag . >> /tmp/build-roda-$tag.log 2>&1 || { tail -20 /tmp/build-roda-$tag.log; exit 1; }
  echo built campfire-roda:$tag \$(docker image inspect -f '{{.Id}}' campfire-roda:$tag | cut -c8-19) rev=$rev"
