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

extraLinuxPackages+=(s3cmd)

export PROJECT_SH="project.sh"
export TRIGGERS_DIR="triggers"

prepS3cmd() {
    local   host="$1"; shift
    local access="$1"; shift
    local secret="$1"; shift

    cat <<EOF > ~/.s3cfg
[default]
access_key       = $access
secret_key       = $secret
host_base        = $host
host_bucket      =
enable_multipart = True
use_https        = True
EOF
}
s3get() {
    local  buc="$1"; shift
    local from="$1"; shift
    local   to="$1"; shift

    mkdir -p "$to"
    s3cmd --recursive get "$from" "$to"
}
s3put() {
    local  buc="$1"; shift
    local from="$1"; shift
    local   to="$1"; shift

    if ! s3cmd ls "$buc" 2>/dev/null 1>&2; then
        echo "# bucket not found, creating bucket: $buc"
        s3cmd mb "$buc"
    fi
    s3cmd --recursive put "$from" "$to"
}
trigger() {
    local trigger="$1"; shift
    local      to="$1"; shift

    if [[ "$(s3cmd ls "$to$TRIGGERS_DIR/" | wc -l)" != 0 ]]; then
        local triggersTmpDir="$TRIGGERS_DIR-$$/"
        mkdir -p "$triggersTmpDir"
        s3cmd --recursive get "$to$TRIGGERS_DIR/" "$triggersTmpDir"
        local f
        for f in "$triggersTmpDir"/*.trigger; do
            if [[ -f "$f" ]]; then
                local TRIGGER_REPOSITORY TRIGGER_BRANCH
                . "$f"
                triggerOther "$trigger" "$TRIGGER_REPOSITORY" "$TRIGGER_BRANCH"
            fi
        done
        rm -rf "$triggersTmpDir"
    fi
}
triggerOther() {
    local trigger="$1"; shift
    local    repo="$1"; shift
    local  branch="$1"; shift

    local i total_count conclusion rerunUrl
    local tmpJson="runs.json"

    firstFieldFromJson() {
        local field="$1"; shift

        grep -E "^ *\"$field\": " "$tmpJson" | head -1 | sed 's/^[^:]*: *//;s/,$//;s/"//g'
    }

    echo "====== triggering: $repo  [$branch]"
    for i in $(seq 0 600); do
        curl -s \
            -u "automation:$trigger"  \
            "https://api.github.com/repos/$repo/actions/runs?branch=$branch" \
            -o "$tmpJson"
        total_count="$(firstFieldFromJson "total_count")"
        if [[ "$total_count" == 0 ]]; then
            break
        fi
        conclusion="$(firstFieldFromJson "conclusion")"
        if [[ "$conclusion" != "null" ]]; then
            break
        fi
        echo "::info:: waiting for build on $repo branch $branch to finish ($i)"
        sleep 2
    done
    if [[ "$total_count" == 0 ]]; then
        echo "::warning:: no build on $repo branch $branch, retrigger impossible..."
    elif [[ "$conclusion" == "null" ]]; then
        echo "::warning::the build on $repo branch $branch did not finish in time"
    else
        conclusion="$(firstFieldFromJson "conclusion")"
        echo "::info:: conclusion: $conclusion"
        if [[ "$conclusion" != failure ]]; then
            echo "::warning::the latest build on $repo branch $branch did not finish with failure (but $conclusion), retrigger impossible..."
        else
            rerunUrl="$(firstFieldFromJson "rerun_url")"
            echo "::info::triggering: $rerunUrl"
            curl -s \
                -XPOST \
                -u "automation:$trigger"  \
                "$rerunUrl"
        fi
    fi
}
