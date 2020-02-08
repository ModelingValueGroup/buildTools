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

  curl_ "$token" -X POST -d '{"query":"'"$query"'"}' "$GITHUB_API_BASEURL/graphql" -o -
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

    local headerArg=()
    if [[ "$token" != "" ]]; then
        headerArg+=("--header" "Authorization: token $token")
    fi

    curl \
        --location \
        --remote-header-name \
        --fail \
        --silent \
        --show-error \
        "${headerArg[@]}" \
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
assertChecksumsMatch() {
    local errorsFound=0
    local expSum=""
    local   file=""
    local a
    for a in "$@"; do
        if [[ "$expSum" == "" ]]; then
            expSum="$a"
        else
            file="$a"

            local actSum="$(md5sum < "$file" | sed 's/ .*//')"
            if [[ ! ( "$actSum" =~ ^$expSum$ ) ]]; then
                echo "::error::test failed: $file is not generated correctly (md5sum is $actSum not $expSum)" 1>&2
                errorsFound=1
            fi
            expSum=""
        fi
    done

    if [[ "$errorsFound" == 1 ]]; then
        exit 56
    fi
}
assertEqualFiles() {
    local exp="$1"; shift
    local act="$1"; shift

    local expAsTxt
    local actAsTxt

    expAsTxt="$(base64 <"$exp")"
    actAsTxt="$(base64 <"$act")"

    if [[ "$expAsTxt" != "$actAsTxt" ]]; then
        echo "::error::test failed: $exp is not generated correctly (diff '$exp' '$act')" 1>&2
        exit 46
    fi
}
assertEqual() {
    local  v1="$1"; shift
    local  v2="$1"; shift
    local msg="$1"; shift

    if [[ "$v1" != "$v2" ]]; then
        echo "::error::$msg: $v1 != $v2"
        exit 65
    fi
}
getMajor2Version() {
    local fullVersion="$1"; shift

    sed -En 's/([0-9][0-9]*[.][0-9][0-9]*).*/\1/p' <<<"$fullVersion"
}
test_getMajorVersion() {
    assertEqual "$(getMajor2Version "2019.1"    )"  "2019.1"  "getMajorVersion() does not work correctly"
    assertEqual "$(getMajor2Version "2019.1.3"  )"  "2019.1"  "getMajorVersion() does not work correctly"
    assertEqual "$(getMajor2Version "2019.13"   )"  "2019.13" "getMajorVersion() does not work correctly"
    assertEqual "$(getMajor2Version "2019.13.1" )"  "2019.13" "getMajorVersion() does not work correctly"
    assertEqual "$(getMajor2Version "2019.13.12")"  "2019.13" "getMajorVersion() does not work correctly"
}
