#!/usr/bin/env bash
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## (C) Copyright 2018-2020 Modeling Value Group B.V. (http://modelingvalue.org)                                        ~
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

export SNAPSHOTS_REPOS="tmp-snapshots"
export SNAPSHOTS_CLONE="/tmp/$SNAPSHOTS_REPOS"

retrieveBranchSnapshots() {
    local branch="$1"; shift
    local    lib="$1"; shift

    prepareBranchSnapshots "${ALLREP_TOKEN:-$GITHUB_TOKEN}" "$branch"
    local yamls=( $(findTriggerYamls) )

    if [[ "${#yamls[@]}" == 0 ]]; then
        echo "::error::could not find proper workflow files for retriggering builds (use 'on: [push, workflow_dispatch]' in one or more yaml files in '.github/workflows'"
    fi

    local g a v e flags
    while read g a v e flags; do
        if [[ $g != '' ]]; then
            local artiTrgDir="$SNAPSHOTS_CLONE/trigger/${g//./\/}/$a"
            local artiLibDir="$SNAPSHOTS_CLONE/lib/${g//./\/}/$a"

            mkdir -p "$artiTrgDir"
            (
                echo "TRIGGER_REPOSITORY='$GITHUB_REPOSITORY'"
                echo "TRIGGER_BRANCH='$branch'"
                echo "TRIGGER_YAMLS=( $(for a in "${yamls[@]}"; do printf "'%s' " "$a"; done))"
            ) > "$artiTrgDir/${GITHUB_REPOSITORY////#}.trigger"

            local parts=()
            if [[ "$flags" =~ .*j.* ]]; then parts+=("$a"        ); fi
            if [[ "$flags" =~ .*d.* ]]; then parts+=("$a-javadoc"); fi
            if [[ "$flags" =~ .*s.* ]]; then parts+=("$a-sources"); fi
            local aa
            for aa in "${parts[@]}"; do
                local f="$artiLibDir/$aa.$e"
                if [[ -f "$f" ]]; then
                    echo "::info::got snapshot for $g:$aa on branch $branch ($f)"
                    cp "$f" "$lib"
                else
                    echo "::info::no snapshot for $g:$aa on branch $branch ($f)"
                fi
            done
        fi
    done < <(getDependencyGavesWithFlags)
    pushBranchSnapshots # for trigger files
}
findTriggerYamls() {
    if [[ -d ".github/workflows" ]]; then
        (   cd ".github/workflows"
            egrep "^on: " *.{yaml,yml} 2>/dev/null | fgrep workflow_dispatch | fgrep push | sed 's/:.*//'
        )
    fi
}
storeMyBranchSnapshots() {
    local g a v e flags
    read -r g a v e flags < <(getFirstArtifactWithFlags)
    if [[ "$g" != "" && "$a" != "" ]]; then
        echo "::info::storing artifacts $g:$a in the branch snapshot repo"
        storeBranchSnapshots \
            "${ALLREP_TOKEN:-$GITHUB_TOKEN}"  \
            "out/artifacts"  \
            "$g"             \
            "$a"             \
            "$GITHUB_REF"
    else
        echo "::info::can not find the artifact we are producing in $PROJECT_SH"
    fi
}
storeBranchSnapshots() {
    local    token="$1"; shift
    local   srcDir="$1"; shift
    local    group="$1"; shift
    local artifact="$1"; shift
    local   branch="$1"; shift

    local bareBranch="${branch#refs/heads/}"
    local    subPath="${group//./\/}/$artifact"

    prepareBranchSnapshots     "$token"  "$bareBranch"
    copyAndPushBranchSnapshots "$srcDir" "$subPath"
    pushBranchSnapshots
    triggerBranchSnapshots     "$token"  "$subPath"
}
prepareBranchSnapshots() {
    local      token="$1"; shift
    local bareBranch="$1"; shift

    local repoUrl="$(getGithubRepoSecureUrl "$token" "$GITHUB_REPOSITORY_OWNER/$SNAPSHOTS_REPOS")"

    if [[ -d "$SNAPSHOTS_CLONE/.git" ]] && (cd "$SNAPSHOTS_CLONE"; git fsck --full --no-progress >/dev/null 2>&1); then
        echo "::info::clone of $repoUrl already on disk: $SNAPSHOTS_CLONE"
        git fetch --all
    else
        rm -rf "$SNAPSHOTS_CLONE"
        mkdir -p "$SNAPSHOTS_CLONE"
        if (cd "$SNAPSHOTS_CLONE/.."; git clone "$repoUrl"); then
            echo "::info::cloned $repoUrl"
        else
            echo "::info::clone of $repoUrl not possible: create new repo"
            (   cd "$SNAPSHOTS_CLONE"
                echo "::info::create repos $GITHUB_REPOSITORY_OWNER/$SNAPSHOTS_REPOS"
                printf "%s\n%s\n%s\n" "# Branch Snapshots repo" "Build files from branches are stored here for other projects to depend on." "This is an ephemeral repo." > "README.md"
                git init
                git add "README.md"
                git commit -m "first commit"
                git remote add origin "$repoUrl"
                curl -X POST \
                        --location \
                        --remote-header-name \
                        --fail \
                        --silent \
                        --show-error \
                        --header "Authorization: token $token" \
                        -d '{"name":"'"$SNAPSHOTS_REPOS"'"}' \
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
    fi

    if [[ ! -d "$SNAPSHOTS_CLONE/.git" ]]; then
        echo "::error::could not clone or create $GITHUB_REPOSITORY_OWNER/$SNAPSHOTS_REPOS" 1>&2
        exit 24
    fi

    (   cd "$SNAPSHOTS_CLONE"
        echo "::info::checkout $bareBranch"
        if ! git checkout "$bareBranch"; then
            echo "::info::need to create new branch $bareBranch"
            git checkout _
            git checkout -b "$bareBranch"
            git push -u origin "$bareBranch"
        fi
        git pull --ff-only
    )
}
copyAndPushBranchSnapshots() {
    local  srcDir="$1"; shift
    local subPath="$1"; shift

    mkdir -p "$SNAPSHOTS_CLONE/lib/$subPath"
    cp -r "$srcDir/"* "$SNAPSHOTS_CLONE/lib/$subPath"
}
pushBranchSnapshots() {
    (   cd "$SNAPSHOTS_CLONE"
        echo "::info::pushing"
        git add .
        if git commit -a -m "branch assets @$(date +'%Y-%m-%d %H:%M:%S')"; then
            echo "::info::need to push"
            git push
        fi
    )
}
triggerBranchSnapshots() {
    local   token="$1"; shift
    local subPath="$1"; shift

    local triggerFile
    for triggerFile in "$SNAPSHOTS_CLONE/trigger/$subPath"/*; do
        if [[ -f "$triggerFile" ]]; then
            local TRIGGER_REPOSITORY=
            local TRIGGER_BRANCH=
            local TRIGGER_YAMLS=()
            . "$triggerFile"
            triggerOtherRepoBuild "$token" "$TRIGGER_REPOSITORY" "$TRIGGER_BRANCH" "${TRIGGER_YAMLS[@]:-}"
        fi
    done
}
triggerOtherRepoBuild() {
    local   token="$1"; shift
    local    repo="$1"; shift
    local  branch="$1"; shift
    local   yamls=("${@:-build.yaml}")  # just take build.yaml if no yamls available (backwards compat)

    if true; then
        # experimental feature: trigger through workflow dispatch....
        local yaml
        for yaml in "${yamls[@]}"; do
            local url="$GITHUB_API_URL/repos/$repo/actions/workflows/$yaml/dispatches"
            echo "::info::triggering repo=$repo branch=$branch workflow=$yaml: $url"
            curlPipe \
                    "$token" \
                    -X POST \
                    -H "Accept: application/vnd.github.v3+json" \
                    -d '{"ref":"'"$branch"'"}' \
                    "$url" \
                    -o - \
                    || echo "::info::trigger failed but we ignore this for now"
        done
    else
        local i totalCount conclusion message rerunUrl
        local tmpJson="runs.json"

        firstFieldFromJsonLog() {
            local field="$1"; shift

            (grep -E "^ *\"$field\": " "$tmpJson" | head -1 | sed 's/^[^:]*: *//;s/,$//;s/"//g') || :
        }

        echo "====== triggering: $repo  [$branch]"
        for i in $(seq 0 600); do
            curl -s \
                -u "automation:$token"  \
                "https://api.github.com/repos/$repo/actions/runs?branch=$branch" \
                -o "$tmpJson"

            totalCount="$(firstFieldFromJsonLog "totalCount")"
            conclusion="$(firstFieldFromJsonLog "conclusion")"
               message="$(firstFieldFromJsonLog "message")"
              rerunUrl="$(firstFieldFromJsonLog "rerun_url")"

            echo "::info::totalCount=$totalCount"
            echo "::info::conclusion=$conclusion"
            echo "::info::   message=$message"
            echo "::info:: rerun_url=$rerunUrl"

            if [[ "$totalCount" == 0 || "$conclusion" != "null" ]]; then
                break
            fi
            echo "::info::waiting for build on $repo branch $branch to finish ($i...)"
            sleep 2
        done
        if [[ "$totalCount" == 0 ]]; then
            echo "::warning:: no build on $repo branch $branch, retrigger impossible..."
        elif [[ "$conclusion" == "null" ]]; then
            echo "::warning::I have waited a long time but the build on $repo branch $branch did not finish yet, giving up..."
        elif [[ "$conclusion" != "failure" ]]; then
            echo "::warning::the latest build on $repo branch $branch did not finish with failure (but $conclusion), retrigger impossible, sorry..."
        else
            echo "::info::triggering: $rerunUrl"
            curl -s \
                -XPOST \
                -u "automation:$token"  \
                "$rerunUrl" \
                -o "$tmpJson"

            message="$(firstFieldFromJsonLog "message")"
            if [[ "$message" == "Unable to re-run this workflow run because it was created over a month ago" ]]; then
                echo "::warning::the latest build on $repo branch $branch is too old, retrigger impossible, sorry..."
            else
                echo "::info::triggering yielded: $message"
            fi
        fi
    fi
}
