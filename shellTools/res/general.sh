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

group() {
    echo "::group::$1 log" 1>&2
    "$@"
    echo "::endgroup::" 1>&2
}
graphqlQuery() {
    local  token="$1"; shift
    local  query="$1"; shift
    local select="$1"; shift

    local rawQuery="$(sed 's/"/\\"/g' <<<"$query"| tr '\n\r' '  ' | sed 's/  */ /g')"

    curlPipe \
            "$token" \
            -X POST \
            -d '{"query":"'"$rawQuery"'"}' \
            "$GITHUB_GRAPHQL_URL" \
            -o - \
        | jq -r "$select" 2>/dev/null
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
#
# curl call with automatic authorisation header if token as arg and
#   --remote-header-name : use filename as indicated by server
#   --remote-name        : save in file in current dir
#
curlSave() {
    local token="$1"; shift

    curlPipe "$token" --remote-header-name --remote-name "$@"
}
#
# curl call with automatic authorisation header if token as arg and
#   --location      : follow redirects
#   --fail          : fail silently
#   --silent        : no progress or errors reported
#   --show-error    : show error message on fail
#
curlPipe() {
    local token="$1"; shift

    local headerArg=()
    if [[ "$token" != "" ]]; then
        headerArg+=("--header" "Authorization: token $token")
    fi

    curl \
        "${headerArg[@]}" \
        --location \
        --fail \
        --silent \
        --show-error \
        "$@"
}
validateToken() {
    local token="$1"; shift

    curlPipe "$token" "$GITHUB_API_REPOS_URL"  -o - >/dev/null
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
    local a expSum file errorsFound=0
    for a in "$@"; do
        IFS=: read expSum file <<<"$a"
        if [[ ! -f "$file" ]]; then
            echo "::error::test failed: $file missing" 1>&2
        else
            local actSum="$(md5sum < "$file" | sed 's/ .*//')"
            if [[ ! ( "$actSum" =~ ^$expSum$ ) ]]; then
                echo "::error::test failed: $file was not generated correctly (md5sum is $actSum not $expSum)" 1>&2
                touch "$errorDetectedMarker"
               errorsFound=1
            fi
        fi
    done

    if [[ "$errorsFound" == 1 ]]; then
        exit 56
    fi
}
assertEqualFiles() {
    local exp="$1"; shift
    local act="$1"; shift

    if [[ ! -f "$exp" ]]; then
        echo "::error::test failed: $exp not found" 1>&2
        touch "$errorDetectedMarker"
        exit 46
    fi
    if [[ ! -f "$act" ]]; then
        echo "::error::test failed: $act not found" 1>&2
        touch "$errorDetectedMarker"
        exit 46
    fi

    local expAsTxt
    local actAsTxt

    expAsTxt="$(base64 <"$exp")"
    actAsTxt="$(base64 <"$act")"

    if [[ "$expAsTxt" != "$actAsTxt" ]]; then
        echo "::error::test failed: $act was not generated correctly (diff '$PWD/$exp' '$PWD/$act')" 1>&2
        touch "$errorDetectedMarker"
        exit 46
    fi
}
assertEqual() {
    local  v1="$1"; shift
    local  v2="$1"; shift
    local msg="$1"; shift

    if [[ "$v1" != "$v2" ]]; then
        echo "::error::$msg: $v1 != $v2" 1>&2
        touch "$errorDetectedMarker"
        exit 65
    fi
}
assertFileContains() {
    local total="$1"; shift
    local  file="$1"; shift
    local   cnt="$1"; shift
    local  patt="$1"; shift

    if [[ ! -f "$file" ]]; then
        echo "::error::did not find expected file $file" 1>&2
        exit 34
    else
        if (( $total != -1 && $(wc -l < "$file") != $total )); then
            echo "::error::expected $total lines in '$file' but found :" $(wc -l < "$file") 1>&2
            sed "s/^/  | /;s/  | \(.*$patt\)/  > \1/" "$file"
            touch "$errorDetectedMarker"
        fi
        local n="$(egrep "$patt" "$file" | wc -l | sed 's/ //g')"
        if [[ "$cnt" != "$n" ]]; then
            echo "::error::expected $cnt lines but found $n lines containing '$patt' in '$file':" 1>&2
            sed "s/^/  | /;s/  | \(.*$patt\)/  > \1/" "$file"
            touch "$errorDetectedMarker"
        fi
        if [[ -f "$errorDetectedMarker" ]]; then
            exit 35
        fi
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
doubleBuild() {
    local func="$1"; shift
    local file="$1"; shift

    local tmp="/tmp/doubleBuild-$$"
    cp "$file" "$tmp-pre"
    "$func"
    cp "$file" "$tmp-pst"

    if ! diff -q <(sed -e '$a\' "$tmp-pre" 2>/dev/null) <(sed -e '$a\' "$tmp-pst" 2>/dev/null) >/dev/null; then
        diff "$tmp-pre" "$tmp-pst" | sed 's/^/   DIFF|/' || :
        echo "::info::building changed the key file '$file': trying again..."
        "$func"
        cp "$file" "$tmp-pst2"

        if ! diff -q <(sed -e '$a\' "$tmp-pst" 2>/dev/null) <(sed -e '$a\' "$tmp-pst2" 2>/dev/null) >/dev/null; then
            diff "$tmp-pst" "$tmp-pst2" | sed 's/^/   DIFF|/' || :
            echo "::error::rebuilding changed the key file '$file' again: giving up..."
            exit 25
        fi
    fi
}
