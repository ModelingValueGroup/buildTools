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

#######################################################################################################################
prepareForTesting() {
    if [[ "${GITHUB_WORKSPACE:-}" == "" ]]; then
        export GITHUB_WORKSPACE="$PWD"
        export GITHUB_REPOSITORY="ModelingValueGroup/buildTools"

        ##### mimic github actions env for local execution:
        . ~/secrets.sh # defines INPUT_TOKEN without exposing it in the github repos
        if [[ "${INPUT_TOKEN:-}" == "" ]]; then
            echo ":error:: local test runs require a file ~/sercrets.sh that defines at least INPUT_TOKEN"
            exit 67
        fi

        if [[ "$(command -v md5)" != "" && "$(command -v md5sum)" == "" ]]; then
            md5sum() { md5; }
        fi
        xmlstarlet() {
            :
        }
    fi
}

#######################################################################################################################
##### tests ###########################################################################################################
test_00() {
    textFromJar() {
        java -jar buildTools.jar
    }
    textFromDir() {
        echo "#!/usr/bin/env bash"
        for sh in ../../shellTools/res/*.sh; do
            echo "###@@@ $(basename "$sh")"
            sed '/^#!\/usr\/bin\/env bash$/d' "$sh"
        done
    }

    if [[ "$(textFromJar)" != "$(textFromDir)" ]]; then
        echo "::error::test failed: jar does not correctly deliver scripts" 1>&2
        diff <(printf "%s" "$(textFromJar)") <(printf "%s" "$(textFromDir)")
        exit 46
    fi
    echo "test OK: jar does correctly deliver scripts"
}
#######################################################################################################################
test_01() {
    echo "...expect 2 warnings"
    downloadArtifactQuick "$INPUT_TOKEN" "org.modelingvalue" "buildTools" "1.1.1" "jar" "downloaded"
    mustBeSameChecksum "83b11ce6151a9beaa79576117f2f1c9f" "downloaded/buildTools.jar"
    mustBeSameChecksum "5d2fa9173c3c1ec0164587b4ece4ec36" "downloaded/buildTools.pom"
    rm -rf downloaded
    echo "test OK: downloadArtifactQuick is working correctly"
}
#######################################################################################################################
test_02() {
    downloadArtifact "$INPUT_TOKEN" "org.modelingvalue" "buildTools" "1.1.1" "jar" "downloaded"
    mustBeSameChecksum "83b11ce6151a9beaa79576117f2f1c9f" "downloaded/buildTools.jar"
    mustBeSameChecksum "5d2fa9173c3c1ec0164587b4ece4ec36" ~/".m2/repository/org/modelingvalue/buildTools/1.1.1//buildTools-1.1.1.pom" # not copied to indicated dir
    rm -rf downloaded
    echo "test OK: downloadArtifact is working correctly"
}
#######################################################################################################################
test_03() {
    printf "aap\r\nnoot\r\n" > testfile_crlf.txt
    printf "aap\nnoot\n"     > testfile_lf.txt
    if cmp -s testfile_crlf.txt testfile_lf.txt; then
        echo "::error::correctEols precheck failed" 1>&2
        exit 67
    fi
    correctEols
    if ! cmp -s testfile_crlf.txt testfile_lf.txt; then
        echo "::error::correctEols failed" 1>&2
        exit 67
    fi
    rm testfile_crlf.txt testfile_lf.txt
    echo "test OK: correctEols is working correctly"
}
#######################################################################################################################
test_04() {
    printf "xxx" > hdr
    printf "aap\nnoot\n" > testfile.java
    printf "//~~~~~~\n// xxx ~\n//~~~~~~\n\naap\nnoot\n" > testfileref.java
    correctHeaders hdr
    if ! cmp -s testfile.java testfileref.java; then
        echo "::error::correctHeaders failed" 1>&2
        exit 67
    fi
    rm hdr testfile.java testfileref.java
    echo "test OK: correctEols is working correctly"
}
#######################################################################################################################
test_05() {
    mkdir -p .idea
    cat <<EOF >project.sh
artifacts=(
    "test.modelingvalue  qqq                     9.9.9       jar j--"
)
dependencies=(
    "junit               junit                   4.12        jar jds"
    "org.hamcrest        hamcrest-core           1.3         jar jds"
)
EOF
    cp ../../.idea/modules.xml .idea/modules.xml
    cp ../../build.xml         build.xml
    generateAll
    mustBeSameChecksum "f9b0eed046613097151f3a749bc133bb" "pom.xml"
    mustBeSameChecksum "50f4e5517c5891fb37d7fd93f18e1e72" ".idea/libraries/Maven__junit_junit.xml"
    mustBeSameChecksum "ba2140517389305e2276df33aad7db7c" ".idea/libraries/Maven__org_hamcrest_hamcrest_core.xml"
}
test_06() {
    runUploadArtifactTest "tst.modelingvalue" "buildTools" "$INPUT_TOKEN"
    echo "test OK: uploadArtifactQuick is working correctly"
}
#######################################################################################################################
##### test execution:
if [[ "$#" == 0 ]]; then
    tests=( $(declare -F | sed 's/declare -f //' | egrep '^test_' | sort) )
else
    tests=("$@")
fi
prepareForTesting
for i in "${tests[@]}"; do
    printf "\n\n@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ %s @@@@@@@@@@@@@@@@@@@@@@@@@@@@\n" "$i"

    rm -rf ~/.m2/repository/org/modelingvalue       # delete our stuff from the .m2 dir

    ##### make tmp dir:
    tmp="tmp/$i"
    rm -rf "$tmp"
    mkdir -p "$tmp"
    (
        cd "$tmp"

        ##### copy the produced jar over to here:
        if [[ -f ../../buildTools.jar               ]]; then
            cp ../../buildTools.jar               buildTools.jar
        elif [[ -f ../../out/artifacts/buildTools.jar ]]; then
            cp ../../out/artifacts/buildTools.jar buildTools.jar
        fi
        . <(java -jar buildTools.jar)

        "$i"
    )
done
printf "\n\nall tests OK\n\n"
