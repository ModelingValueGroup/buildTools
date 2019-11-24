#!/usr/bin/env bash
set -euo pipefail

if [[ "${GITHUB_WORKSPACE:-}" == "" ]]; then
  ##### mimic github actions env for local execution:
  # shellcheck disable=SC1090
  . ~/secrets.sh # defines INPUT_TOKEN without expsong it in the github repos
  if [[ "${INPUT_TOKEN:-}" == "" ]]; then
    echo ":error:: local test runs require a file ~/sercrets.sh that defines at least INPUT_TOKEN"
    exit 67
  fi
  GITHUB_WORKSPACE="$PWD"
  GITHUB_REPOSITORY="ModelingValueGroup/buildTools"
fi

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

##### tests
test_00() {
  downloadArtifactQuick "$INPUT_TOKEN" "com.modelingvalue" "buildTools" "1.0.4" "sh" "."
  if [[ "$(md5sum buildTools.sh)" != "xxx" ]]; then
    echo "::error::downloadArtifactQuick failed"
    exit 65
  fi
  rm buildTools.sh
}
test_01() {
  downloadArtifact      "$INPUT_TOKEN" "com.modelingvalue" "buildTools" "1.0.4" "sh" "."
  if [[ "$(md5sum buildTools.sh)" != "xxx" ]]; then
    echo "::error::downloadArtifactQuick failed"
    exit 65
  fi
  rm buildTools.sh
}

group test_00
group test_01

echo ok