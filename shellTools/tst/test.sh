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
        java -jar ~/buildTools.jar
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
}
test_downloadArtifactQuick() {
    downloadArtifactQuick "$INPUT_TOKEN" "org.modelingvalue" "buildTools"    "1.1.1" "jar" "from-github" 2>log
    downloadArtifactQuick "$INPUT_TOKEN" "junit"             "junit"         "4.12"  "jar" "from-maven"
    downloadArtifactQuick "$INPUT_TOKEN" "junit"             "junit"         "4.10"  "jar" "from-sonatype"

    assertChecksumsMatch    "83b11ce6151a9beaa79576117f2f1c9f" "from-github/buildTools.jar" \
                            "5d2fa9173c3c1ec0164587b4ece4ec36" "from-github/buildTools.pom" \
                            \
                            "5b38c40c97fbd0adee29f91e60405584" "from-maven/junit.jar" \
                            "af7ca61fba26556cfe5b40cf15aadc14" "from-maven/junit.pom" \
                            "cf72f68b360b44c15fadd47a0bbc1b43" "from-maven/junit-javadoc.jar" \
                            "97f2fb8b3005d11d5a754adb4d99c926" "from-maven/junit-sources.jar" \
                            \
                            "68380001b88006ebe49be50cef5bb23a" "from-sonatype/junit.jar" \
                            "7cb390d6759b75fc0c2bedfdeb45877d" "from-sonatype/junit.pom" \
                            "ecac656aaa7ef5e9d885c4fad5168133" "from-sonatype/junit-javadoc.jar" \
                            "8f17d4271b86478a2731deebdab8c846" "from-sonatype/junit-sources.jar"

    assertFileContains log 2 "::warning::could not download artifact"
}
test_downloadArtifact() {
    (downloadArtifact "$INPUT_TOKEN" "org.modelingvalue" "buildTools" "1.1.1" "jar" "downloaded") >log 2>&1
    assertChecksumsMatch    "83b11ce6151a9beaa79576117f2f1c9f" "downloaded/buildTools.jar" \
                            "5d2fa9173c3c1ec0164587b4ece4ec36" ~/".m2/repository/org/modelingvalue/buildTools/1.1.1//buildTools-1.1.1.pom" # pom not copied to indicated dir so checking in m2-repos
    rm -rf downloaded
}
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
}
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
}
test_generateAll() {
    mkdir -p .idea TST/tst SRC/src BTH/src BTH/tst
    cat <<EOF >project.sh
artifacts=(
    "test.modelingvalue  zomaar                  9.9.9       jar j--"
)
dependencies=(
    "junit               junit                   4.12        jar jdst"
    "jars@multi"
    "org.hamcrest        hamcrest-core           1.3         jar jds-"
)
repositories=(
    "https://projects.itemis.de/nexus/content/repositories/mbeddr"
)
multi=(
    "MPS/lib/mps-editor.jar"
    "MPS/lib/annotations.jar"
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

    generateMavenSettings "uuu" "ppp" "someurl" > settings.xml

    assertChecksumsMatch    "28530fe5cdb447b6f28cdd903331c629" "pom.xml" \
                            "aeb55c0a88fa399f0604ba45b102260e" ".idea/libraries/gen__hamcrest_core.xml" \
                            "9da13dd7b8b691d1c6781f39f36d5be8" ".idea/libraries/gen__junit.xml" \
                            "c2f5edf722b02968392812dcfe1a10bc" ".idea/libraries/gen__multi.xml" \
                            "e5b40e41880c8864b8c1ff7041b1fd54" "build.xml" \
                            "208a3ecf8fc0ade893227f0387958b49" "TST/module_modtst.xml" \
                            "606cba3391fe62749758d115233d493d" "SRC/module_modsrc.xml" \
                            "2084d453d9c1abed6b11623d5f2d2145" "BTH/module_modbth.xml" \
                            "851e45a3b74f2265bcfc65a36889277d" "settings.xml"
}
test_uploadArtifactQuick() {
    runUploadArtifactTest "tst.modelingvalue" "buildTools" "$INPUT_TOKEN"
}
test_getAllDependencies() {
    cat <<EOF >project.sh
dependencies=(
    "org.modelingvalue   immutable-collections   0.0.0       jar jds-"  # will never exist
    "org.modelingvalue   dclare                  0.0.13      jar jds-"  # does exist
    "junit               junit                   4.12        jar jdst"
    "org.hamcrest        hamcrest-core           1.3         jar jds-"
)
EOF
    if (set -x; getAllDependencies "${INPUT_TOKEN:-}" "${INPUT_SCALEWAY_ACCESS_KEY:-}" "${INPUT_SCALEWAY_SECRET_KEY:-}" ) >log.out 2>log.err; then
        echo "::error::expected a fail but encountered success" 1>&2
    else
        assertFileContains log.err 4 "^::warning::could not download artifact: " 1>&2
        assertFileContains log.err 1 "^::error::missing dependency org.modelingvalue:immutable-collections.jar" 1>&2
    fi
}
#######################################################################################################################
#######################################################################################################################
prepareForTesting() {
    if [[ "${GITHUB_WORKSPACE:-}" == "" ]]; then
        export  GITHUB_WORKSPACE="$PWD"
        export GITHUB_REPOSITORY="ModelingValueGroup/buildTools"
        export        GITHUB_REF="refs/heads/local-build-fake-branch"

        ##### mimic github actions env for local execution:
        . ~/secrets.sh # defines INPUT_TOKEN without exposing it in the github repos
        if [[ "${INPUT_TOKEN:-}" == "" || "${INPUT_SCALEWAY_ACCESS_KEY:-}" == ""  || "${INPUT_SCALEWAY_SECRET_KEY:-}" == "" ]]; then
            echo ":error:: local test runs require a file ~/sercrets.sh that defines INPUT_TOKEN INPUT_SCALEWAY_ACCESS_KEY and INPUT_SCALEWAY_SECRET_KEY"
            exit 23
        fi

        if [[ "$(command -v md5)" != "" && "$(command -v md5sum)" == "" ]]; then
            md5sum() { md5; }
        fi
    fi
}
#######################################################################################################################
##### test execution:
cp out/artifacts/buildTools.jar ~
. <(java -jar ~/buildTools.jar)
if [[ "$#" == 0 ]]; then
    tests=( $(declare -F | sed 's/declare -f //' | egrep '^test_' | sort) )
else
    tests=("$@")
fi
prepareForTesting
rm -rf tmp
for t in "${tests[@]}"; do
    echo 1>&2
    echo "::group::$t" 1>&2
    printf "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ %s @@@@@@@@@@@@@@@@@@@@@@@@@@@@\n" "$t" 1>&2

    rm -rf ~/.m2/repository/org/modelingvalue       # delete our stuff from the .m2 dir

    ##### make tmp dir:
    tmp="tmp/$t"
    rm -rf "$tmp"
    mkdir -p "$tmp"
    (
        cd "$tmp"

        ##### include the produced jar again:
        . <(java -jar ~/buildTools.jar)
        "$t"
    )
    echo "::endgroup::" 1>&2
done
printf "\nall tests OK\n\n"
