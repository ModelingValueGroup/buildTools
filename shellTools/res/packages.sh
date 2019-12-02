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

downloadArtifactQuick() {
    local token="$1"; shift
    local     g="$1"; shift
    local     a="$1"; shift
    local     v="$1"; shift
    local     e="$1"; shift
    local   dir="$1"; shift

    group curl_ "$token" "$GITHUB_PACKAGE_URL/$g.$a/$v/$a-$v.$e" -o "$dir/$a.$e"
}
downloadArtifact() {
    local token="$1"; shift
    local     g="$1"; shift
    local     a="$1"; shift
    local     v="$1"; shift
    local     e="$1"; shift
    local   dir="$1"; shift

    mvn_ "$token" \
        org.apache.maven.plugins:maven-dependency-plugin:LATEST:copy \
                   -Dartifact="$g:$a:$v:$e" \
            -DoutputDirectory="$dir" \
          -Dmdep.stripVersion="true"
}
uploadArtifact() {
    local token="$1"; shift
    local  gave="$1"; shift
    local   pom="$1"; shift
    local  file="$1"; shift

    if [[ ! -f "$file" ]]; then
        echo "::error::uploadArtifact: can not find file $file"
        exit 75
    fi

    local g a v e
    gave2vars "$gave" "$pom" "$file"

    mvn_ "$token" \
    deploy:deploy-file \
         -DgroupId="$g" \
      -DartifactId="$a" \
         -Dversion="$v" \
       -Dpackaging="$e" \
    -DrepositoryId="github" \
            -Dfile="$file" \
         -DpomFile="$pom" \
             -Durl="$GITHUB_PACKAGE_URL"
}
lastPackageVersion() {
    listPackageVersions "$@" | head -1
}
listPackageVersions() {
    local      token="$1"; shift
    local repository="$1"; shift
    local       gave="$1"; shift
    local        pom="$1"; shift

    local g a v e
    gave2vars "$gave" "$pom" ""

    local   username="${repository/\/*}"
    local  reposname="${repository/*\/}"

    local query
    query="$(cat <<EOF | sed 's/"/\\"/g' | tr '\n\r' '  ' | sed 's/  */ /g'
query {
    repository(owner:"$username", name:"$reposname"){
        registryPackages(name:"$g.$a",first:1) {
            nodes {
                versions(last:100) {
                    nodes {
                        version
                    }
                }
            }
        }
    }
}
EOF
)"
    graphqlQuery "$token" "$query" | jq -r '.data.repository.registryPackages.nodes[0].versions.nodes[].version' 2>/dev/null
}
