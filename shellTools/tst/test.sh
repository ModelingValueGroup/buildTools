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
test_version() {
    local e="$(sed -n 's/"//g;s/^version=//p' ../../project.sh)"
    local v="$(java -jar ~/buildtools.jar -version)"
    if [[ "$v" != "$e" ]]; then
        echo "::error::test failed: expected version $e but found version $v"
        touch "$errorDetectedMarker"
        exit 46
    fi
    echo "ok: correct version found: $e"
}
test_memecheck() {
    java -jar ~/buildtools.jar -meme > buildtoolsMeme.sh
    local o="$(java -jar ~/buildtools.jar -check 2>&1)"
    local e=""
    if [[ "$o" != "$e" ]]; then
        echo "::error::test failed: the meme-identical check did not succeed: got $o instead of $e"
        touch "$errorDetectedMarker"
        exit 46
    fi

    sed 's/shift/_____/' buildtoolsMeme.sh > meme2
    local o="$(java -jar ~/buildtools.jar -check=meme2 2>&1 | wc -l | tr -d ' ')"
    local e="17"
    if (( $o != $e )); then
        echo "::error::test failed: the diff-meme check did not succeed: got $o instead of $e"
        touch "$errorDetectedMarker"
        exit 46
    fi
    echo "ok: meme check ok"
}
test_meme() {
    java -jar ~/buildtools.jar -meme > buildtoolsMeme.sh
    rm ~/buildtools.jar
    if ! env -i "$(which bash)" -c "
        set -ue
        export     PATH='$PATH'
        export ANT_HOME='$ANT_HOME'
        . buildtoolsMeme.sh '$INPUT_TOKEN' '' 2>/dev/null
        [[ -f ~/buildtools.jar ]]
        declare -f lastPackageVersion >/dev/null
    "; then
        echo "::error::test failed: the meme failed"
        touch "$errorDetectedMarker"
        exit 46
    else
        echo "ok: meme works ok"
    fi
}
test_extraInstall() {
    (
        inOptionalLinuxPackage test_command
        sudo() {
            "$@"
        }

        export PATH="$PWD:$PATH"
        cat <<"EOF1" > "apt-get"
if [[ "$1 $2 $3" == "install -y test_command" ]]; then
    cat <<"EOF2" > "test_command"
printf "##%s" "$@"
printf "##\n"
EOF2
    chmod +x "test_command"
    echo "more logging to stdout"
    echo "end more to stderr" 1>&2
fi
EOF1
        chmod +x "apt-get"

        local o="$(test_command a b c 2>err || echo FAILED)"
        local e="##a##b##c##"
        if [[ "$o" != "$e" ]]; then
            echo "::error::test A1 failed: simulated extra install command returned '$o' but expected '$e' (on stdout)"
            touch "$errorDetectedMarker"
            exit 23
        fi

        local o="$(cat err)"
        local e="::group::install test_command from test_command
more logging to stdout
end more to stderr
::endgroup::"
        if [[ "$o" != "$e" ]]; then
            echo "::error::test A2 failed: simulated extra install command returned '$o' but expected '$e'"
            touch "$errorDetectedMarker"
            exit 23
        fi

        local o="$(test_command q w e 2>err || echo FAILED)"
        local e="##q##w##e##"
        if [[ "$o" != "$e" ]]; then
            echo "::error::test B1 failed: simulated extra install command returned '$o' but expected '$e' (on stdout)"
            touch "$errorDetectedMarker"
            exit 23
        fi

        local o="$(cat err)"
        local e=""
        if [[ "$o" != "$e" ]]; then
            echo "::error::test B2 failed: simulated extra install command returned '$o' but expected '$e' (on stderr)"
            touch "$errorDetectedMarker"
            exit 23
        fi
    )
    if [[ "$(uname -s)" != "Darwin" ]]; then
        # this does not work on mac: no apt-get available
        inOptionalLinuxPackage jq

        local o="$(jq . <<<'{"a":1,"b":2}' 2>err || echo FAILED)"
        local e='{
  "a": 1,
  "b": 2
}'
        if [[ "$o" != "$e" ]]; then
            echo "::error::test C1 failed: simulated extra install command returned '$o' but expected '$e' (on stdout)"
            touch "$errorDetectedMarker"
            exit 23
        fi

        local o="$(cat err)"
        local e=""
        if [[ "$o" != "$e" ]]; then
            echo "::error::test C2 failed: simulated extra install command returned '$o' but expected '$e' (on stderr)"
            touch "$errorDetectedMarker"
            exit 23
        fi

        local o="$(jq . <<<'{"a":222,"b":111}' 2>err || echo FAILED)"
        local e='{
  "a": 222,
  "b": 111
}'
        if [[ "$o" != "$e" ]]; then
            echo "::error::test C1 failed: simulated extra install command returned '$o' but expected '$e' (on stdout)"
            touch "$errorDetectedMarker"
            exit 23
        fi

        local o="$(cat err)"
        local e=""
        if [[ "$o" != "$e" ]]; then
            echo "::error::test C2 failed: simulated extra install command returned '$o' but expected '$e' (on stderr)"
            touch "$errorDetectedMarker"
            exit 23
        fi
    fi
}
test_packing() {
    textFromJar() {
        java -jar ~/buildtools.jar
    }
    textFromDir() {
        echo "#!/usr/bin/env bash"
        for sh in ../../shellTools/res/*.sh; do
            if [[ $(basename "$sh") != buildtoolsMeme.sh ]]; then
                echo "###@@@ $(basename "$sh")"
                sed '/^#!\/usr\/bin\/env bash$/d' "$sh"
            fi
        done
    }

    if [[ "$(textFromJar)" != "$(textFromDir)" ]]; then
        echo "::error::test failed: jar does not correctly deliver scripts" 1>&2
        diff <(printf "%s" "$(textFromJar)") <(printf "%s" "$(textFromDir)")
        # shellcheck disable=SC2154
        touch "$errorDetectedMarker"
        exit 46
    fi
}
test_downloadArtifactQuick() {
    downloadArtifactQuick "$INPUT_TOKEN" "org.modelingvalue" "build""Tools"  "1.1.1" "jar" "from-github1" 2> log1
    downloadArtifactQuick "$INPUT_TOKEN" "org.modelingvalue" "buildtools"    "1.1.1" "jar" "from-github2" 2> log2
    downloadArtifactQuick "$INPUT_TOKEN" "junit"             "junit"         "4.12"  "jar" "from-maven"
    downloadArtifactQuick "$INPUT_TOKEN" "junit"             "junit"         "4.10"  "jar" "from-sonatype"

    assertChecksumsMatch    "83b11ce6151a9beaa79576117f2f1c9f:from-github1/build""Tools.jar" \
                            "5d2fa9173c3c1ec0164587b4ece4ec36:from-github1/build""Tools.pom" \
                            "83b11ce6151a9beaa79576117f2f1c9f:from-github2/buildtools.jar" \
                            "5d2fa9173c3c1ec0164587b4ece4ec36:from-github2/buildtools.pom" \
                            \
                            "5b38c40c97fbd0adee29f91e60405584:from-maven/junit.jar" \
                            "af7ca61fba26556cfe5b40cf15aadc14:from-maven/junit.pom" \
                            "cf72f68b360b44c15fadd47a0bbc1b43:from-maven/junit-javadoc.jar" \
                            "97f2fb8b3005d11d5a754adb4d99c926:from-maven/junit-sources.jar" \
                            \
                            "68380001b88006ebe49be50cef5bb23a:from-sonatype/junit.jar" \
                            "7cb390d6759b75fc0c2bedfdeb45877d:from-sonatype/junit.pom" \
                            "ecac656aaa7ef5e9d885c4fad5168133:from-sonatype/junit-javadoc.jar" \
                            "8f17d4271b86478a2731deebdab8c846:from-sonatype/junit-sources.jar"

    assertFileContains 3 log1 2 "::warning::could not download artifact"
    assertFileContains 3 log1 1 "::warning::artifact id build""Tools should be only lowercase"
    assertFileContains 2 log2 2 "::warning::could not download artifact"
}
test_downloadArtifact() {
    (downloadArtifact "$INPUT_TOKEN" "org.modelingvalue" "buildtools" "1.1.1" "jar" "downloaded") >log 2>&1
    assertChecksumsMatch    "83b11ce6151a9beaa79576117f2f1c9f:downloaded/buildtools.jar" \
                            "5d2fa9173c3c1ec0164587b4ece4ec36:$HOME/.m2/repository/org/modelingvalue/buildtools/1.1.1//buildtools-1.1.1.pom" # pom not copied to indicated dir so checking in m2-repos
    rm -rf downloaded
}
test_correctEols() {
    printf "aap\r\nnoot\r\n" > testfile_crlf.txt
    printf "aap\nnoot\n"     > testfile_lf.txt
    if cmp -s testfile_crlf.txt testfile_lf.txt; then
        echo "::error::correctEols precheck failed" 1>&2
        touch "$errorDetectedMarker"
        exit 67
    fi
    correctEols
    if ! cmp -s testfile_crlf.txt testfile_lf.txt; then
        echo "::error::correctEols failed" 1>&2
        touch "$errorDetectedMarker"
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
        touch "$errorDetectedMarker"
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

    assertChecksumsMatch    "b244bf9dc675d01a8c029aafb8b6a628:pom.xml" \
                            "aeb55c0a88fa399f0604ba45b102260e:.idea/libraries/gen__hamcrest_core.xml" \
                            "9da13dd7b8b691d1c6781f39f36d5be8:.idea/libraries/gen__junit.xml" \
                            "c2f5edf722b02968392812dcfe1a10bc:.idea/libraries/gen__multi.xml" \
                            "e5b40e41880c8864b8c1ff7041b1fd54:build.xml" \
                            "208a3ecf8fc0ade893227f0387958b49:TST/module_modtst.xml" \
                            "606cba3391fe62749758d115233d493d:SRC/module_modsrc.xml" \
                            "2084d453d9c1abed6b11623d5f2d2145:BTH/module_modbth.xml" \
                            "851e45a3b74f2265bcfc65a36889277d:settings.xml"
}
test_uploadArtifactQuick() {
    runUploadArtifactTest "tmp.modelingvalue.testingbuildtoolsbuilding" "buildtools" "$INPUT_TOKEN"
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
        touch "$errorDetectedMarker"
    else
        assertFileContains 1553 log.err 4 "^::warning::could not download artifact: " 1>&2
        assertFileContains 1553 log.err 1 "^::error::missing dependency org.modelingvalue:immutable-collections.jar" 1>&2
    fi
}
test_getLatestAsset() {
    getLatestAsset "ModelingValueGroup" "buildtools" "buildtools.jar"
    # checksum varies between releases unfortunately so we only check on existence of the file
    if [[ ! -f "buildtools.jar" && ! -f "build""Tools.jar" ]]; then # TODO: remove uppercase match only for transition
        echo "::error:: test failed: buildtools.jar could not be downloaded"
        touch "$errorDetectedMarker"
        exit 88
    fi
}
test_getAllLatestAssets() {
    getAllLatestAssets "$INPUT_TOKEN" "ModelingValueGroup" "buildtools"
    # checksum varies between releases unfortunately so we only check on existence of the file
    if [[ ! -f "buildtools.jar" && ! -f "build""Tools.jar" ]]; then # TODO: remove uppercase match only for transition
        echo "::error:: test failed: buildtools.jar could not be downloaded"
        touch "$errorDetectedMarker"
        exit 88
    fi
}
test_setOutput() {
    test_setOutput_() {
        local e="$1"; shift
        local v="$1"; shift

        local out="$(setOutput "name" "$v")"
        if [[ "$out" != "::set-output name=name::$e" ]]; then
            echo "::error:: test failed: setOutput does not work correctly: '$out' but '::set-output name=name::$e' expected"
            touch "$errorDetectedMarker"
            exit 88
        fi
    }
    test_setOutput_ "aap"               "aap"
    test_setOutput_ "a%ap"              "a%ap"
    test_setOutput_ "aap%0Anoot%0A"     "$(printf "%s\n%s\n" 'aap'  'noot')"
    test_setOutput_ "a%25ap%0Anoot%0A"  "$(printf "%s\n%s\n" 'a%ap' 'noot')"
}
#######################################################################################################################
#######################################################################################################################
prepareForTesting() {
    if [[ "${GITHUB_WORKSPACE:-}" == "" ]]; then
        export  GITHUB_WORKSPACE="$PWD"
        export GITHUB_REPOSITORY="ModelingValueGroup/buildtools"
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
if [[ "$#" == 0 ]]; then
    tests=( $(declare -F | sed 's/declare -f //' | egrep '^test_' | sort) )
else
    tests=("$@")
fi
prepareForTesting
export errorDetectedMarker="errorDetectedMarker"
failingTests=()
rm -rf tmp
for t in "${tests[@]}"; do
    echo "::group::$t" 1>&2
    printf "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ %s @@@@@@@@@@@@@@@@@@@@@@@@@@@@\n" "$t" 1>&2

    cp out/artifacts/buildtools.jar ~             # fresh jar copy to ~
    rm -rf ~/.m2/repository/*/modelingvalue       # delete our stuff from the .m2 dir

    ##### make tmp dir:
    tmp="tmp/$t"
    rm -rf "$tmp"
    mkdir -p "$tmp"
    (
        cd "$tmp"

        ##### include the produced jar again:
        . <(java -jar ~/buildtools.jar)
        "$t" || touch "$errorDetectedMarker" "../$errorDetectedMarker"
        if [[ -f "$errorDetectedMarker" ]]; then
            touch "../$errorDetectedMarker"
        fi
    ) || touch "tmp/$errorDetectedMarker"
    echo "::endgroup::" 1>&2
    if [[ -f "tmp/$errorDetectedMarker" ]]; then
        failingTests+=("$t")
        rm "tmp/$errorDetectedMarker"
        echo "$t failed"
    fi
done
if [[ "${#failingTests[@]}" != 0 ]]; then
    printf "\n::error::${#failingTests[@]} tests failed: ${failingTests[*]}\n\n"
    exit 56
else
    printf "\nall tests OK\n\n"
fi
