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

registerForJitInstall s3cmd

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
    printf "--config=%s" "$configFile"
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
        echo "::info::bucket not found, creating bucket: $buc"
        s3cmd "$confArg" mb "$buc"
    fi
    s3cmd "$confArg" --recursive put "$from" "$to"
}
