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

###############################################################################
export            GITHUB_HOST="github.com"
export         GITHUB_BASEURL="https://$GITHUB_HOST"
export GITHUB_PACKAGE_BASEURL="https://maven.pkg.$GITHUB_HOST"
export     GITHUB_API_BASEURL="https://api.$GITHUB_HOST"
###############################################################################
if [[ "${GITHUB_REPOSITORY:-}" == "" ]]; then
    # not on github actions, probably a localbuild: deduce names from git repo:
    export           USERNAME="$(git remote -v | head -1 | sed "s|.*$GITHUB_BASEURL/||;s|.*:||;s|\.git .*||;s/ .*//" | sed 's|\([^/]*\)/\(.*\)|\1|')"
    export          REPOSNAME="$(git remote -v | head -1 | sed "s|.*$GITHUB_BASEURL/||;s|.*:||;s|\.git .*||;s/ .*//" | sed 's|\([^/]*\)/\(.*\)|\2|')"
    export  GITHUB_REPOSITORY="$USERNAME/$REPOSNAME"
else
    # on github actions: deduce names from env var:
    export           USERNAME="${GITHUB_REPOSITORY/\/*}"
    export          REPOSNAME="${GITHUB_REPOSITORY/*\/}"
fi
###############################################################################
export     GITHUB_PACKAGE_URL="$GITHUB_PACKAGE_BASEURL/$GITHUB_REPOSITORY"
export          GIHUB_API_URL="$GITHUB_API_BASEURL/repos/$USERNAME/$REPOSNAME"
export      MAVEN_PACKAGE_URL="https://repo1.maven.org/maven2"
#export         APACHE_PACKAGE_URL="https://repo.maven.apache.org/maven2"
export   SONATYPE_PACKAGE_URL="https://repository.sonatype.org/service/local/repo_groups/forge/content"
export    GITHUB_RELEASES_URL="$GIHUB_API_URL/releases"
export           ARTIFACT_DIR="out/artifacts"                   # default for IntelliJ
export             OUR_DOMAIN="youNeedToSet_OUR_DOMAIN"
export            OUR_PRODUCT="youNeedToSet_OUR_PRODUCT"
###############################################################################
declare -A MAVEN_REPOS_LIST
   MAVEN_REPOS_LIST[maven]="$MAVEN_PACKAGE_URL"
MAVEN_REPOS_LIST[sonatype]="$SONATYPE_PACKAGE_URL"
  MAVEN_REPOS_LIST[github]="$GITHUB_PACKAGE_URL"
export MAVEN_REPOS_LIST
###############################################################################
getGithubSecureUrl() {
    local token="$1"; shift

    printf "https://%s:%s@%s/%s.git" "$GITHUB_ACTOR" "$token" "$GITHUB_HOST" "$GITHUB_REPOSITORY"
}
###############################################################################
export extraLinuxPackages=()
