#!/bin/bash
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

set -ue

. ~/secrets.sh

GITHUB_GRAPHQL_URL="https://api.github.com/graphql"
OWNER=ModelingValueGroup
REPOS=buildtools
ARTIF=org.modelingvalue.buildtools
TOKEN=$INPUT_TOKEN

if [ ]; then
q='
  repository(owner: "'$OWNER'", name: "'$REPOS'") {
    packages(names: "'$ARTIF'", first: 1) {
      nodes {
        versions(first: 1) {
          nodes {
            version
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
    | jq .
fi

graphqlQuery() {
  local query="$1"; shift

  curl -s -H "Authorization: bearer $TOKEN" -X POST -d '{"query":"'"$query"'"}' "$GITHUB_GRAPHQL_URL"
}
listPackageVersions() {
  local a="$1"; shift

  local query="$(cat <<EOF | sed 's/"/\\"/g' | tr '\n\r' ' '
query {
    repository(owner:"$OWNER", name:"$REPOS"){
        packages(names:"$a",first:1) {
            nodes {
                versions(first:100) {
                    nodes {
                        version
                    }
                }
            }
        }
    }
}
EOF
)"
  graphqlQuery "$query" | jq -r '.data.repository.packages.nodes[0].versions.nodes[].version' | head -10
}



listPackageVersions $ARTIF
