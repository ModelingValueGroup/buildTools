#!/usr/bin/env bash
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## (C) Copyright 2018-2020 Modeling Value Group B.V. (http://modelingvalue.org)                                        ~
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

getMpsDownloadUrl() {
    local fullVersion="$1"; shift

    printf "https://download.jetbrains.com/mps/%s/MPS-%s.zip" "$(getMajor2Version "$fullVersion")" "$fullVersion"
}
installMps() {
    local         dir="$1"; shift
    local fullVersion="$1"; shift

    echo "::info::installing MPS $fullVersion..."
find . -type f -exec ls -l {} + | sed 's/^/@@A@@ /'; sleep 1
    mkdir -p "$dir"
    (
        cd "$dir"
find . -type f -exec ls -l {} + | sed 's/^/@@B@@ /'; sleep 1
        local tmpZip="MPS$$.zip"
        curlPipe '' -o "$tmpZip" "$(getMpsDownloadUrl "$fullVersion")"
find . -type f -exec ls -l {} + | sed 's/^/@@C@@ /'; sleep 1
        if [[ ! -f "$tmpZip" ]]; then
            echo "::error::could not download MPS $fullVersion" 1>&2
            exit 32
        fi
find . -type f -exec ls -l {} + | sed 's/^/@@D@@ /'; sleep 1
        unzip -q "$tmpZip"
find . -type f -exec ls -l {} + | sed 's/^/@@E@@ /'; sleep 1
        mv "MPS "*/* .
find . -type f -exec ls -l {} + | sed 's/^/@@F@@ /'; sleep 1
        rm -rf "$tmpZip" "MPS "*
    )
}
test_installMPS() {
    installMps "MPS" "2019.3"
    assertChecksumsMatch    "15d9d92ace38667ba67f4160034a5a09:MPS/about.txt" \
                            "dae22af1b94ebf2137efe0c8bcae6ba0:MPS/lib/annotations.jar"
}
