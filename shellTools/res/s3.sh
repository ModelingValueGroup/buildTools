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

installS3cmd() {
    export   S3CMD_HOST_URL="$1"; shift
    export S3CMD_ACCESS_KEY="$1"; shift
    export S3CMD_SECRET_KEY="$1"; shift
}
s3cmd_() {
    s3cmd                                   \
               --host="$S3CMD_HOST_URL"     \
         --access_key="$S3CMD_ACCESS_KEY"   \
         --secret_key="$S3CMD_SECRET_KEY"   \
        --host-bucket=                      \
        "$@"
}
get() {
    local  buc="$1"; shift
    local from="$1"; shift
    local   to="$1"; shift

    echo "# going to get from '$S3CMD_HOST_URL' from '$from' to '$to'"
    mkdir -p "$to"
    s3cmd_ --recursive get "$from" "$to"
}
put() {
    local  buc="$1"; shift
    local from="$1"; shift
    local   to="$1"; shift

    echo "# going to put on '$S3CMD_HOST_URL' from '$from' to '$to'"
    if ! s3cmd_ ls "$buc" 2>/dev/null 1>&2; then
        echo "# bucket not found, creating bucket: $buc"
        s3cmd_ mb "$buc"
    fi
    s3cmd_ --recursive put "$from" "$to"
}
