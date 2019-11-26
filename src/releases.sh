#!/usr/bin/env bash
set -euo pipefail

getRelease() {
    local token="$1"; shift
    local   tag="$1"; shift

    curl_ "$token" "$GIHUB_API_URL/releases/tags/$tag" -o -
}
getLatestRelease() {
    local token="$1"; shift

    curl_ "$token" "$GIHUB_API_URL/releases/latest" -o -
}
downloadLatestRelease() {
    local token="$1"; shift
    local   dir="$1"; shift

    local relJson="$(getLatestRelease "$token")"
    local  urls=( $(jq --raw-output '.assets[].browser_download_url' <<<"$relJson") )
    local names=( $(jq --raw-output '.assets[].name'                 <<<"$relJson") )

    mkdir "$dir"
    for i in "${!urls[@]}" ; do
        echo
        echo "== $i => ${urls[$i]}  /  ${names[$i]}"
        echo
        curl -L -o "$dir/${names[$i]}" "${urls[$i]}"
    done
}
removeReleaseWithTag() {
    local     tag="$1"; shift
    local   token="$1"; shift

    local relJson="$(getRelease "$token" "$tag")"
    local      id="$(jq --raw-output '.id' <<<"$relJson")"
    if [[ $id == null || $id == "" ]]; then
        echo "ERROR: trying to delete a release that does not exist" 1>&2
        exit 99
    fi
    curl_ "$token" -X DELETE "$GIHUB_API_URL/releases/$id" -o -
}
publishRelease() {
    local  branch="$1"; shift
    local     tag="$1"; shift
    local   token="$1"; shift
    local isDraft="$1"; shift
    local  assets=("$@")

    local comment="release $tag created on $(date +'%Y-%m-%d %H:%M:%S')"
    local   isPre="$(contains pre "$tag")"

    echo "release info:"
    echo "        tag     = $tag"
    echo "        relName = $tag"
    echo "        isDraft = $isDraft"
    echo "        isPre   = $isPre"
    echo "        branch  = $branch"
    echo "        comment = $comment"


    local   relJson="$(getRelease "$token" "$tag")"
    local uploadUrl="$(jq --raw-output '.upload_url' <<<"$relJson")"
    if [[ $uploadUrl != null ]]; then
        echo "ERROR: this release already exists, delete it first" 1>&2
        exit 99
    fi
    echo "    creating new release..."
    json="$(cat <<EOF
{
"tag_name"        : "$tag",
"target_commitish": "$branch",
"name"            : "$tag",
"body"            : "$comment",
"draft"           : $isDraft,
"prerelease"      : $isPre
}
EOF
)"
    local relJson="$(curl_ "$token" -X POST -d "$json" "$GIHUB_API_URL/releases" -o -)"
    local uploadUrl="$(jq --raw-output '.upload_url' <<<"$relJson")"
    if [[ $uploadUrl == null ]]; then
        echo "ERROR: unable to create the release: $relJson" 1>&2
        echo
        exit 99
    fi
    local uploadUrl="$(sed -E 's/\{\?.*//' <<<"$uploadUrl")"
    echo "    using upload url: $uploadUrl"

    for file in "${assets[@]}"; do
        local mimeType="$(file -b --mime-type "$file")"
        local     name="$(basename "$file" | sed "s/SNAPSHOT/$tag/")"
        echo "      attaching: $file as $name ($mimeType)"
        local cnt
        for (( cnt = 1; cnt <= 10; ++cnt )); do
            local  attJson="$(curl_ "$token" --header "Content-Type: $mimeType" -X POST --data-binary @"$file" "$uploadUrl?name=$name" -o -)"
            echo "$attJson" >"$name.upload.json"
            local    state="$(jq --raw-output '.state' <<<"$attJson")"
            if [[ $state == uploaded ]]; then
                echo "        => ok"
                break
            fi
            if (( 10 <= $cnt )); then
                echo "        => ERROR: asset could not be attached"
                echo
                exit 99
            fi
            echo "        => oops, not correctly attached: '$state', trying again... ($cnt)"
            echo "INFO: $attJson"
        done
    done
}
publishReleaseWithJarsOnGitHub() {
    local  branch="$1"; shift
    local version="$1"; shift
    local   token="$1"; shift
    local isDraft="$1"; shift
    local   names=("$@")

    local  assets=()
    for n in "${names[@]}"; do
        assets+=("$(makeJarName        $n)")
        assets+=("$(makeJarNameSources $n)")
        assets+=("$(makeJarNameJavadoc $n)")
    done
    publishReleaseOnGitHub "$branch" "$version" "$token" "$isDraft" "${assets[@]}"
}
publishReleaseOnGitHub() {
    local  branch="$1"; shift
    local version="$1"; shift
    local   token="$1"; shift
    local isDraft="$1"; shift
    local  assets=("$@")

    if [[ $version == "" ]]; then
        echo "ERROR: version is empty" 1>&2
        exit 60
    fi
    if [[ $version != SNAPSHOT && $(git tag -l "$version") ]]; then
        echo "ERROR: tag $version already exists" 1>&2
        exit 70
    fi
    if ! validateToken "$token"; then
        echo "ERROR: not a valid token" 1>&2
        exit 80
    fi
    local hadError=false
    for file in "${assets[@]}"; do
        if [[ ! -f $file ]]; then
            echo "ERROR: file not found: $file" 1>&2
            hadError=true
        fi
    done
    if [[ $hadError == true ]]; then
        exit 95
    fi

    if [[ $version == SNAPSHOT && $(git tag -l "$version") ]]; then
        removeReleaseWithTag "$version" "$token"
    fi
    publishRelease "$branch" "$version" "$token" "$isDraft" "${assets[@]}"
}
###############################################################################