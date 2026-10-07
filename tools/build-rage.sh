#!/usr/bin/env bash
# Local: build-rage.sh TAG -> campfire-rage:TAG and campfire-rage-candidate:TAG on the box, from
# apps/rage at HEAD (git archive, so only committed files), labelled with the commit.
set -euo pipefail
tag=$1
cd ~/Projects/campfire-perf/apps/rage
rev=$(git rev-parse HEAD)
git archive HEAD | ssh ${BOX:?set BOX=user@host} "set -e; d=/opt/campfire-perf/apps/rage-build-$tag; rm -rf \$d; mkdir -p \$d; tar -x -C \$d; cd \$d
  while [ -e /tmp/box-busy.sq ]; do sleep 30; done
  flock /tmp/campfire-bench.lock docker buildx build --load --network host --label org.opencontainers.image.revision=$rev -t campfire-rage:$tag . > /tmp/build-rage-$tag.log 2>&1 || { tail -20 /tmp/build-rage-$tag.log; exit 1; }
  cd /opt/campfire-perf/once-campfire-rust/parity/docker/candidate
  flock /tmp/campfire-bench.lock docker buildx build --load --network host -q -t campfire-rage-candidate:$tag --build-arg BASE_IMAGE=campfire-rage:$tag . >> /tmp/build-rage-$tag.log 2>&1 || { tail -20 /tmp/build-rage-$tag.log; exit 1; }
  echo built campfire-rage:$tag \$(docker image inspect -f '{{.Id}}' campfire-rage:$tag | cut -c8-19) rev=$rev"
