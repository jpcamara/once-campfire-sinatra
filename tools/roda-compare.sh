#!/usr/bin/env bash
# Local: roda-compare.sh TAG -> server-HTML diff (script/compare over script/paths.txt) of the
# reference vs campfire-roda:TAG, both started on the box by script/box-pair under the bench lock,
# fetched through an SSH tunnel and normalized here with the parity harness's normalizer.
set -uo pipefail
tag=$1
cd ~/Projects/campfire-perf/apps/roda
ssh ${BOX:?set BOX=user@host} "cd /opt/campfire-perf/apps/roda && while [ -e /tmp/box-busy.sq ]; do sleep 30; done; rm -f /tmp/roda-pair-done; exec flock /tmp/campfire-bench.lock bash -c 'script/box-pair start campfire-roda:$tag >/dev/null && echo ready; for i in \$(seq 1 900); do [ -e /tmp/roda-pair-done ] && break; sleep 1; done; script/box-pair stop'" > /tmp/roda-pair-$tag.log 2>&1 &
pair=$!
until grep -q ready /tmp/roda-pair-$tag.log 2>/dev/null; do sleep 2; kill -0 $pair 2>/dev/null || { cat /tmp/roda-pair-$tag.log; exit 1; }; done
ssh -N -L 4794:127.0.0.1:4794 -L 4796:127.0.0.1:4796 ${BOX:?set BOX=user@host} & tunnel=$!
sleep 2
# Twice: the second pass reads pages whose shells (and the sidebar, messages pages) are now cached.
status=0
for pass in 1 2; do
  OUT=/tmp/roda-compare-$tag-$pass script/compare http://127.0.0.1:4794 http://127.0.0.1:4796 $(grep -v '^#' script/paths.txt) | sed "s/^/pass $pass: /" || status=1
done
# Then the write flows, on the same pair (both seeds have only seen sign-ins).
OUT=/tmp/roda-flows-$tag script/flows http://127.0.0.1:4794 http://127.0.0.1:4796 | sed "s/^/flows: /"
kill $tunnel; ssh ${BOX:?set BOX=user@host} "touch /tmp/roda-pair-done"; wait $pair 2>/dev/null
exit $status
