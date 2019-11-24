#!/usr/bin/env bash
set -euo pipefail

##### make tmp dir
tmp=./tmp
rm -rf $tmp
mkdir $tmp
cd $tmp

##### read all scripts
for f in ../src/*.sh; do
  # shellcheck disable=SC1090
  . "$f"
done

##### read in the local secrets
[[ -f ~/secrets.sh ]] . ~/secrets.sh # defines INPUT_TOKEN without expsong it in the github repos

mkdir quick slow
downloadArtifactQuick "$INPUT_TOKEN" "com.modelingvalue" "buildTools" "1.0.4" "sh" "quick"
downloadArtifact      "$INPUT_TOKEN" "com.modelingvalue" "buildTools" "1.0.4" "sh" "slow"

diff quick/buildTools.sh slow/buildTools.sh

echo ok