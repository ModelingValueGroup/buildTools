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
##     Wim Bast, Carel Bast, Tom Brus                                                                                  ~
## Contributors:                                                                                                       ~
##     Arjan Kok, Ronald Krijgsheld                                                                                    ~
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

set -euo pipefail

###############################################################################
export         GITHUB_BASEURL="https://github.com"
export GITHUB_PACKAGE_BASEURL="https://maven.pkg.github.com"
export     GITHUB_API_BASEURL="https://api.github.com"
###############################################################################
if [[ "${GITHUB_REPOSITORY:-}" == "" ]]; then
  # not on github actions, probably a localbuild
  export           USERNAME="$(git remote -v | head -1 | sed "s|.*$GITHUB_BASEURL/||;s|.*:||;s|\.git .*||;s/ .*//" | sed 's|\([^/]*\)/\(.*\)|\1|')"
  export          REPOSNAME="$(git remote -v | head -1 | sed "s|.*$GITHUB_BASEURL/||;s|.*:||;s|\.git .*||;s/ .*//" | sed 's|\([^/]*\)/\(.*\)|\2|')"
  export  GITHUB_REPOSITORY="$USERNAME/$REPOSNAME"
else
  # on github actions
  export           USERNAME="${GITHUB_REPOSITORY/\/*}"
  export          REPOSNAME="${GITHUB_REPOSITORY/*\/}"
fi
###############################################################################
export     GITHUB_PACKAGE_URL="$GITHUB_PACKAGE_BASEURL/$GITHUB_REPOSITORY"
export          GIHUB_API_URL="$GITHUB_API_BASEURL/repos/$USERNAME/$REPOSNAME"
export           ARTIFACT_DIR="out/artifacts" # default for IntelliJ
export             OUR_DOMAIN="you.need.to.set.OUR_DOMAIN"
export            OUR_PRODUCT="youNeedToSet_OUR_PRODUCT"
###############################################################################
export    CHANGES_MADE_MARKER=changes-made
###############################################################################
