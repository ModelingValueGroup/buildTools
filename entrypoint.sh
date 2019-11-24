#!/bin/bash
set -euo pipefail

includeBuildTools() {
  local   token="$1"; shift
  local version="$1"; shift

  local buildToolsUrl="https://maven.pkg.github.com/ModelingValueGroup/buildTools/com.modelingvalue.buildTools/$version/buildTools-$version.sh"

  curl -s -H "Authorization: bearer $token" -L "$buildToolsUrl" -o buildTools.sh
  . buildTools.sh
}

includeBuildTools "$INPUT_TOKEN" "1.0.6"
includeBuildTools "$INPUT_TOKEN" "$(lastPackageVersion "$INPUT_TOKEN" "ModelingValueGroup/buildTools" "" "")"
