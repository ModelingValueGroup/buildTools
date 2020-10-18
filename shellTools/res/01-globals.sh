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

if ! (echo 4.0.0; echo $BASH_VERSION) | sort -VC; then
    echo "::error::this shell version ($BASH_VERSION) is too old, I need at least bash 5.0.0."
    exit 99
fi

if [[ ${GITHUB_ACTIONS:-} == "" ]]; then
    # not on github actions, probably a localbuild: deduce vars from git repo:
    #=============================
    export     GITHUB_SERVER_URL="https://github.com"
    export        GITHUB_API_URL="https://api.github.com"
    export    GITHUB_GRAPHQL_URL="https://api.github.com/graphql"
    #=============================
    #          GITHUB_EVENT_PATH="/home/runner/work/_temp/_github_workflow/event.json"
    #           GITHUB_WORKSPACE="/home/runner/work/yyyy/yyyy"
    #          GITHUB_EVENT_NAME="push"
    #=============================
    export     GITHUB_REPOSITORY="$(git remote -v 2>/dev/null | head -1 | sed "s|.*$GITHUB_SERVER_URL/||;s|.*:[^/]*/||;s|\.git .*||;s/ .*//")"
    #    GITHUB_REPOSITORY_OWNER="xxxx"
    export          GITHUB_ACTOR="${USER:-ModelingValueGroup}"
    #=============================
                      GITHUB_REF="$(git symbolic-ref HEAD 2>/dev/null)"
    #            GITHUB_BASE_REF=""
    #            GITHUB_HEAD_REF=""
    #                GITHUB_SHA="1234567890"
    #=============================
    #              GITHUB_ACTION="aaaa"
    #            GITHUB_WORKFLOW="wwww"
    #                 GITHUB_JOB="jjjj"
    #=============================
    #              GITHUB_RUN_ID="nnnn"
    #          GITHUB_RUN_NUMBER="mmmm"
    #=============================
else
    # on github actions: the following are passed in by github: (for repo xxxx/yyyy)
    #=============================
    #           GITHUB_SERVER_URL="https://github.com"
    #              GITHUB_API_URL="https://api.github.com"
    #          GITHUB_GRAPHQL_URL="https://api.github.com/graphql"
    #=============================
    #           GITHUB_EVENT_PATH="/home/runner/work/_temp/_github_workflow/event.json"
    #            GITHUB_WORKSPACE="/home/runner/work/yyyy/yyyy"
    #           GITHUB_EVENT_NAME="push"
    #=============================
    #           GITHUB_REPOSITORY="xxxx/yyyy"
    #     GITHUB_REPOSITORY_OWNER="xxxx"
    #                GITHUB_ACTOR="ModelingValueGroup"
    #=============================
    #                  GITHUB_REF="refs/heads/bbbb"
    #             GITHUB_BASE_REF=""
    #             GITHUB_HEAD_REF=""
    #                  GITHUB_SHA="1234567890"
    #=============================
    #               GITHUB_ACTION="aaaa"
    #             GITHUB_WORKFLOW="wwww"
    #                  GITHUB_JOB="jjjj"
    #=============================
    #               GITHUB_RUN_ID="nnnn"
    #           GITHUB_RUN_NUMBER="mmmm"
    #=============================
    :
fi
###############################################################################
export               USERNAME="${GITHUB_REPOSITORY/\/*}"
export              REPOSNAME="${GITHUB_REPOSITORY/*\/}"
export     GITHUB_PACKAGE_URL="https://maven.pkg.github.com"
export   GITHUB_API_REPOS_URL="$GITHUB_API_URL/repos/$USERNAME/$REPOSNAME"
export    GITHUB_RELEASES_URL="$GITHUB_API_REPOS_URL/releases"
###############################################################################
export      MAVEN_PACKAGE_URL="https://repo1.maven.org/maven2"
export   SONATYPE_PACKAGE_URL="https://repository.sonatype.org/service/local/repo_groups/forge/content"
export           ARTIFACT_DIR="out/artifacts"                   # default for IntelliJ
export             OUR_DOMAIN="youNeedToSet_OUR_DOMAIN"
export     extraLinuxPackages=()
export    errorDetectedMarker="errorDetectedMarker"
###############################################################################
declare -A MAVEN_REPOS_LIST
export     MAVEN_REPOS_LIST
# NB: do not init with ([xxx]=xxx) the shell on github actions does not allow this!
   MAVEN_REPOS_LIST[maven]="$MAVEN_PACKAGE_URL"
MAVEN_REPOS_LIST[sonatype]="$SONATYPE_PACKAGE_URL"
  MAVEN_REPOS_LIST[github]="$GITHUB_PACKAGE_URL/$GITHUB_REPOSITORY"
###############################################################################
getGithubRepoSecureUrl() {
    local token="$1"; shift
    local  repo="$1"; shift

    printf "%s/%s.git" "$(sed "s|https://|&$GITHUB_ACTOR:$token@|" <<<"$GITHUB_SERVER_URL")" "$repo"
}
getGithubRepoOpenUrl() {
    local  repo="$1"; shift

    printf "%s/%s.git" "$GITHUB_SERVER_URL" "$repo"
}
###############################################################################
if [[ "${ANT_HOME:-}" == "" ]]; then
    if [[ -d "/opt/local/share/java/apache-ant" ]]; then # default for mac
        export ANT_HOME="/opt/local/share/java/apache-ant"
    else
        echo "ERROR: ANT_HOME not set and can not be determined"
        exit 37
    fi
fi
