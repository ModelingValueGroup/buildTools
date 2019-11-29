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
##     Wim Bast, Carel Bast, Tom Brus                                                                                  ~
## Contributors:                                                                                                       ~
##     Arjan Kok, Ronald Krijgsheld                                                                                    ~
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

set -euo pipefail

##########################################################################################################################
extraPackages=(xmlstarlet jq maven)
      ourUser="ModelingValueGroup"
      product="buildTools"
      groupId="com.modelingvalue"
   artifactId="$product"

##########################################################################################################################
echo "::group::install extra packages"
sudo apt-get install -y "${extraPackages[@]}"
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
v="1.0.30"
includeBuildTools "$INPUT_TOKEN" "$v"

##########################################################################################################################
# ...and then overwrite it with the latest:
v="$(lastPackageVersion "$INPUT_TOKEN" "$ourUser/$product" "$groupId:$artifactId" "")"
includeBuildTools "$INPUT_TOKEN" "$v"
