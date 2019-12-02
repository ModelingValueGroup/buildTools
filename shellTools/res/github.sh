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

pushBackToGithub() {
    local token="$1"; shift
    local email="$1"; shift
    local   msg="$1"; shift

    git ls-files --deleted --modified --others --exclude-standard || :
    if [[ "$(git ls-files --deleted --modified --others --exclude-standard)" ]]; then
        echo "changes need to be pushed back to github"

        echo "::group::git commit and push"
            git config user.email "$email"
            git config user.name "$GITHUB_ACTOR"
            git add .
            git commit -m "$msg"
            git push "https://$GITHUB_ACTOR:$token@github.com/$GITHUB_REPOSITORY.git"
        echo "::endgroup::"

    else
        echo "no changes need to be pushed back to github"
    fi
}
