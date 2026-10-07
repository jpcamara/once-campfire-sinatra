#!/usr/bin/env bash
# Local: rage-compare.sh TAG -> server-HTML diff (script/compare over script/paths.txt) of the
# reference vs campfire-rage:TAG, both started on the box by script/box-pair under the bench lock,
# fetched through an SSH tunnel and normalized here with the parity harness's normalizer.
set -uo pipefail
tag=$1
cd ~/Projects/campfire-perf/apps/rage
ssh ${BOX:?set BOX=user@host} "cd /opt/campfire-perf/apps/rage && while [ -e /tmp/box-busy.sq ]; do sleep 30; done; rm -f /tmp/rage-pair-done; exec flock /tmp/campfire-bench.lock bash -c 'script/box-pair start campfire-rage:$tag >/dev/null && echo ready; for i in \$(seq 1 900); do [ -e /tmp/rage-pair-done ] && break; sleep 1; done; script/box-pair stop'" > /tmp/rage-pair-$tag.log 2>&1 &
pair=$!
until grep -q ready /tmp/rage-pair-$tag.log 2>/dev/null; do sleep 2; kill -0 $pair 2>/dev/null || { cat /tmp/rage-pair-$tag.log; exit 1; }; done
ssh -N -L 4594:127.0.0.1:4594 -L 4596:127.0.0.1:4596 ${BOX:?set BOX=user@host} & tunnel=$!
sleep 2
# Twice: the second pass reads pages whose shells (and the sidebar, messages pages) are now cached.
status=0
for pass in 1 2; do
  OUT=/tmp/rage-compare-$tag-$pass script/compare http://127.0.0.1:4594 http://127.0.0.1:4596 $(grep -v '^#' script/paths.txt) | sed "s/^/pass $pass: /" || status=1
done
kill $tunnel; ssh ${BOX:?set BOX=user@host} "touch /tmp/rage-pair-done"; wait $pair 2>/dev/null
exit $status
