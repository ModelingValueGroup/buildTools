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
##### tests ###########################################################################################################
test_packing() {
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
    echo "test OK: packing jar does correctly deliver scripts"
}
#######################################################################################################################
test_downloadArtifactQuick() {
    echo "...expect 2 warnings"
    downloadArtifactQuick "$INPUT_TOKEN" "org.modelingvalue" "buildTools" "1.1.1" "jar" "downloaded"
    checksumCompare  "83b11ce6151a9beaa79576117f2f1c9f" "downloaded/buildTools.jar" \
                     "5d2fa9173c3c1ec0164587b4ece4ec36" "downloaded/buildTools.pom"
    rm -rf downloaded
    echo "test OK: downloadArtifactQuick is working correctly"
}
#######################################################################################################################
test_downloadArtifact() {
    downloadArtifact "$INPUT_TOKEN" "org.modelingvalue" "buildTools" "1.1.1" "jar" "downloaded"
    checksumCompare "83b11ce6151a9beaa79576117f2f1c9f" "downloaded/buildTools.jar" \
                     "5d2fa9173c3c1ec0164587b4ece4ec36" ~/".m2/repository/org/modelingvalue/buildTools/1.1.1//buildTools-1.1.1.pom" # not copied to indicated dir so checking in m2-repos
    rm -rf downloaded
    echo "test OK: downloadArtifact is working correctly"
}
#######################################################################################################################
test_correctEols() {
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
test_correctHeaders() {
    printf "xxx" > hdr
    printf "aap\nnoot\n" > testfile.java
    printf "//~~~~~~\n// xxx ~\n//~~~~~~\n\naap\nnoot\n" > testfileref.java
    correctHeaders hdr
    if ! cmp -s testfile.java testfileref.java; then
        echo "::error::correctHeaders failed" 1>&2
        exit 67
    fi
    rm hdr testfile.java testfileref.java
    echo "test OK: correctHeaders is working correctly"
}
#######################################################################################################################
test_generateAll() {
    mkdir -p .idea TST/tst SRC/src BTH/src BTH/tst
    cat <<EOF >project.sh
artifacts=(
    "test.modelingvalue  zomaar                  9.9.9       jar j--"
)
dependencies=(
    "junit               junit                   4.12        jar jdst"
    "org.hamcrest        hamcrest-core           1.3         jar jds-"
)
EOF
    cat <<'EOF' >.idea/modules.xml
<?xml version="1.0" encoding="UTF-8"?>
<project version="4">
  <component name="ProjectModuleManager">
    <modules>
      <module fileurl="file://$PROJECT_DIR$/correctors/correctors.iml" filepath="$PROJECT_DIR$/TST/modTst.iml" />
      <module fileurl="file://$PROJECT_DIR$/shellTools/shellTools.iml" filepath="$PROJECT_DIR$/SRC/modSrc.iml" />
      <module fileurl="file://$PROJECT_DIR$/shellTools/shellTools.iml" filepath="$PROJECT_DIR$/BTH/modBth.iml" />
    </modules>
  </component>
</project>
EOF
    cat <<EOF >build.xml
<project>
    <target>
        <echo>%s</echo>
    </target>
</project>
EOF
    sed 's/%s/.module.test.sourcepath/'                    build.xml > TST/module_modtst.xml
    sed 's/%s/.module.sourcepath/'                         build.xml > SRC/module_modsrc.xml
    sed 's/%s/.module.sourcepath .module.test.sourcepath/' build.xml > BTH/module_modbth.xml

    generateAll
    generateAll
    generateAll

    checksumCompare "28530fe5cdb447b6f28cdd903331c629" "pom.xml" \
                    "aeb55c0a88fa399f0604ba45b102260e" ".idea/libraries/gen__hamcrest_core.xml" \
                    "9da13dd7b8b691d1c6781f39f36d5be8" ".idea/libraries/gen__junit.xml" \
                    "e5b40e41880c8864b8c1ff7041b1fd54" "build.xml" \
                    "67e61acc023c26ebac90ba8e699fb9bb" "TST/module_modtst.xml" \
                    "606cba3391fe62749758d115233d493d" "SRC/module_modsrc.xml" \
                    "39c3d17d49b6d64c66b2e26b411254bb" "BTH/module_modbth.xml"

    echo "test OK: generateAll is working correctly"
}
test_uploadArtifactQuick() {
    runUploadArtifactTest "tst.modelingvalue" "buildTools" "$INPUT_TOKEN"
    echo "test OK: uploadArtifactQuick is working correctly"
}
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
    fi
}
#######################################################################################################################
##### test execution:
if [[ "$#" == 0 ]]; then
    tests=( $(declare -F | sed 's/declare -f //' | egrep '^test_' | sort) )
else
    tests=("$@")
fi
prepareForTesting
rm -rf tmp
for f in "${tests[@]}"; do
    echo
    echo
    echo "::group::$f"
    printf "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ %s @@@@@@@@@@@@@@@@@@@@@@@@@@@@\n" "$f"

    rm -rf ~/.m2/repository/org/modelingvalue       # delete our stuff from the .m2 dir

    ##### make tmp dir:
    tmp="tmp/$f"
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

        "$f"
    )
    echo "::endgroup::"
done
printf "\n\nall tests OK\n\n"
