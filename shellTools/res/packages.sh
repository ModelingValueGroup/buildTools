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
##     Wim Bast, Tom Brus, Ronald Krijgsheld                                                                           ~
## Contributors:                                                                                                       ~
##     Arjan Kok, Carel Bast                                                                                           ~
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

set -euo pipefail

makeArtifactPath() {
    local   url="$1"; shift
    local     g="$1"; shift
    local     a="$1"; shift
    local     v="$1"; shift
    local     e="$1"; shift
    local extra="${1:-}"       # <empty> | javadoc | sources

    if [[ "$extra" != "" && "${extra:0:1}" != "-" ]]; then
        extra="-$extra"
    fi
    if [[ "$url" =~ .*\?.* ]]; then
        printf "%sg=%s&a=%s&v=%s&e=%s" "$url" "$g" "$a" "$v" "$e"
    else
        printf "%s/%s/%s/%s/%s-%s%s.%s" "$url" "${g//.//}" "$a" "$v" "$a" "$v" "$extra" "$e"
    fi
}
downloadArtifactQuick() {
    local     g="$1"; shift
    local     a="$1"; shift
    local     v="$1"; shift
    local     e="$1"; shift
    local   dir="$1"; shift

    if egrep -q '[A-Z]'<<<"$a"; then
        echo "::warning::artifact id $a should be only lowercase" 1>&2
    fi

    local name combi ext extra

    mkdir -p "$dir"
    for combi in "$e:" "$e:-sources" "$e:-javadoc" "pom:"; do
        IFS=: read ext extra <<<"$combi"
        for name in "${!MAVEN_REPOS_LIST[@]}"; do
            local repoUrl="${MAVEN_REPOS_LIST[$name]}"
            mkdir -p "$dir-$name"
            local  url="$(makeArtifactPath "$repoUrl" "$g" "$a" "$v" "$ext" "$extra")"
            local tmpfile="$dir-$name/$a$extra.$ext"
            curlPipe "$GITHUB_TOKEN" "$url" -o "$tmpfile" 2>/dev/null || : &
        done
    done
    wait
    for combi in ":$e" "-sources:$e" "-javadoc:$e" ":pom"; do
        IFS=: read extra ext <<<"$combi"
        local file="$dir/$a$extra.$ext"
        for name in "${!MAVEN_REPOS_LIST[@]}"; do
            local tmpfile="$dir-$name/$a$extra.$ext"
            if [[ -f "$tmpfile" ]]; then
                if [[ ! -f "$file" ]]; then
                    mv "$tmpfile" "$file"
                elif ! cmp -s "$file" "$tmpfile"; then
                    echo "::warning:: artifacts from different sources differ ($g:$a:$v)" 1>&2
                fi
            fi
        done
        if [[ ! -f "$file" ]]; then
            echo "::warning::could not download artifact: $g:$a:$v ($file)" 1>&2
        fi
    done
    for name in "${!MAVEN_REPOS_LIST[@]}"; do
        rm -rf "$dir-$name"
    done
}
downloadArtifact() {
    local     g="$1"; shift
    local     a="$1"; shift
    local     v="$1"; shift
    local     e="$1"; shift
    local   dir="$1"; shift

    if egrep -q '[A-Z]'<<<"$a"; then
        echo "::warning::artifact id $a should be only lowercase" 1>&2
    fi

    mvn_ "$GITHUB_TOKEN" \
        org.apache.maven.plugins:maven-dependency-plugin:LATEST:copy \
                   -Dartifact="$g:$a:$v:$e" \
            -DoutputDirectory="$dir" \
          -Dmdep.stripVersion="true"
}
uploadArtifactQuick() {
    local     g="$1"; shift
    local     a="$1"; shift
    local     v="$1"; shift
    local   pom="$1"; shift
    local  file="$1"; shift
    local  repo="${1:-$GITHUB_REPOSITORY}"

    if [[ ! -f "$file" ]]; then
        echo "::error::uploadArtifactQuick: can not find file $file" 1>&2
        exit 75
    fi
    if egrep -q '[A-Z]'<<<"$a"; then
        echo "::error::artifact id $a should be only lowercase" 1>&2
        exit 75
    fi

    uploadArtifactQuick_upload() {
        local  file="$1"; shift
        local     e="$1"; shift
        local extra="$1"; shift

        if [[ -f "$file" ]]; then
            curlPipe "$ALLREP_TOKEN" -X PUT --upload-file "$file" "$(makeArtifactPath "$GITHUB_PACKAGE_URL/$repo" "$g" "$a" "$v" "$e" "$extra")"
        fi
    }

    local       e="${file##*.}"
    local sources="$(sed "s/[.]$e\$/-sources&/" <<<"$file")"
    local javadoc="$(sed "s/[.]$e\$/-javadoc&/" <<<"$file")"

    uploadArtifactQuick_upload "$pom"     "pom" ""
    uploadArtifactQuick_upload "$file"    "$e"  ""
    uploadArtifactQuick_upload "$sources" "$e"  "sources"
    uploadArtifactQuick_upload "$javadoc" "$e"  "javadoc"
}
lastPackageVersion() {
    listPackageVersions "$@" | head -1
}
listPackageVersions() {
    local repository="$1"; shift
    local          g="$1"; shift
    local          a="$1"; shift

    local   username="${repository/\/*}"
    local  reposname="${repository/*\/}"

    local query='
        query {
            repository(owner:"'"$username"'", name:"'"$reposname"'"){
                packages(names:"'"$g.$a"'",first:1) {
                    nodes {
                        versions(first:100) {
                            nodes {
                                version
                            }
                        }
                    }
                }
            }
        }'
    local select=".data.repository.packages.nodes[0].versions.nodes[].version"

    graphqlQuery "$GITHUB_TOKEN" "$query" "$select"
}
###################
# util for testing (defined here because it is used in multiple projects)
runUploadArtifactTest() {
    local     g="$1"; shift
    local     a="$1"; shift

    local   tmp="tst-$RANDOM"
    local   dwn="$tmp-dwn"
    local     v="$(date +%Y%m%d.%H%M%S)"
    local   pom="tst.pom"

    mkdir "$tmp"
    (   cd "$tmp"
        cat <<EOF > "tst.pom"
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>$g</groupId>
    <artifactId>$a</artifactId>
    <version>$v</version>
    <packaging>jar</packaging>
</project>
EOF
        echo "#tst.jar"         > tst
        echo "#tst-sources.jar" > tst-sources
        echo "#tst-javadoc.jar" > tst-javadoc
        jar cf tst.jar         tst
        jar cf tst-sources.jar tst-sources
        jar cf tst-javadoc.jar tst-javadoc
    )
    uploadArtifactQuick "$g" "$a" "$v" "$tmp/tst.pom" "$tmp/tst.jar" "ModelingValueGroup/tmp"

    sleep 2 # sleep a bit for all artifacts to arrive (from experience we know that this may take some time....)

    downloadArtifactQuick "$g" "$a" "$v" "jar" "$dwn"
    assertEqualFiles "$tmp/tst.pom"         "$dwn/$a.pom"
    assertEqualFiles "$tmp/tst.jar"         "$dwn/$a.jar"
    assertEqualFiles "$tmp/tst-sources.jar" "$dwn/$a-sources.jar"
    assertEqualFiles "$tmp/tst-javadoc.jar" "$dwn/$a-javadoc.jar"
    rm -rf "$tmp" "$dwn"
}
