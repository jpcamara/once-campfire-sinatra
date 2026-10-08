#!/usr/bin/env bash
# Local: build-app.sh APP TAG -> the app image and its parity candidate image on the box, from
# apps/APP at HEAD (git archive, so only committed files), labelled with the commit. Afterwards the
# new images also take the names bench/run-hetzner and the parity scripts use, and the previous
# ones keep theirs under :before-TAG.
#   sinatra    campfire-sinatra:TAG            campfire-sinatra-candidate:TAG
#   rage       campfire-rage:TAG               campfire-rage-candidate:TAG
#   rails-opt  campfire-reference:rails-opt-TAG  campfire-railsopt-candidate:TAG
set -euo pipefail
app=$1 tag=$2
case "$app" in
  sinatra) image=campfire-sinatra:$tag candidate=campfire-sinatra-candidate:$tag bench=campfire-sinatra:app ;;
  rage) image=campfire-rage:$tag candidate=campfire-rage-candidate:$tag bench=campfire-rage:app ;;
  rails-opt) image=campfire-reference:rails-opt-$tag candidate=campfire-railsopt-candidate:$tag bench=campfire-reference:rails-opt ;;
  *) echo "unknown app $app" >&2; exit 2 ;;
esac
cd ~/Projects/campfire-perf/apps/$app
rev=$(git rev-parse HEAD)
base=${candidate%%:*}
git archive HEAD | ssh "${BOX:?set BOX=user@host}" "set -e; d=/opt/campfire-perf/apps/$app-build-$tag; rm -rf \$d; mkdir -p \$d; tar -x -C \$d; cd \$d
  while [ -e /tmp/box-busy.sq ]; do sleep 30; done
  log=/tmp/build-$app-$tag.log
  flock /tmp/campfire-bench.lock docker buildx build --load --network host --label org.opencontainers.image.revision=$rev -t $image . > \$log 2>&1 || { tail -20 \$log; exit 1; }
  cd /opt/campfire-perf/once-campfire-rust
  if [ $app = rails-opt ]; then
    flock /tmp/campfire-bench.lock docker buildx build --load --network host -q --build-context fixtures=reference/test/fixtures \
      --build-arg BASE_IMAGE=$image -f parity/docker/Dockerfile -t $candidate parity/docker >> \$log 2>&1 || { tail -20 \$log; exit 1; }
  else
    flock /tmp/campfire-bench.lock docker buildx build --load --network host -q --build-arg BASE_IMAGE=$image \
      -t $candidate parity/docker/candidate >> \$log 2>&1 || { tail -20 \$log; exit 1; }
  fi
  docker image inspect $bench >/dev/null 2>&1 && docker tag $bench $bench-before-$tag
  docker image inspect $base:latest >/dev/null 2>&1 && docker tag $base:latest $base:before-$tag
  docker tag $image $bench; docker tag $candidate $base:latest
  echo built $app $image \$(docker image inspect -f '{{.Id}}' $image | cut -c8-19) rev=$rev"
