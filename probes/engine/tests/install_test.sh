#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
install="$here/install.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0
check() {
  if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; failures=$((failures + 1)); fi
}
server() {
  local dir="$tmp/$1"
  mkdir -p "$dir/Resources/Server/Other" "$dir/Resources/Client"
  printf other > "$dir/Resources/Client/other.zip"
  echo "$dir"
}
probes_present() {
  [[ -d $1/Resources/Server/ArcadeProbeBase && -d $1/Resources/Server/ArcadeProbeAGame && -d $1/Resources/Server/ArcadeProbeZGame && -d $1/Resources/Server/ArcadeProbeLoose && -f $1/Resources/Client/ArcadeProbe.zip ]]
}
nothing_left() {
  [[ ! -e $1/Resources/Server/ArcadeProbeBase && ! -e $1/Resources/Server/ArcadeProbeAGame && ! -e $1/Resources/Server/ArcadeProbeZGame && ! -e $1/Resources/Server/ArcadeProbeLoose && ! -e $1/Resources/Client/ArcadeProbe.zip && ! -e $1/Resources/Client/ArcadeProbeGame.zip && ! -e $1/Resources/.arcade-probe-installed ]]
}
others_intact() {
  [[ -d $1/Resources/Server/Other && $(cat "$1/Resources/Client/other.zip") == other ]]
}

dir=$(server full)
bash "$install" "$dir" >/dev/null
check "install creates the probes, both zips and the record" 'probes_present "$dir" && [[ -f $dir/Resources/Client/ArcadeProbeGame.zip && -f $dir/Resources/.arcade-probe-installed ]]'
bash "$install" --remove "$dir" >/dev/null
check "remove deletes exactly the probes" 'nothing_left "$dir" && others_intact "$dir"'

dir=$(server nogame)
bash "$install" --no-game "$dir" >/dev/null
check "--no-game leaves out the game zip" 'probes_present "$dir" && [[ ! -e $dir/Resources/Client/ArcadeProbeGame.zip ]]'
bash "$install" --remove "$dir" >/dev/null
check "--no-game install removes cleanly" 'nothing_left "$dir" && others_intact "$dir"'

dir=$(server folder-collision)
mkdir -p "$dir/Resources/Server/ArcadeProbeBase"
printf mine > "$dir/Resources/Server/ArcadeProbeBase/marker"
if bash "$install" "$dir" >/dev/null 2>&1; then rc=0; else rc=$?; fi
check "an existing probe folder refuses the install" '[[ $rc == 1 && ! -e $dir/Resources/.arcade-probe-installed && ! -e $dir/Resources/Server/ArcadeProbeAGame ]]'
if bash "$install" --remove "$dir" >/dev/null 2>&1; then rc=0; else rc=$?; fi
check "remove without a record refuses and keeps the folder" '[[ $rc == 1 && $(cat "$dir/Resources/Server/ArcadeProbeBase/marker") == mine ]]'

dir=$(server zip-collision)
printf mine > "$dir/Resources/Client/ArcadeProbe.zip"
if bash "$install" "$dir" >/dev/null 2>&1; then rc=0; else rc=$?; fi
check "an existing probe zip refuses the install" '[[ $rc == 1 && $(cat "$dir/Resources/Client/ArcadeProbe.zip") == mine && ! -e $dir/Resources/Server/ArcadeProbeBase ]]'

mkdir -p "$tmp/empty"
if bash "$install" "$tmp/empty" >/dev/null 2>&1; then rc=0; else rc=$?; fi
check "a directory without Resources/Server is refused" '[[ $rc == 1 ]]'

mkdir -p "$tmp/failzip"
printf '#!/bin/sh\nexit 1\n' > "$tmp/failzip/zip"
chmod +x "$tmp/failzip/zip"
dir=$(server failed)
if PATH="$tmp/failzip:$PATH" bash "$install" "$dir" >/dev/null 2>&1; then rc=0; else rc=$?; fi
check "a failing zip rolls the install back" '[[ $rc != 0 ]] && nothing_left "$dir" && others_intact "$dir"'
bash "$install" "$dir" >/dev/null
check "a retry after a failed install succeeds" 'probes_present "$dir"'

mkdir -p "$tmp/slowzip"
printf '#!/bin/sh\nsleep 30\n' > "$tmp/slowzip/zip"
chmod +x "$tmp/slowzip/zip"
dir=$(server interrupted)
PATH="$tmp/slowzip:$PATH" bash "$install" "$dir" >/dev/null 2>&1 &
pid=$!
for _ in $(seq 1 100); do [[ -d $dir/Resources/Server/ArcadeProbeBase ]] && break; sleep 0.05; done
kill -TERM "$pid"
if wait "$pid"; then rc=0; else rc=$?; fi
check "an interrupted install rolls back" '[[ $rc != 0 ]] && nothing_left "$dir" && others_intact "$dir"'
bash "$install" "$dir" >/dev/null
check "a retry after an interrupted install succeeds" 'probes_present "$dir"'

dir=$(server tampered)
bash "$install" "$dir" >/dev/null
echo "Resources/Server/Other" >> "$dir/Resources/.arcade-probe-installed"
if bash "$install" --remove "$dir" >/dev/null 2>&1; then rc=0; else rc=$?; fi
check "a record naming another path refuses removal and deletes nothing" '[[ $rc == 1 ]] && probes_present "$dir" && others_intact "$dir"'

dir=$(server linked)
mkdir -p "$tmp/elsewhere/Server"
rm -rf "$dir/Resources/Server"
ln -s "$tmp/elsewhere/Server" "$dir/Resources/Server"
if bash "$install" "$dir" >/dev/null 2>&1; then rc=0; else rc=$?; fi
check "a symlinked Resources/Server refuses the install" '[[ $rc == 1 && ! -e $tmp/elsewhere/Server/ArcadeProbeBase && ! -e $dir/Resources/.arcade-probe-installed ]]'

dir=$(server repointed)
bash "$install" "$dir" >/dev/null
mkdir -p "$tmp/victim/Server/ArcadeProbeBase"
printf keep > "$tmp/victim/Server/ArcadeProbeBase/marker"
mv "$dir/Resources/Server" "$dir/Resources/Server.real"
ln -s "$tmp/victim/Server" "$dir/Resources/Server"
if bash "$install" --remove "$dir" >/dev/null 2>&1; then rc=0; else rc=$?; fi
check "a Resources/Server repointed after install refuses removal" '[[ $rc == 1 && $(cat "$tmp/victim/Server/ArcadeProbeBase/marker") == keep ]]'

dir=$(server dangling)
ln -s "$tmp/dangling-target" "$dir/Resources/.arcade-probe-installed"
if bash "$install" "$dir" >/dev/null 2>&1; then rc=0; else rc=$?; fi
check "a dangling link at the record refuses the install" '[[ $rc == 1 && ! -e $tmp/dangling-target && ! -e $dir/Resources/Server/ArcadeProbeBase ]]'

dir=$(server dangling-probe)
ln -s "$tmp/dangling-probe-target" "$dir/Resources/Server/ArcadeProbeLoose"
if bash "$install" "$dir" >/dev/null 2>&1; then rc=0; else rc=$?; fi
check "a dangling link at a probe path refuses the install and stays" '[[ $rc == 1 && -L $dir/Resources/Server/ArcadeProbeLoose && ! -e $dir/Resources/Server/ArcadeProbeBase ]]'

if ((failures)); then echo "$failures install checks failed"; exit 1; fi
echo "all install checks passed"
