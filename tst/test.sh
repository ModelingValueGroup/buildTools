#!/usr/bin/env bash
set -euo pipefail

##### mimic github actions env for local execution:
# shellcheck disable=SC1090
[[ -f ~/secrets.sh ]] && . ~/secrets.sh # defines INPUT_TOKEN without expsong it in the github repos
GITHUB_WORKSPACE="${GITHUB_WORKSPACE:-$PWD}"

##### make tmp dir
tmp=./tmp
rm -rf $tmp
mkdir $tmp
cd $tmp

##### read all scripts
for f in "$GITHUB_WORKSPACE/src/"*.sh; do
  # shellcheck disable=SC1090
  . "$f"
done

# do some testing:
mkdir quick slow
downloadArtifactQuick "$INPUT_TOKEN" "com.modelingvalue" "buildTools" "1.0.4" "sh" "quick"
downloadArtifact      "$INPUT_TOKEN" "com.modelingvalue" "buildTools" "1.0.4" "sh" "slow"
diff quick/buildTools.sh slow/buildTools.sh

echo ok