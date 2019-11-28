#!/usr/bin/env bash
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
