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
    local     g="$1"; shift
    local     a="$1"; shift
    local     v="$1"; shift
    local     e="$1"; shift
    local extra="${1:-}"       # <empty> | javadoc | sources

    if [[ "$extra" != "" ]]; then
        extra="-$extra"
    fi
    printf "%s/%s/%s/%s-%s%s.%s" "${g//.//}" "$a" "$v" "$a" "$v" "$extra" "$e"
}
downloadArtifactQuick() {
    local token="$1"; shift
    local     g="$1"; shift
    local     a="$1"; shift
    local     v="$1"; shift
    local     e="$1"; shift
    local   dir="$1"; shift

    mkdir -p "$dir"

    local f="$dir/$a.$e"
    local fs="$dir/$a-sources.$e"
    local fd="$dir/$a-javadoc.$e"
    local fp="$dir/$a.pom"
    rm -f "$f" "$fs" "$fd" "$fp"

    curl_ "$token" "$GITHUB_PACKAGE_URL/$(makeArtifactPath "$g" "$a" "$v" "$e" "")" -o "$f"
    if [[ ! -f "$f" || -z "$f"  ]]; then
        echo "::error::could not download artifact to $f"
        return 88
    fi
    curl_ "$token" "$GITHUB_PACKAGE_URL/$(makeArtifactPath "$g" "$a" "$v" "$e" "sources")" -o "$fs" 2>/dev/null || echo "::warning::no sources available for $g:$a:$v"
    curl_ "$token" "$GITHUB_PACKAGE_URL/$(makeArtifactPath "$g" "$a" "$v" "$e" "javadoc")" -o "$fd" 2>/dev/null || echo "::warning::no javadoc available for $g:$a:$v"
    curl_ "$token" "$GITHUB_PACKAGE_URL/$(makeArtifactPath "$g" "$a" "$v" "pom" ""      )" -o "$fp" 2>/dev/null || echo "::warning::no pom available for $g:$a:$v"
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
uploadArtifactQuick() {
    local   token="$1"; shift
    local       g="$1"; shift
    local       a="$1"; shift
    local       v="$1"; shift
    local     pom="$1"; shift
    local    file="$1"; shift

    if [[ ! -f "$file" ]]; then
        echo "::error::uploadArtifactQuick: can not find file $file" 1>&2
        exit 75
    fi

    uploadArtifactQuick_upload() {
        local  file="$1"; shift
        local     e="$1"; shift
        local extra="$1"; shift

        if [[ "$file" != "" ]]; then
            local url="$GITHUB_PACKAGE_URL/$(makeArtifactPath "$g" "$a" "$v" "$e" "$extra")"
            curl_ "$token" -X PUT --upload-file "$file" "$url"
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
uploadArtifact() {
    local   token="$1"; shift
    local    gave="$1"; shift
    local     pom="$1"; shift
    local    file="$1"; shift
    local sources="${1:-}"
    local javadoc="${2:-}"

    local g a v e
    gave2vars "$gave" "$pom" "$file"

    if [[ ! -f "$file" ]]; then
        echo "::error::uploadArtifact: can not find file $file" 1>&2
        exit 75
    fi
    local args=("-Dfile=$file")
    if [[ "$sources" != "" ]]; then
        if [[ ! -f "$sources" ]]; then
            echo "::error::uploadArtifact: can not find sources file $sources" 1>&2
            exit 75
        fi
        args+=("-Dsources=$sources")
        if [[ "$javadoc" != "" ]]; then
            if [[ ! -f "$javadoc" ]]; then
                echo "::error::uploadArtifact: can not find javadoc file $javadoc" 1>&2
                exit 75
            fi
            args+=("-Djavadoc=$javadoc")
        fi
    fi

    mvn_ "$token" \
        deploy:deploy-file \
                         -DgroupId="$g" \
                      -DartifactId="$a" \
                         -Dversion="$v" \
                       -Dpackaging="$e" \
                    -DrepositoryId="github" \
                             -Durl="$GITHUB_PACKAGE_URL" \
        "${args[@]}"
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
runUploadArtifactTest() {
    local     g="$1"; shift
    local     a="$1"; shift
    local token="$1"; shift

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
    uploadArtifactQuick   "$token" "$g" "$a" "$v" "$tmp/tst.pom" "$tmp/tst.jar"

    downloadArtifactQuick "$token" "$g" "$a" "$v" "jar" "$dwn"
    mustBeSameContents "$tmp/tst.pom"         "$dwn/$a.pom"
    mustBeSameContents "$tmp/tst.jar"         "$dwn/$a.jar"
    mustBeSameContents "$tmp/tst-sources.jar" "$dwn/$a-sources.jar"
    mustBeSameContents "$tmp/tst-javadoc.jar" "$dwn/$a-javadoc.jar"
    rm -rf "$tmp" "$dwn"
}
