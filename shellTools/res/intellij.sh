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

export   artifactS3Host="s3.nl-ams.scw.cloud"
export artifactS3Bucket="mvg-artifacts"

generateAll() {
    cleanupIntellijGeneratedAntFiles
    generatePomFromDependencies
    generateIntellijLibraryFilesFromDependencies
    generateAntTestTargets
    generateAntJavadocTargets
}
# shellcheck disable=SC2120
cleanupIntellijGeneratedAntFiles() {
    local extraAntFiles=("$@")

    for xml in build.xml module_*.xml */module_*.xml "${extraAntFiles[@]}"; do
        if [[ -f "$xml" ]]; then

            # - add includeantruntime="false" for all <javac> calls:
            sed 's|<javac \([^i]\)|<javac includeantruntime="false" \1|' "$xml" | compareAndOverwrite "$xml"

            # - unfortunately IntellJ generates absolute paths for some zipfileset, I cant find a way to correct this automatically....
            if grep -Fq '="/' "$xml"; then
                echo "::error::the ant file '$xml' may contain an absolute path: $(grep -F '="/' "$xml")" 1>&2
                exit 83
            fi
        fi
    done
}
generatePomFromDependencies() {
    local g a v e flags
    read g a v e flags < <(getFirstArtifactWithFlags)
    cat <<EOF | xmlstarlet fo | compareAndOverwrite "pom.xml"
<?xml version="1.0" encoding="UTF-8"?>
<!--==============================================================-->
<!-- WARNING: this file will be overwritten by the build scripts! -->
<!--          change  project.sh  instead                         -->
<!--==============================================================-->
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>$g</groupId>
    <artifactId>$a</artifactId>
    <version>$v</version>
    <packaging>$e</packaging>
    <scm>
        <url>$GITHUB_PACKAGE_URL</url>
    </scm>
    <dependencies>
$(
    getDependencyGavesWithFlags | while read g a v e flags; do
        if [[ $g != '' ]]; then
            local dep="<groupId>$g</groupId><artifactId>$a</artifactId><version>$v</version>"
            if [[ "$flags" =~ .*t.* ]]; then
                dep+="<scope>test</scope>"
            fi
            echo "<dependency>$dep</dependency>"
        fi
    done
)
    </dependencies>
</project>
EOF
}
generateIntellijLibraryFilesFromDependencies() {
    local g a v e flags
    mkdir -p ".idea/libraries"
    for i in ".idea/libraries/gen__"*; do
        if [[ -f "$i" ]] && grep -Fq '<library name="gen: ' "$i"; then
            rm "$i"
        fi
    done
    getDependencyGavesWithFlags \
        | while read g a v e flags; do
            if [[ $g != "" ]]; then
                local fileName="gen__$(sed 's/[^a-zA-Z0-9]/_/g' <<<"$a")"
                cat <<EOF | compareAndOverwrite ".idea/libraries/$fileName.xml"
<!--==============================================================-->
<!-- WARNING: this file will be overwritten by the build scripts! -->
<!--          change  project.sh  instead                         -->
<!--==============================================================-->
<component name="libraryTable">
  <library name="gen: $a">
$(
if [[ "$flags" =~ .*j.* ]]; then
    echo "    <CLASSES>"
    echo "      <root url=\"jar://\$PROJECT_DIR\$/lib/$a.jar!/\" />"
    echo "    </CLASSES>"
else
    echo "    <CLASSES />"
fi
)
$(
if [[ "$flags" =~ .*d.* ]]; then
    echo "    <JAVADOC>"
    echo "      <root url=\"jar://\$PROJECT_DIR\$/lib/$a-javadoc.jar!/\" />"
    echo "    </JAVADOC>"
else
    echo "    <JAVADOC />"
fi
)
$(
if [[ "$flags" =~ .*s.* ]]; then
    echo "    <SOURCES>"
    echo "      <root url=\"jar://\$PROJECT_DIR\$/lib/$a-sources.jar!/\" />"
    echo "    </SOURCES>"
else
    echo "    <SOURCES />"
fi
)
  </library>
</component>
EOF
            fi
        done
    . <(catProjectSh)
    getDependencyJarVars \
        | while read var; do
            if [[ "$var" != "" ]]; then
                local fileName="gen__$var"
                eval "local jars=(\"\${${var}[@]}\")"
                cat <<EOF | compareAndOverwrite ".idea/libraries/$fileName.xml"
<!--==============================================================-->
<!-- WARNING: this file will be overwritten by the build scripts! -->
<!--          change  project.sh  instead                         -->
<!--==============================================================-->
<component name="libraryTable">
  <library name="gen: $var">
    <CLASSES>
$(
for jar in "${jars[@]}"; do
    echo "      <root url=\"jar://\$PROJECT_DIR\$/$jar!/\" />"
done
)
    </CLASSES>
    <JAVADOC />
    <SOURCES />
  </library>
</component>
EOF
            fi
        done
}
generateAntTestTargets() {
    cond__() {
        local modDir="$1"; shift
        local    xml="$1"; shift

        [[ -d "$modDir/tst" ]] && grep -Fq ".module.test.sourcepath" "$xml"
    }
    target__() {
        local    modName="$1"; shift
        local modNameLow="$1"; shift
        local targetName="$1"; shift

        case "$targetName" in
        test.module.$modNameLow)
            cat <<EOF
    <target name="test.module.$modNameLow">
        <junit haltonfailure="on" logfailedtests="on" fork="on" forkmode="once">
            <!-- fork="on" forkmode="perTest" threads="8" -->
            <classpath refid="$modNameLow.runtime.module.classpath"/>
            <batchtest todir=".">
                <fileset dir="\${$modNameLow.testoutput.dir}">
                    <include name="**/*Test.*"/>
                    <include name="**/*Tests.*"/>
                </fileset>
                <formatter type="xml"/>
            </batchtest>
        </junit>
    </target>
EOF
            ;;
        testresults.module.$modNameLow)
            cat <<EOF
    <target name="testresults.module.$modNameLow" depends="test.module.$modNameLow">
        <mkdir dir="\${basedir}/out/artifacts"/>
        <jar destfile="\${basedir}/out/artifacts/$modName-testresults.jar" filesetmanifest="skip">
            <zipfileset file="\${basedir}/TEST-*.xml"/>
        </jar>
    </target>
