#!/bin/bash
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## (C) Copyright 2018-2019 Modeling Value Group B.V. (http://modelingvalue.org)                                        ~
##                                                                                                                     ~
## Licensed under the GNU Lesser General Public License v3.0 (the 'License'). You may not use this file except in      ~
## compliance with the License. You may obtain a copy of the License at: https://choosealicense.com/licenses/lgpl-3.0  ~
## Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on ~
## an 'AS IS' BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the  ~
## specific language governing permissions and limitations under the License.                                          ~
##                                                                                                                     ~
## Maintainers:                                                                                                        ~
##     Wim Bast, Tom Brus, Ronald Krijgsheld                                                                           ~
## Contributors:                                                                                                       ~
##     Arjan Kok, Carel Bast                                                                                           ~
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

set -euo pipefail

##########################################################################################################################
extraPackages=(xmlstarlet jq maven:mvn s3cmd)
      ourUser="ModelingValueGroup"
      product="buildTools"
      groupId="org.modelingvalue"
   artifactId="$product"

##########################################################################################################################
echo "::group::install extra packages"
toInstall=()
for i in "${extraPackages[@]}"; do
    IFS=: read n c <<<"$i"
    c="${c:-$n}"
    if ! which $c 1>/dev/null; then
        toInstall+=("$n")
    fi
done
if [[ "${#toInstall[@]}" != 0 ]]; then
    echo "## installing: ${toInstall[*]}"
    sudo apt-get update
    sudo apt-get install -y "${toInstall[@]}"
fi
echo "::endgroup::"

includeBuildTools() {
  local   token="$1"; shift
  local version="$1"; shift

  local url="https://maven.pkg.github.com/$ourUser/$product/$groupId.$artifactId/$version/$artifactId-$version.jar"

  curl -s -H "Authorization: bearer $token" -L "$url" -o "$artifactId.jar"
  . <(java -jar "$artifactId.jar")
  echo "INFO: installed $artifactId version $version"
}

##########################################################################################################################
# we do not have the 'lastPackageVersion' function defined here yet
# so we first load a known version here....
v="1.2.9"
includeBuildTools "$INPUT_TOKEN" "$v"

##########################################################################################################################
# ...and then overwrite it with the latest:
v="$(lastPackageVersion "$INPUT_TOKEN" "$ourUser/$product" "$groupId:$artifactId" "")"
includeBuildTools "$INPUT_TOKEN" "$v"
