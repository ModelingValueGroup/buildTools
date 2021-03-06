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

# set user mail and name but only if not set yet:
git config user.name  >/dev/null || git config --global user.name  "automation"                     || echo "::info::could not set user.name"
git config user.email >/dev/null || git config --global user.email "automation@modelingvalue.com"   || echo "::info::could not set user.email"

pushBackToGithub() {
    git ls-files --deleted --modified --others --exclude-standard || :
    if [[ "$(git ls-files --deleted --modified --others --exclude-standard)" ]]; then
        echo "::info::changes need to be pushed back to github"

        echo "::group::git commit and push" 1>&2
            git add .
            git commit -m "automatic reformat by actions"
            git push "$(getGithubRepoSecureUrl "$GITHUB_TOKEN" "$GITHUB_REPOSITORY")"
        echo "::endgroup::" 1>&2

    else
        echo "::info::no changes need to be pushed back to github"
    fi
}
errorIfVersionTagExists() {
    . <(catProjectSh 'local ')
    local tagName="v$version"
    git fetch --tags --quiet
    if [[ "$(git tag | fgrep -Fx "$tagName")" == "" ]]; then
        echo "::info::ok: no such tag ($tagName)"
    else
        echo "::info::existing tags:"
        git tag | sed 's/^/::info::   /'
        echo "::error::tag for this version ($tagName) already set, can not build on master"
        exit 89
    fi
}
setVersionTag() {
    . <(catProjectSh 'local ')
    local tagName="v$version"
    git fetch --tags --quiet
    if [[ "$(git tag | fgrep -Fx "$tagName")" == "" ]]; then
        echo "::info::setting tag $tagName"
        git tag "$tagName"
        git push "$(getGithubRepoSecureUrl "$GITHUB_TOKEN" "$GITHUB_REPOSITORY")" "$tagName"
    else
        echo "::error::tag for this version ($tagName) already exists"
        exit 88
    fi
}
findUntaggedVersionNumber() {
    . <(catProjectSh 'local ')
    local initialVersion="$version"
    local        tagName="v$version"
    local     initialTag="$tagName"
    git fetch --tags --quiet
    if [[ "$(git tag | fgrep -Fx "$tagName")" == "" ]]; then
        echo "::info::version $version accepted because there is no tag $tagName for it yet"
    else
        while [[ "$(git tag | fgrep -Fx "$tagName")" != "" ]]; do
            version="$(bumpMinor "$version")"
            tagName="v$version"
        done
        sed -i "s/^version=.*/version='$version'/" project.sh
        echo "::info::version $initialVersion bumped to $version because there already is a tag $initialTag"
    fi
}
bumpMinor() {
    local v="$1"; shift

    if [[ "$v" =~ ^[0-9]+$ ]]; then
        printf "%d" "$((v+1))"
    else
        local n="$(sed 's/^.*[.]//' <<<"$v")"
        local p="$(sed 's/[.][^.]*$//' <<<"$v")"
        printf "%s.%d" "$p" "$((n+1))"
    fi
}
getLatestAsset() {
    local    owner="$1"; shift
    local repoName="$1"; shift
    local     file="$1"; shift

    curl \
        --location \
        --remote-header-name \
        --remote-name \
        --fail \
        --silent \
        --show-error \
        "https://github.com/$owner/$repoName/releases/latest/download/$file"
}
getAllLatestAssets() {
    local    owner="$1"; shift
    local repoName="$1"; shift

    local query='
            {
              repository(owner: "'"$owner"'", name: "'"$repoName"'") {
                releases(last: 1) {
                  nodes {
                    releaseAssets(first:100){
                      nodes{
                        downloadUrl
                      }
                    }
                  }
                }
              }
            }
        '
    local select='.data.repository.releases.nodes[].releaseAssets.nodes[].downloadUrl'

    for u in $(graphqlQuery "$GITHUB_TOKEN" "$query" "$select"); do
        echo "::info::downloading $u..." 1>&2
        curlSave "$GITHUB_TOKEN" "$u"
    done
}
setOutput() {
    local  name="$1"; shift
    if [[ "$#" == 0 ]]; then
        local value="$(cat)"
    else
        local value="$1"
    fi

    if (( 1 < "$(wc -l<<<"$value")" )); then
        value="$( (sed 's/%/%25/g' | awk '{printf "%s%%0A", $0}') <<<"$value")"
    fi

    echo "::set-output name=$name::$value"
}
getGithubRepoSecureUrl() {
    local token="$1"; shift
    local  repo="$1"; shift

    printf "https://%s:%s@%s/%s.git" "$GITHUB_REPOSITORY_OWNER" "$token" "${GITHUB_SERVER_URL#https://}" "$repo"
}
getGithubRepoOpenUrl() {
    local  repo="$1"; shift

    printf "%s/%s.git" "$GITHUB_SERVER_URL" "$repo"
}
