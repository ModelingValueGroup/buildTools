#!/bin/bash
set -euo pipefail

##########################################################################################################################
extraPackages=(xmlstarlet jq maven)
      ourUser="ModelingValueGroup"
      product="buildTools"
      groupId="org.modelingvalue"
   artifactId="$product"

##########################################################################################################################
echo "::group::install extra packages"
sudo apt-get install -y "${extraPackages[@]}"
echo "::endgroup::"

includeBuildTools() {
  local   token="$1"; shift
  local version="$1"; shift

  local url="https://maven.pkg.github.com/$ourUser/$product/$groupId.$artifactId/$version/$artifactId-$version.sh"

  curl -s -H "Authorization: bearer $token" -L "$url" -o $artifactId.sh
  . $artifactId.sh
}

##########################################################################################################################
# we do not have the 'lastPackageVersion' function defined here yet
# so we first load a known version here....
includeBuildTools "$INPUT_TOKEN" "1.0.19"

# ...and then overwrite it with the latest:
latest="$(lastPackageVersion "$INPUT_TOKEN" "$ourUser/$product" "$groupId:$artifactId" "")"
includeBuildTools "$INPUT_TOKEN" "$latest"
echo "INFO: installed $artifactId version $latest"