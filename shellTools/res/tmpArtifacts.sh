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

export ARTIFACTS_REPOS="tmp-artifacts"
export ARTIFACTS_CLONE="/tmp/artifacts/$ARTIFACTS_REPOS"

storeTmpArtifacts() {
    local    token="$1"; shift
    local   srcDir="$1"; shift
    local    group="$1"; shift
    local artifact="$1"; shift
    local   branch="$1"; shift

    local bareBranch="${branch#refs/heads/}"
    local    subPath="${group//./\/}/$artifact"

    prepareTmpArtifacts     "$token"  "$bareBranch"
    copyAndPushTmpArtifacts "$srcDir" "$subPath"
    pushTmpArtifacts
    triggerTmpArtifacts     "$token"  "$subPath"
}
prepareTmpArtifacts() {
    local      token="$1"; shift
    local bareBranch="$1"; shift

    rm -rf "$ARTIFACTS_CLONE"
    mkdir -p "$ARTIFACTS_CLONE"
    (   cd "$ARTIFACTS_CLONE/.."
        if [[ -d "$ARTIFACTS_REPOS/.git" ]]; then
            echo "::info::clone already on disk"
        elif git clone "$(getGithubRepoSecureUrl "$token" "$GITHUB_REPOSITORY_OWNER/$ARTIFACTS_REPOS")"; then
            echo "::info::clone made"
        else
            echo "::info::create new repo"
            (   cd "$ARTIFACTS_CLONE"
                echo "::info::create repos $GITHUB_REPOSITORY_OWNER/$ARTIFACTS_REPOS"
                printf "%s\n%s\n" "# ephemeral artifacts repo" "Build assets from branches are stored here. This is an ephemeral repo." > "README.md"
                git init
                git add "README.md"
                git commit -m "first commit"
                git remote add origin "git@github.com:$GITHUB_REPOSITORY_OWNER/$ARTIFACTS_REPOS.git"
                curl -X POST \
                        --location \
                        --remote-header-name \
                        --fail \
                        --silent \
                        --show-error \
                        --header "Authorization: token $token" \
                        -d '{"name":"'"$ARTIFACTS_REPOS"'"}' \
                        "$GITHUB_API_URL/orgs/$GITHUB_REPOSITORY_OWNER/repos" \
                        -o - \
                    | jq .
               git push -u origin master

               git checkout -b _
               git push -u origin _

               git checkout -b develop
               git push -u origin develop
            )
        fi

        if [[ ! -d "$ARTIFACTS_REPOS/.git" ]]; then
            echo "::error::could not clone or create $GITHUB_REPOSITORY_OWNER/$ARTIFACTS_REPOS" 1>&2
            exit 24
        fi
        sed 's/^/@@@ /' "$ARTIFACTS_REPOS/.git/config" //TODO

        (   cd "$ARTIFACTS_CLONE"
            echo "::info::checkout $bareBranch"
            if ! git checkout "$bareBranch"; then
                echo "::info::need to create new branch $bareBranch"
                git checkout _
                git checkout -b "$bareBranch"
                git push -u origin "$bareBranch"
            else # TODO
                # just try to push a new branch to test writability
                local tmpBranch="tmp/$RANDOM"
                git checkout -b "$tmpBranch"
                if ! git push origin "$tmpBranch"; then
                    echo "::error::CAN NOT PUSH TO ARTIFACT REPO"
                    exit 66
                fi
                git branch -d "$tmpBranch"
                git push origin -delete "$tmpBranch"
            fi
        )
    )
}
copyAndPushTmpArtifacts() {
    local  srcDir="$1"; shift
    local subPath="$1"; shift

    mkdir -p "$ARTIFACTS_CLONE/lib/$subPath"
    cp -r "$srcDir/" "$ARTIFACTS_CLONE/lib/$subPath"
}
pushTmpArtifacts() {
    (   cd "$ARTIFACTS_CLONE"
        echo "::info::pushing"
        git add .
        if git commit -a -m "branch assets @$(date +'%Y-%m-%d %H:%M:%S')"; then
            echo "::info::need to push"
            git push
        fi
    )
}
triggerTmpArtifacts() {
    local   token="$1"; shift
    local subPath="$1"; shift

    local triggerFile
    for triggerFile in "$ARTIFACTS_CLONE/trigger/$subPath"/*; do
        if [[ -f "$triggerFile" ]]; then
            . "$triggerFile"
            triggerOther "$token" "$TRIGGER_REPOSITORY" "$TRIGGER_BRANCH"
        fi
    done
}
