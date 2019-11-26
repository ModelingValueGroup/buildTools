#!/usr/bin/env bash
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
