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

    rm -f ~/buildTools.jar
    curl -s -H "Authorization: bearer $token" -L "$url" -o ~/buildTools.jar
    if [[ "$(file ~/buildTools.jar)" =~ .*text.* ]]; then
        echo "::error::could not download buildTools jar from: $url"
        sed 's/^/    /' ~/buildTools.jar
        exit 91
    fi
    . <(java -jar ~/buildTools.jar)
    echo "INFO: installed buildTools version $version"
}
includeBuildTools() {
    local   token="$1"; shift
    local version="${1:-}"

    includeBuildToolsVersion "$token" "${version:-2.0.6}"
    if [[ "${version}" == "" ]]; then
        includeBuildToolsVersion "$token" "$(lastPackageVersion "$token" "ModelingValueGroup/buildTools" "org.modelingvalue" "buildTools")"
    fi
}

if [[ "${1:-}" == "" ]]; then
    echo "::error::no token passed to buildToolsMeme.sh"
    exit 56
fi
includeBuildTools "$1" "${2:-}"
