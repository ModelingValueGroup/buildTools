#!/usr/bin/env bash
set -euo pipefail

mvn_() {
  local token="$1"; shift

  generateMavenSettings "$USERNAME" "$token" "$GITHUB_PACKAGE_URL" >settings.xml
  group ${DRY:-} mvn \
    -B \
    -s settings.xml \
    "$@"
  rm settings.xml
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
      "$(xmlstarlet sel -t -v /_:project/_:groupId    <"$pom" 2>/dev/null)" \
      "$(xmlstarlet sel -t -v /_:project/_:artifactId <"$pom" 2>/dev/null)" \
      "$(xmlstarlet sel -t -v /_:project/_:version    <"$pom" 2>/dev/null)" \
      "$(xmlstarlet sel -t -v /_:project/_:packaging  <"$pom" 2>/dev/null)"
  fi
}
