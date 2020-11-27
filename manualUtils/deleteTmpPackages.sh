#!/bin/bash
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

. ~/secrets.sh

GITHUB_GRAPHQL_URL="https://api.github.com/graphql"
OWNER=ModelingValueGroup
REPOS=tmp

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
            --header "Authorization: token $GITHUB_TOKEN" \
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
                    --header "Authorization: token $GITHUB_TOKEN" \
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
