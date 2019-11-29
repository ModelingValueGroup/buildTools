#!/usr/bin/env bash
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

makeJavaDocJar() {
    local   sjar="$1"; shift
    local   djar="$1"; shift

    mkdir tmp-src
    (cd tmp-src; jar xf "../$sjar")
    javadoc -d tmp-doc -sourcepath tmp-src -subpackages "$OUR_DOMAIN"

    mkdir -p "$(dirname "$djar")"
    jar cf "$djar" -C tmp-doc .
    rm -rf tmp-src tmp-doc
}
makeJarName() {
    local      name="$1"; shift
    local variation="${1:-}"

    echo "$ARTIFACT_DIR/$name-SNAPSHOT$variation.jar"
}
makeJarNameSources() {
    makeJarName "$1" -sources
}
makeJarNameJavadoc() {
    makeJarName "$1" -javadoc
}
makeAllJavaDocJars() {
    for n in "$@"; do
        makeJavaDocJar "$(makeJarNameSources $n)" "$(makeJarNameJavadoc $n)"
    done
}
