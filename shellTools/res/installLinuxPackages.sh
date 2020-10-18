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

set -euo pipefail

##########################################################################################################################
inOptionalLinuxPackage() {
    local command="$1"; shift
    local package="${1:-$command}"

    if ! which $command >/dev/null; then
        . <(cat <<EOF
$command() {
    installbefore $command $package
    unset $command
    $command "\$@"
}
EOF
        )
    fi
}
installbefore() {
    local command="$1"; shift
    local package="$1"; shift

    if [[ "$(type -at $command | fgrep file)" == "" ]]; then
        (
            echo "::group::install $command from $package"
            if ! type apt-get >/dev/null 2>&1; then
                echo "::error::no apt-get command so I have no way to install $command from $package"
                exit 92
            fi
            if [[ "$(type -t $command)" != function ]]; then
                echo "::error::inconsistent use of installBefore(): called while $command already available"
                exit 91
            fi

            #### WORAROUND_START ####################################################################################################
            # the following line is a workaround for a broken mirror...
            # see: https://github.community/t5/GitHub-Actions/File-has-unexpected-size-89974-89668-Mirror-sync-in-progress/m-p/44270
            for apt_file in $(grep -lr microsoft /etc/apt/sources.list.d/ 2>/dev/null || :); do
                rm "$apt_file"
            done
            #### WORAROUND_END ######################################################################################################

            apt-get update
            apt-get install -y "$package"
            if ! type "$command" >/dev/null 2>&1; then
                echo "::error::could not install $command from $package"
                exit 93
            fi
            echo "::endgroup::"
        ) 1>&2
    fi
}
