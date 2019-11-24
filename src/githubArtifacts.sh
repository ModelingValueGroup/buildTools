#!/usr/bin/env bash
set -euo pipefail

group() {
  echo "::group::$1 log" 1>&2
  "$@"
  echo "::endgroup::" 1>&2
}
downloadArtifactQuick() {
  local token="$1"; shift
  local     g="$1"; shift
  local     a="$1"; shift
  local     v="$1"; shift
  local     e="$1"; shift
  local   dir="$1"; shift

  group curl -H "Authorization: bearer $token" -L "$GITHUB_PACKAGE_URL/$g.$a/$v/$a-$v.$e" -o "$dir/$a.$e"
}
downloadArtifact() {
  local token="$1"; shift
  local     g="$1"; shift
  local     a="$1"; shift
  local     v="$1"; shift
  local     e="$1"; shift
  local   dir="$1"; shift

  generateMavenSettings "$USERNAME" "$token" "$GITHUB_PACKAGE_URL" >settings.xml
  group mvn \
    -B \
    -s settings.xml \
    org.apache.maven.plugins:maven-dependency-plugin:LATEST:copy \
               -Dartifact="$g:$a:$v:$e" \
        -DoutputDirectory="$dir" \
      -Dmdep.stripVersion="true"
  rm settings.xml
}
uploadArtifact() {
  local token="$1"; shift
  local  gave="$1"; shift
  local   pom="$1"; shift
  local  file="$1"; shift

  local g a v e
  gave2vars "$gave" "$pom" "$file"

  generateMavenSettings "$USERNAME" "$token" "$GITHUB_PACKAGE_URL" > settings.xml

  ${DRY:-} mvn \
    -B \
    -s settings.xml \
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
generateMavenSettings() {
  local   username="$1"; shift
  local   password="$1"; shift
  local repository="$1"; shift

  cat  <<EOF
  <settings xmlns="http://maven.apache.org/SETTINGS/1.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 http://maven.apache.org/xsd/settings-1.0.0.xsd">
    <activeProfiles>
      <activeProfile>github</activeProfile>
    </activeProfiles>

    <profiles>
      <profile>
        <id>github</id>
        <repositories>
          <repository>
            <id>central</id>
            <url>https://repo1.maven.org/maven2</url>
            <releases><enabled>true</enabled></releases>
            <snapshots><enabled>false</enabled></snapshots>
          </repository>
          <repository>
            <id>github</id>
            <name>GitHub Apache Maven Packages</name>
            <url>$repository</url>
          </repository>
        </repositories>
      </profile>
    </profiles>

    <servers>
      <server>
        <id>github</id>
        <username>$username</username>
        <password>$password</password>
      </server>
    </servers>
  </settings>
EOF
}
graphqlQuery() {
  local token="$1"; shift
  local query="$1"; shift

  curl -s -H "Authorization: bearer $token" -X POST -d '{"query":"'"$query"'"}' 'https://api.github.com/graphql'
}
lastPackageVersion() {
  listPackageVersions "$@" | tail -1
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
  query="$(cat <<EOF | sed 's/"/\\"/g' | tr '\n\r' '  '
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
  graphqlQuery "$token" "$query" | jq -r '.data.repository.registryPackages.nodes[0].versions.nodes[].version'
}
gave2vars() {
  local gave="$1"; shift
  local  pom="$1"; shift
  local file="$1"; shift

  if [[ $gave == "" && -f "$pom" ]]; then
    gave="$(extractGaveFromPom "$pom")"
  fi
  if [[ $gave == "" && -f "pom.xml" ]]; then
    gave="$(extractGaveFromPom "pom.xml")"
  fi
  if [[ "$gave" == "" ]]; then
    echo "::error::can not determine group and artifact from '$gave' and '$pom'"
    exit 55
  fi
  export g a v e
  IFS=: read -r g a v e <<<"$gave"
  if [[ $e == "" && "$file" != "" ]]; then
    e="${file##*.}"
  fi
}
extractGaveFromPom() {
  local  pom="$1"; shift

  if [[ -f "$pom" ]]; then
    printf "%s:%s:%s:%s" \
      "$(xmlstarlet sel -t -v /_:project/_:groupId    <"$pom")" \
      "$(xmlstarlet sel -t -v /_:project/_:artifactId <"$pom")" \
      "$(xmlstarlet sel -t -v /_:project/_:version    <"$pom")" \
      "$(xmlstarlet sel -t -v /_:project/_:packaging  <"$pom")"
  fi
}
