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

group() {
  echo "::group::$1 log" 1>&2
  "$@"
  echo "::endgroup::" 1>&2
}
graphqlQuery() {
  local token="$1"; shift
  local query="$1"; shift

  curl_ "$token" -X POST -d '{"query":"'"$query"'"}' 'https://api.github.com/graphql' -o -
}
contains() {
    local find="$1"; shift
    local  str="$1"; shift

    if [[ "$str" =~ .*$find.* ]]; then
        echo true
    else
        echo false
    fi
}
curl_() {
    local token="$1"; shift

    curl \
        --location \
        --remote-header-name \
        --silent \
        --show-error \
        --header "Authorization: token $token" \
        "$@"
}
validateToken() {
    local token="$1"; shift

    curl_ "$token" "$GIHUB_API_URL"  -o - >/dev/null
}
sedi() {
    if [[ "$OSTYPE" =~ darwin* ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}
compareAndOverwrite() {
    local file="$1"; shift

    local tmp=$(mktemp)

    cat > $tmp
    if [[ ! -f "$file" ]] || ! cmp -s "$tmp" "$file"; then
        mkdir -p "$(dirname "$file")"
        cp "$tmp" "$file"
    fi
    rm "$tmp"
}
