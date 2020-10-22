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

inOptionalLinuxPackage s3cmd

export PROJECT_SH="project.sh"
export TRIGGERS_DIR="triggers"

#
# prepare for using S3 with the given parameters
# echos the config flag to use on the commands below
#
prepS3cmd() {
    local   host="$1"; shift
    local access="$1"; shift
    local secret="$1"; shift

    local configFile=~/".s3cfg-$$"
    cat <<EOF > "$configFile"
[default]
access_key       = $access
secret_key       = $secret
host_base        = $host
host_bucket      =
enable_multipart = True
use_https        = True
EOF
    find ~ -maxdepth 1 -type f -name '.s3cfg-*' -mtime +1 -delete # delete configs older then 1 hour
    echo "--config=$configFile"
}
#
# get a file or folder from S3
#
s3get() {
    local confArg="$1"; shift
    local     buc="$1"; shift
    local    from="$1"; shift
    local      to="$1"; shift

    mkdir -p "$to"
    s3cmd "$confArg" --recursive get "$from" "$to"
}
#
# put a file or folder to S3
#
s3put() {
    local confArg="$1"; shift
    local     buc="$1"; shift
    local    from="$1"; shift
    local      to="$1"; shift

    if ! s3cmd "$confArg" ls "$buc" 2>/dev/null 1>&2; then
        echo "# bucket not found, creating bucket: $buc"
        s3cmd "$confArg" mb "$buc"
    fi
    s3cmd "$confArg" --recursive put "$from" "$to"
}
s3trigger() {
    local confArg="$1"; shift
    local   token="$1"; shift
    local      to="$1"; shift

    if [[ "$(s3cmd "$confArg" ls "$to$TRIGGERS_DIR/" | wc -l)" != 0 ]]; then
        local triggersTmpDir="$TRIGGERS_DIR-$$/"
        mkdir -p "$triggersTmpDir"
        s3cmd "$confArg" --recursive get "$to$TRIGGERS_DIR/" "$triggersTmpDir"
        local f
        for f in "$triggersTmpDir"/*.trigger; do
            if [[ -f "$f" ]]; then
                local TRIGGER_REPOSITORY TRIGGER_BRANCH
                . "$f"
                triggerOther "$token" "$TRIGGER_REPOSITORY" "$TRIGGER_BRANCH"
            fi
        done
        rm -rf "$triggersTmpDir"
    fi
}
triggerOther() {
    local   token="$1"; shift
    local    repo="$1"; shift
    local  branch="$1"; shift

    local i totalCount conclusion message rerunUrl
    local tmpJson="runs.json"

    firstFieldFromJsonLog() {
        local field="$1"; shift

        (grep -E "^ *\"$field\": " "$tmpJson" | head -1 | sed 's/^[^:]*: *//;s/,$//;s/"//g') || :
    }

    echo "====== triggering: $repo  [$branch]"
    for i in $(seq 0 600); do
        curl -s \
            -u "automation:$token"  \
            "https://api.github.com/repos/$repo/actions/runs?branch=$branch" \
            -o "$tmpJson"

        totalCount="$(firstFieldFromJsonLog "totalCount")"
        conclusion="$(firstFieldFromJsonLog "conclusion")"
           message="$(firstFieldFromJsonLog "message")"
          rerunUrl="$(firstFieldFromJsonLog "rerun_url")"

        echo "::info::totalCount=$totalCount"
        echo "::info::conclusion=$conclusion"
        echo "::info::   message=$message"
        echo "::info:: rerun_url=$rerunUrl"

        if [[ "$totalCount" == 0 || "$conclusion" != "null" ]]; then
            break
        fi
        echo "::info::waiting for build on $repo branch $branch to finish ($i...)"
        sleep 2
    done
    if [[ "$totalCount" == 0 ]]; then
        echo "::warning:: no build on $repo branch $branch, retrigger impossible..."
    elif [[ "$conclusion" == "null" ]]; then
        echo "::warning::I have waited a long time but the build on $repo branch $branch did not finish yet, giving up..."
    elif [[ "$conclusion" != "failure" ]]; then
        echo "::warning::the latest build on $repo branch $branch did not finish with failure (but $conclusion), retrigger impossible, sorry..."
    else
        echo "::info::triggering: $rerunUrl"
        curl -s \
            -XPOST \
            -u "automation:$token"  \
            "$rerunUrl" \
            -o "$tmpJson"

        message="$(firstFieldFromJsonLog "message")"
        if [[ "$message" == "Unable to re-run this workflow run because it was created over a month ago" ]]; then
            echo "::warning::the latest build on $repo branch $branch is too old, retrigger impossible, sorry..."
        else
            echo "::info::triggering yielded: $message"
        fi
    fi
}
