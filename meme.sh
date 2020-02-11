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

includeBuildToolsVersion() {
    local   token="$1"; shift
    local version="$1"; shift

    local url="https://maven.pkg.github.com/ModelingValueGroup/buildTools/org.modelingvalue.buildTools/$version/buildTools-$version.jar"

    curl -s -H "Authorization: bearer $token" -L "$url" -o "buildTools.jar"
    . <(java -jar "buildTools.jar")
    echo "INFO: installed buildTools version $version"
}
includeBuildTools() {
    local   token="$1"; shift

    ##########################################################################################################################
    # we do not have the 'lastPackageVersion' function yet, so we first load a known version here....
    includeBuildToolsVersion "$token" "2.0.0"
    # ...and then overwrite it with the latest:
    includeBuildToolsVersion "$token" "$(lastPackageVersion "$token" "ModelingValueGroup/buildTools" "org.modelingvalue" "buildTools")"
}

includeBuildTools "$INPUT_TOKEN"