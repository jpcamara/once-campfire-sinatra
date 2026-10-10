#!/usr/bin/env bash
# Local: pair-verify.sh APP IMAGE -> server-HTML diff (script/compare over script/paths.txt, twice:
# the second pass reads cached pages) and the write flows (script/flows, on fresh seed copies) of the
# reference vs IMAGE. Both run on the box via APP's script/box-pair under the bench lock, reached
# through an SSH tunnel. APP is sinatra (ports 4494/4496), rage (4594/4596) or roda (4794/4796).
set -uo pipefail
app=$1 image=$2
case "$app" in sinatra) ref=4494 cand=4496 ;; rage) ref=4594 cand=4596 ;; roda) ref=4794 cand=4796 ;; *) echo "unknown app $app" >&2; exit 2 ;; esac
box=${BOX:?set BOX=user@host}
cd ~/Projects/campfire-perf/apps/$app
log=/tmp/$app-pair-$$.log

pair() { # start the pair, run "$@" locally against it, stop it
  ssh "$box" "cd /opt/campfire-perf/apps/$app && while [ -e /tmp/box-busy.sq ]; do sleep 30; done; rm -f /tmp/$app-pair-done; exec flock /tmp/campfire-bench.lock bash -c 'script/box-pair start $image >/dev/null && echo ready; for i in \$(seq 1 900); do [ -e /tmp/$app-pair-done ] && break; sleep 1; done; script/box-pair stop'" > "$log" 2>&1 &
  local remote=$!
  until grep -q ready "$log" 2>/dev/null; do sleep 2; kill -0 $remote 2>/dev/null || { cat "$log"; return 1; }; done
  ssh -N -L $ref:127.0.0.1:$ref -L $cand:127.0.0.1:$cand "$box" & local tunnel=$!
  sleep 2
  "$@"; local status=$?
  kill $tunnel; ssh "$box" "touch /tmp/$app-pair-done"; wait $remote 2>/dev/null
  return $status
}

compare_twice() {
  local status=0
  for pass in 1 2; do
    OUT=/tmp/$app-compare-$$-$pass script/compare http://127.0.0.1:$ref http://127.0.0.1:$cand $(grep -v '^#' script/paths.txt) | sed "s/^/pass $pass: /" || status=1
  done
  return $status
}

flows() { OUT=/tmp/$app-flows-$$ script/flows http://127.0.0.1:$ref http://127.0.0.1:$cand; }

pair compare_twice; s1=$?
pair flows; s2=$?
echo "compare exit $s1, flows exit $s2"
exit $(( s1 || s2 ))