EOF
            ;;
        esac
    }
    enrichAntFiles cond__ target__ "test" "test.module" "testresults.module"
}
generateAntJavadocTargets() {
    cond__() {
        local modDir="$1"; shift
        local    xml="$1"; shift

        [[ -d "$modDir/src" ]] && grep -Fq ".module.sourcepath" "$xml"
    }
    target__() {
        local    modName="$1"; shift
        local modNameLow="$1"; shift
        local targetName="$1"; shift

        cat <<EOF
    <target name="javadoc.module.$modNameLow">
        <property name="$modNameLow.javadoc.dir" value="\${basedir}/out/artifacts"/>
        <property name="$modNameLow.javadoc.tmp" value="\${$modNameLow.javadoc.dir}/tmp"/>
        <property name="$modNameLow.javadoc.jar" value="\${$modNameLow.javadoc.dir}/$modName-javadoc.jar"/>
        <javadoc sourcepathref="$modNameLow.module.sourcepath" destdir="\${$modNameLow.javadoc.tmp}" classpathref="$modNameLow.module.classpath"/>
        <jar destfile="\${$modNameLow.javadoc.jar}" filesetmanifest="skip">
            <zipfileset dir="\${$modNameLow.javadoc.tmp}"/>
        </jar>
        <delete dir="\${$modNameLow.javadoc.tmp}"/>
    </target>
EOF
    }
    enrichAntFiles cond__ target__ "javadoc" "javadoc.module"
}
enrichAntFiles() {
    local   condFunc="$1"; shift
    local targetFunc="$1"; shift
    local mainTarget="$1"; shift
    local subTargets=("$@")

    local    mainAntFile="build.xml"
    local mainAntFileTmp="$mainAntFile.tmp"

    if [[ ! -f "$mainAntFile" ]]; then
        echo "::error::there is no ant file $mainAntFile, please generate it first" 1>&2
        exit 77
    fi
    local subs=""
    local all
    all="$(getIntellijModules)"
    local modDirAndName
    for modDirAndName in $all; do
        local modDir modName modNameLow
        IFS=/ read -r modDir modName <<<"$modDirAndName"
        if [[ "$modName" == "" ]]; then
            modName="$modDir"
            modDir="."
        fi
        modNameLow="${modName,,}"
        xml="$modDir/module_$modNameLow.xml"

        if [[ ! -f "$xml" ]]; then
            echo "::error::there is no ant file $xml, please generate it first" 1>&2
            exit 77
        fi
        if "$condFunc" "$modDir" "$xml"; then
            local tmp="$xml.tmp"
            cp "$xml" "$tmp"
            for subTarget in "${subTargets[@]}"; do
                local sub="$subTarget.$modNameLow"
                rmTargetFromAntFile "$tmp" "$sub"
                "$targetFunc" "$modName" "$modNameLow" "$sub" | addSnippetToAntFile  "$tmp"
            done
            cat "$tmp" | xmlstarlet fo | compareAndOverwrite "$xml"
            rm "$tmp"

            if [[ "$subs" != "" ]]; then
                subs+=","
            fi
            subs+="$sub"
        fi
    done
    cp "$mainAntFile" "$mainAntFileTmp"
    rmTargetFromAntFile "$mainAntFileTmp" "$mainTarget"
    addSnippetToAntFile  "$mainAntFileTmp" <<EOF
    <target name="$mainTarget" depends="$subs">
        <echo>all done for $mainTarget</echo>
    </target>
EOF
    cat "$mainAntFileTmp" | xmlstarlet fo | compareAndOverwrite "$mainAntFile"
    rm "$mainAntFileTmp"
}
addSnippetToAntFile() {
    local xml="$1"; shift

    ed "$xml" <<EOF >/dev/null
/<[/]project>
i
$(cat)
.
w
q
EOF
}
rmTargetFromAntFile() {
    local  xml="$1"; shift
    local name="$1"; shift

    if grep -Fq "<target name=\"$name\"" "$xml"; then
        ed "$xml" <<EOF >/dev/null
/<target name="$name"[ >]
.,/<[/]target>/d
w
q
EOF
    fi
}
getAllDependencies() {
    local token="$1"; shift
    local s3ACC="${1:-}"
    local s3SEC="${2:-}"

    local g a v e flags
    local branch="$(sed 's|^refs/heads/||;s|/|_|g' <<<"$GITHUB_REF")"
    local    lib="lib"
    mkdir -p "$lib"

    if [[ "$token" != "" ]]; then
        echo "## trying to get dependencies from maven..."
        while read g a v e flags; do
            if [[ $g != '' ]]; then
                downloadArtifactQuick "$token" "$g" "$a" "$v" "$e" "$lib"
            fi
        done < <(getDependencyGavesWithFlags)
    fi

    if [[ "$branch" != "master" && "$s3ACC" != "" && "$s3SEC" != "" ]]; then
        installS3cmd "https://$artifactS3Host" "$s3ACC" "$s3SEC"
        if command -v s3cmd; then
            echo "## trying to get dependencies from S3 (because this is NOT the master branch)..."
            local     tmpLib="tmpLib"
            local tmpTrigger="${GITHUB_REPOSITORY////#}.trigger"
            mkdir -p $tmpLib
            printf "TRIGGER_REPOSITORY='%s'\nTRIGGER_BRANCH='%s'\n" "$GITHUB_REPOSITORY" "$branch" > "$tmpLib/$tmpTrigger"
            while read g a v e flags; do
                if [[ $g != '' ]]; then
                    local parts=()
                    if [[ "$flags" =~ .*j.* ]]; then parts+=("$a"        ); fi
                    if [[ "$flags" =~ .*d.* ]]; then parts+=("$a-javadoc"); fi
                    if [[ "$flags" =~ .*s.* ]]; then parts+=("$a-sources"); fi
                    local s3dir="s3://$artifactS3Bucket/$g/$a/$branch"
                    for aa in "${parts[@]}"; do
                        if s3cmd_ --force get "$s3dir/$aa.$e" $tmpLib 2>/dev/null 1>&2; then
                            echo "## got latest $g:$aa for branch $branch from S3"
                        else
                            echo "## could not get $g:$aa for branch $branch from S3"
                        fi
                    done
                    s3cmd_ --force put "$tmpLib/$tmpTrigger" "$s3dir/triggers/$tmpTrigger"
                fi
            done < <(getDependencyGavesWithFlags)
            rm "$tmpLib/$tmpTrigger"
            mv $tmpLib/* "$lib" 2>/dev/null || :
            rm -rf $tmpLib
        fi
    fi

    echo "## checking if we have the required dependencies..." 1>&2
    local missingSome=false
    while read g a v e flags; do
        if [[ $g != '' && ! -f "$lib/$a.$e" ]]; then
            echo "::error::missing dependency $g:$a.$e" 1>&2
            missingSome=true
        fi
    done < <(getDependencyGavesWithFlags)
    if [[ "$missingSome" == true ]]; then
        exit 82
    else
        echo "## all dependencies downloaded ok"
    fi
}
getFirstArtifactWithFlags() {
    . <(catProjectSh)
    printf "%s\n" "${artifacts[0]}"
}
getDependencyGavesWithFlags() {
    . <(catProjectSh)
    printf "%s\n" "${dependencies[@]}" | fgrep -v "@" | sort -u
}
getDependencyJarVars() {
    . <(catProjectSh)
    printf "%s\n" "${dependencies[@]}" | sed -n "s/jars@//p" | sort -u
}
getIntellijModules() {
    local modules=".idea/modules.xml"
    if [[ ! -f "$modules" ]]; then
        echo "::error::intellij modules.xml file not found" 1>&2
        exit 45
    fi
    xmlstarlet sel -t -v project/component/modules/module/@filepath -n "$modules" |sed 's/\$[^$]*\$//g;s|^/||;s|\.iml$||'
}
# shellcheck disable=SC2120
catProjectSh() {
    local maybeAbsent="${1:-}"

    if [[ ! -f "project.sh" ]]; then
        if [[ "$maybeAbsent" != "-maybeAbsent" ]]; then
            echo "::error::project.sh file not found" 1>&2
            exit 45
        fi
    else
        cat <<EOF
local artifacts=()
local dependencies=()
local repositories=()
$(cat project.sh)
EOF
    fi
}
