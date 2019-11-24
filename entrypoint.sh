#!/bin/bash
set -x
set -euo pipefail

includeBuildTools() {
  local   token="$1"; shift
  local version="$1"; shift

  local buildToolsUrl="https://maven.pkg.github.com/ModelingValueGroup/buildTools/com.modelingvalue.buildTools/$version/buildTools-$version.sh"

  curl -s -H "Authorization: bearer $token" -L "$buildToolsUrl" -o buildTools-tmp.sh
  . buildTools-tmp.sh
  rm buildTools-tmp.sh
}

# we do not have the 'lastPackageVersion' function defined here yet. So we first load a known version here and then overwrite it with the latest:
echo "================================================="
includeBuildTools "$INPUT_TOKEN" "1.0.12"
echo "================================================="
declare -pf listPackageVersions
declare -pf lastPackageVersion
echo "================================================="
listPackageVersions "$INPUT_TOKEN" "ModelingValueGroup/buildTools" "com.modelingvalue:buildTools" ""
echo "================================================="
includeBuildTools "$INPUT_TOKEN" "$(lastPackageVersion "$INPUT_TOKEN" "ModelingValueGroup/buildTools" "com.modelingvalue:buildTools" "")"
echo "================================================="
