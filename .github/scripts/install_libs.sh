#!/usr/bin/env bash
set -uo pipefail

haxelib install hxpkg --quiet --always < /dev/null || exit 1

PACKAGES=$(python3 -c "
import json
for profile in json.load(open('.hxpkg')):
    if profile.get('profile', 'default') != 'default':
        continue
    for pkg in profile['pkgs']:
        print(pkg['name'], pkg.get('link', '-'), pkg.get('branch', '-'))
")

missing() {
  local result=""
  while read -r NAME LINK BRANCH; do
    [ -z "$NAME" ] && continue
    if ! haxelib path "$NAME" > /dev/null 2>&1; then result="$result $NAME"; fi
  done <<< "$PACKAGES"
  echo "$result"
}

install_commit() {
  local NAME="$1" LINK="$2" REF="$3"
  local ROOT=".haxelib/${NAME//./,}"
  local DIR="$ROOT/git"

  rm -rf "$DIR"
  mkdir -p "$DIR"
  git -C "$DIR" init -q
  git -C "$DIR" remote add origin "$LINK"
  if ! git -C "$DIR" fetch -q --depth 1 origin "$REF"; then
    rm -rf "$DIR"
    return 1
  fi
  git -C "$DIR" checkout -q FETCH_HEAD
  printf 'git' > "$ROOT/.current"
  echo "Installed $NAME from $LINK at $REF"
}

for ATTEMPT in 1 2 3 4; do
  haxelib run hxpkg install < /dev/null 2>&1 | tee hxpkg.log

  for NAME in $(missing); do
    LINE=$(grep -E "^$NAME " <<< "$PACKAGES")
    LINK=$(awk '{print $2}' <<< "$LINE")
    BRANCH=$(awk '{print $3}' <<< "$LINE")
    if [ "$LINK" != "-" ] && [ "$BRANCH" != "-" ]; then
      install_commit "$NAME" "$LINK" "$BRANCH" || echo "::warning::Could not fetch $NAME at $BRANCH"
    fi
  done

  MISSING=$(missing)
  if [ -z "$MISSING" ]; then
    rm -f hxpkg.log
    echo "All libraries installed"
    exit 0
  fi

  echo "::warning::Attempt $ATTEMPT could not install:$MISSING"
  sleep $((ATTEMPT * 15))
done

rm -f hxpkg.log
echo "::error::Could not install:$(missing)"
exit 1
