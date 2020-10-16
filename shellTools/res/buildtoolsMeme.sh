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

    local url="https://maven.pkg.github.com/ModelingValueGroup/buildtools/org.modelingvalue.buildtools/$version/buildtools-$version.jar"

    rm -f ~/buildtools.jar
    curl -s -H "Authorization: bearer $token" -L "$url" -o ~/buildtools.jar
    if [[ "$(file ~/buildtools.jar)" =~ .*text.* ]]; then
        echo "::error::could not download buildtools jar from: $url"
        sed 's/^/    /' ~/buildtools.jar
        exit 91
    fi
    . <(java -jar ~/buildtools.jar)
    echo "INFO: installed buildtools version $version"
}
includeBuildTools() {
    local   token="$1"; shift
    local version="${1:-}"

    includeBuildToolsVersion "$token" "${version:-3.0.3}"
    if [[ "${version}" == "" ]]; then
        includeBuildToolsVersion "$token" "$(lastPackageVersion "$token" "ModelingValueGroup/buildtools" "org.modelingvalue" "buildtools")"
    fi
}

if [[ "${1:-}" == "" ]]; then
    echo "::error::no token passed to buildtoolsMeme.sh"
    exit 56
fi
includeBuildTools "$1" "${2:-}"
