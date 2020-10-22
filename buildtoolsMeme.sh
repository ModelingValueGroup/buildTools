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

  MEME_TOKEN="$1"; shift
MEME_VERSION="$1"; shift

if [[ "$MEME_TOKEN" == "" ]]; then
    echo "::error::no token passed to buildtoolsMeme.sh"
    exit 56
fi
if ! (echo 4.0.0; echo $BASH_VERSION) | sort -VC; then
    echo "::error::this shell version ($BASH_VERSION) is too old, I need at least bash 4.0.0."
    exit 99
fi

getBuildtoolsVersion() {
    local            token="$1"; shift
    local requestedVersion="$1"; shift

    local url="https://maven.pkg.github.com/ModelingValueGroup/buildtools/org.modelingvalue.buildtools/$requestedVersion/buildtools-$requestedVersion.jar"

    rm -f ~/buildtools.jar
    curl -s -H "Authorization: bearer $token" -L "$url" -o ~/buildtools.jar
    if [[ "$(file ~/buildtools.jar)" =~ .*text.* ]]; then
        echo "::error::could not download buildtools jar from: $url"
        sed 's/^/    /' ~/buildtools.jar
        exit 91
    fi
    echo "installed buildTools $(java -jar ~/buildtools.jar -version)"
}
getBuildtools() {
    local            token="$1"; shift
    local requestedVersion="$1"; shift

    local latestVersion
    local installedVersion

    if [[ -f ~/buildtools.jar ]]; then
        . <(java -jar ~/buildtools.jar)
           latestVersion="$(lastPackageVersion "$token" "ModelingValueGroup/buildtools" "org.modelingvalue" "buildtools" || :)"
        installedVersion="$(java -jar ~/buildtools.jar -version)"
        if [[ ( "$requestedVersion" != "" && "$installedVersion" != "$requestedVersion" ) || ( "$requestedVersion" == "" && "$installedVersion" != "$latestVersion" ) ]]; then
            # not the right version
            rm  ~/buildtools.jar
            installedVersion=
        else
            echo "::info::buildtools version $installedVersion already installed"
        fi
    fi
    if [[ ! -f ~/buildtools.jar ]]; then
        if [[ "$requestedVersion" == "" ]]; then
            getBuildtoolsVersion "$token" "3.3.3" # older version, just to make lastPackageVersion() work
            . <(java -jar ~/buildtools.jar)
            getBuildtoolsVersion "$token" "$(lastPackageVersion "$token" "ModelingValueGroup/buildtools" "org.modelingvalue" "buildtools")"
        else
            getBuildtoolsVersion "$token" "$requestedVersion"
        fi
        . <(java -jar ~/buildtools.jar -check)
    fi
}
getBuildtools "$MEME_TOKEN" "$MEME_VERSION"
