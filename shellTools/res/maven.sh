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

extraLinuxPackages+=(xmlstarlet)
extraLinuxPackages+=(maven:mvn)

mvn_() {
    local token="$1"; shift

    local settings=settings$RANDOM.xml
    generateMavenSettings "$USERNAME" "$token" "$GITHUB_PACKAGE_URL/$GITHUB_REPOSITORY" >$settings
    group ${DRY:-} mvn \
        -B \
        -s $settings \
        "$@"
    rm $settings
}
generateMavenSettings() {
    local   username="$1"; shift
    local   password="$1"; shift
    local repository="$1"; shift

    . <(catProjectSh -maybeAbsent 'local ')
    reposSnippet_() {
        local url="$1"; shift
        cat <<EOF
          <repository>
            <id>$(sed 's/[^a-zA-Z0-9]/_/g' <<<"$url")</id>
            <url>$url</url>
          </repository>
EOF
    }
    
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
$(for url in "${repositories[@]}" ; do
    if [[ "$url" != "" ]]; then
        reposSnippet_ "$url"
    fi
done)
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
    echo "::error::can not determine group and artifact from '$gave' and '$pom'" 1>&2
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
      "$(xmlstarlet sel -t -v /_:project/_:groupId    "$pom" 2>/dev/null)" \
      "$(xmlstarlet sel -t -v /_:project/_:artifactId "$pom" 2>/dev/null)" \
      "$(xmlstarlet sel -t -v /_:project/_:version    "$pom" 2>/dev/null)" \
      "$(xmlstarlet sel -t -v /_:project/_:packaging  "$pom" 2>/dev/null)"
  fi
}
