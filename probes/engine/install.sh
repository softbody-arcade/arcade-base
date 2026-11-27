#!/usr/bin/env bash
set -Eeuo pipefail

here=$(cd "$(dirname "$0")" && pwd)
servers=(ArcadeProbeBase ArcadeProbeAGame ArcadeProbeZGame ArcadeProbeLoose)
allowed=(
  Resources/Server/ArcadeProbeBase
  Resources/Server/ArcadeProbeAGame
  Resources/Server/ArcadeProbeZGame
  Resources/Server/ArcadeProbeLoose
  Resources/Client/ArcadeProbe.zip
  Resources/Client/ArcadeProbeGame.zip
)
record=Resources/.arcade-probe-installed

usage() {
  echo "usage: install.sh [--no-game] <test-server-dir> | install.sh --remove <test-server-dir>" >&2
  exit 1
}

remove=false game=true
while (($#)); do
  case $1 in
    --remove) remove=true; shift ;;
    --no-game) game=false; shift ;;
    --*) usage ;;
    *) break ;;
  esac
done
(($# == 1)) || usage
root=$1
[[ -d $root/Resources/Server && -d $root/Resources/Client ]] || { echo "not a test server: $root" >&2; exit 1; }
root=$(cd "$root" && pwd -P)
for dir in Resources Resources/Server Resources/Client; do
  [[ ! -L $root/$dir ]] || { echo "refusing a symlinked $dir in $root" >&2; exit 1; }
done

if $remove; then
  [[ -f $root/$record ]] || { echo "no probe record in $root" >&2; exit 1; }
  mapfile -t lines < "$root/$record"
  declare -A seen=()
  for line in "${lines[@]}"; do
    ok=false
    for path in "${allowed[@]}"; do [[ $line == "$path" ]] && ok=true; done
    $ok || { echo "record lists an unexpected path: $line" >&2; exit 1; }
    [[ -z ${seen[$line]:-} ]] || { echo "record lists a path twice: $line" >&2; exit 1; }
    seen[$line]=1
  done
  for line in "${lines[@]}"; do rm -rf -- "${root:?}/$line"; done
  rm -f -- "$root/$record"
  echo "probes removed from $root"
  exit 0
fi

[[ ! -e $root/$record && ! -L $root/$record ]] || { echo "probes already installed in $root" >&2; exit 1; }
for path in "${allowed[@]}"; do
  [[ ! -e $root/$path && ! -L $root/$path ]] || { echo "already exists, not touching it: $path" >&2; exit 1; }
done

created=()
child=
run() {
  local rc=0
  "$@" &
  child=$!
  wait "$child" || rc=$?
  child=
  return "$rc"
}
rollback() {
  local path
  [[ -z $child ]] || { kill "$child" 2>/dev/null || true; wait "$child" 2>/dev/null || true; }
  for path in "${created[@]}"; do rm -rf -- "${root:?}/$path"; done
  rm -f -- "$root/$record"
}
trap 'rollback; exit 1' ERR
trap 'rollback; exit 143' TERM
trap 'rollback; exit 130' INT

for name in "${servers[@]}"; do
  created+=("Resources/Server/$name")
  run cp -r "$here/server/$name" "$root/Resources/Server/$name"
done
created+=(Resources/Client/ArcadeProbe.zip)
run bash -c 'cd "$1" && exec zip -qr "$2" .' _ "$here/client-base" "$root/Resources/Client/ArcadeProbe.zip"
if $game; then
  created+=(Resources/Client/ArcadeProbeGame.zip)
  run bash -c 'cd "$1" && exec zip -qr "$2" .' _ "$here/client-game" "$root/Resources/Client/ArcadeProbeGame.zip"
fi
printf '%s\n' "${created[@]}" > "$root/$record"
trap - ERR TERM INT
echo "probes installed in $root"
