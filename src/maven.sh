#!/usr/bin/env bash
set -euo pipefail

makeAllPoms() {
    local productUrl="$1"; shift
    local     gitUrl="$1"; shift
    local    version="$1"; shift

    rm -f "$ARTIFACT_DIR"/*.pom
    mkdir -p "$ARTIFACT_DIR"
    for name in "$@"; do
        makePomFromGavs "$productUrl" "$gitUrl" "$version" "$name" "$(findDescription "$name")" $(findAllGavsOf "$name")
    done
    makePomFromGavs "$productUrl" "$gitUrl" "unused" "ALL" "unused" $(findAllGavs)
}
makePomFromGavs() {
    local  productUrl="$1"; shift
    local      gitUrl="$1"; shift
    local     version="$1"; shift
    local        name="$1"; shift
    local description="$1"; shift
    local        gavs=("$@")

    genDependencies() {
        for gav in "$@"; do
            IFS=: read g a v <<<"$gav"
            cat <<EOF
        <dependency>
            <groupId>$g</groupId>
            <artifactId>$a</artifactId>
            <version>$v</version>
        </dependency>
EOF
        done
    }

    mkdir -p "$ARTIFACT_DIR"
    local pom="$ARTIFACT_DIR/$name-SNAPSHOT.pom"
    cat <<EOF >"$pom"
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
                             http://maven.apache.org/maven-v4_0_0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>$OUR_DOMAIN.$OUR_PRODUCT</groupId>
    <artifactId>$name</artifactId>
    <version>$([[ $version == SNAPSHOT ]] && echo "0.0.0-SNAPSHOT" || echo "$version")</version>
    <packaging>jar</packaging>

    <name>$OUR_PRODUCT $name</name>
    <description>$description</description>
    <url>$productUrl</url>

    <licenses>
        <license>
            <name>GNU Lesser General Public License v3.0</name>
            <url>https://www.gnu.org/licenses/lgpl-3.0.en.html</url>
            <distribution>repo</distribution>
        </license>
    </licenses>

    <scm>
        <url>$gitUrl</url>
    </scm>

    <dependencies>
$([[ "${#gavs[@]}" != 0 ]] && genDependencies "${gavs[@]}")
    </dependencies>
</project>
EOF
    echo "    generated $pom"
}
findAllGavsOf() {
    local name="$1"; shift

    for iml in "$OUR_DOMAIN".$name/*.iml "$OUR_DOMAIN".$name.*/*.iml; do
        fgrep '"Maven: ' $iml | fgrep -v 'scope="TEST"' | sed 's/.*"Maven: //;s/".*//'
    done | sort -u
}
findAllGavs() {
    for iml in */*.iml; do
        fgrep '"Maven: ' $iml | sed 's/.*"Maven: //;s/".*//'
    done | sort -u
}
findDescription() {
    local name="$1"; shift

    for i in "$OUR_DOMAIN".$name "$OUR_DOMAIN".$name.*; do
        cat "$i/description" 2>/dev/null || :
    done
}
