#!/bin/bash
set -euo pipefail

includeBuildTools() {
  local   token="$1"; shift
  local version="$1"; shift

  local buildToolsUrl="https://maven.pkg.github.com/ModelingValueGroup/buildTools/com.modelingvalue.buildTools/$version/buildTools-$version.sh"

  curl -s -H "Authorization: bearer $token" -L "$buildToolsUrl" -o buildTools.sh
  . buildTools.sh
}

# we do not have the 'lastPackageVersion' function defined here yet
# so we first load a known version here and then overwrite it with the latest:
includeBuildTools "$INPUT_TOKEN" "1.0.19"
includeBuildTools "$INPUT_TOKEN" "$(lastPackageVersion "$INPUT_TOKEN" "ModelingValueGroup/buildTools" "com.modelingvalue:buildTools" "")"
