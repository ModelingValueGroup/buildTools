#!/usr/bin/env bash
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
    if [[ -f "$file" ]] && cmp -s "$tmp" "$file"; then
        rm "$tmp"
    else
        mv "$tmp" "$file"
        echo "$file" >> "$CHANGES_MADE_MARKER"
    fi

}