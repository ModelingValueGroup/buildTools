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
installLinuxPackages() {
    local toInstall c n problems

    toInstall=()
    # shellcheck disable=SC2154
    for i in "${extraLinuxPackages[@]}"; do
        IFS=: read n c <<<"$i"
        c="${c:-$n}"
        if ! which $c 1>/dev/null; then
            toInstall+=("$n")
        fi
    done
    if [[ "${#toInstall[@]}" != 0 ]]; then
        echo "::group::install extra packages" 1>&2
        echo "## installing: ${toInstall[*]}"
        if ! command -v apt-get; then
            echo "::warning::no apt-get command so I have no way to install the required linux tools: ${toInstall[*]}" 1>&2
            exit 92
        fi

        #### WORAROUND_START
        # the following line is a workaround for a broken mirror...
        # see: https://github.community/t5/GitHub-Actions/File-has-unexpected-size-89974-89668-Mirror-sync-in-progress/m-p/44270
        for apt_file in $(grep -lr microsoft /etc/apt/sources.list.d/); do
            sudo rm "$apt_file"
        done
        #### WORAROUND_END

        sudo apt-get update
        sudo apt-get install -y "${toInstall[@]}"
        problems=false
        for i in "${extraLinuxPackages[@]}"; do
            IFS=: read n c <<<"$i"
            c="${c:-$n}"
            if ! which $c 1>/dev/null; then
                echo "::error::linux tool $c could not be installed (package $n)" 1>&2
                problems=true
            fi
        done
        if [[ "$problems" == true ]]; then
            exit 95
        fi
        echo "::endgroup::" 1>&2
    fi
}
