#!/usr/bin/env bash
set -uo pipefail

haxelib install hxpkg --quiet --always < /dev/null || exit 1

NAMES=$(python3 -c "import json;print(' '.join(k['name'] for p in json.load(open('.hxpkg')) if p.get('profile','default') == 'default' for k in p['pkgs']))")

missing() {
  local result=""
  for NAME in $NAMES; do
    if ! haxelib path "$NAME" > /dev/null 2>&1; then result="$result $NAME"; fi
  done
  echo "$result"
}

for ATTEMPT in 1 2 3 4; do
  haxelib run hxpkg install < /dev/null 2>&1 | tee hxpkg.log
  MISSING=$(missing)
  if [ -z "$MISSING" ] && ! grep -q "failed" hxpkg.log; then
    rm -f hxpkg.log
    echo "All libraries installed"
    exit 0
  fi
  echo "::warning::Attempt $ATTEMPT could not install:${MISSING:- (see log)}"
  sleep $((ATTEMPT * 15))
done

rm -f hxpkg.log
echo "::error::Could not install:$(missing)"
exit 1
