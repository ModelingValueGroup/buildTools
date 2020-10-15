#!/bin/bash

. ~/secrets.sh

GITHUB_GRAPHQL_URL="https://api.github.com/graphql"
OWNER=ModelingValueGroup
REPOS=tmp
TOKEN=$INPUT_TOKEN2

for ARTIF in \
    tmp.modelingvalue.buildtools \
    tmp.modelingvalue.upload-maven-package-action-test \
    ; do
    q='
      repository(owner: "'$OWNER'", name: "'$REPOS'") {
        packages(names: "'$ARTIF'", first: 1) {
          nodes {
            name
            versions(last: 100) {
              nodes {
                version
                id
              }
            }
          }
        }
      }
    '
    curl -X POST \
            --location \
            --remote-header-name \
            --fail \
            --silent \
            --show-error \
            --header "Authorization: token $TOKEN" \
            -d '{"query":"query { '"$(sed 's/"/\\"/g' <<<"$q" | tr -d '\n')"' } "}' \
            "$GITHUB_GRAPHQL_URL" \
            -o - \
        | jq . \
        | sed -En 's/^ *"(version|id)": //p'  \
        | tr -d '",' \
        | paste -d " " - - \
        | while read v id; do
            echo "==== $ARTIF ==== $v ==== $id ===="
            curl -X POST \
                    --location \
                    --remote-header-name \
                    --fail \
                    --silent \
                    --show-error \
                    --header "Accept: application/vnd.github.package-deletes-preview+json" \
                    --header "Authorization: token $TOKEN" \
                    -d '{"query":"mutation { deletePackageVersion(input:{packageVersionId:\"'"$id"'\"}) { success }}"}' \
                    "$GITHUB_GRAPHQL_URL" \
                    -o - \
                | jq . >/tmp/$$-del
            if fgrep -q 'errors' /tmp/$$-del; then
                fgrep 'message' /tmp/$$-del
            else
                cat /tmp/$$-del
            fi
            rm -f /tmp/$$-del
        done
done
