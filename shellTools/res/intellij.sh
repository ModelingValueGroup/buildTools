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

    for xml in build.xml */module_*.xml "${extraAntFiles[@]}"; do
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
    for i in ".idea/libraries/gen!"*; do
        if [[ -f "$i" ]] && grep -Fq '<library name="gen: ' "$i"; then
            rm "$i"
        fi
    done
    getDependencyGavesWithFlags | while read g a v e flags; do
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
}
generateAntTestTargets() {
    if [[ ! -f "build.xml" ]]; then
        echo "::error::there is no ant file build.xml, please generate it first"
        exit 77
    fi
    local subs=""
    local modDirAndName
    local all
    all="$(getIntellijModules)"
    for modDirAndName in $all; do
        local modDir modName
        IFS=/ read -r modDir modName <<<"$modDirAndName"
        if [[ -d "$modDir/tst" ]]; then
            local modNameLow="${modName,,}"
            local        xml="$modDir/module_$modNameLow.xml"
            local        tmp="$xml.tmp"

            if [[ ! -f "$xml" ]]; then
                echo "::error::there is no ant file $xml, please generate it first"
                exit 77
            fi
            cp "$xml" "$tmp"
            rmTargetFromAntFile "$tmp" "test.$modNameLow"
            addSnippetToAntFile  "$tmp" <<EOF
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
            rmTargetFromAntFile "$tmp" "test.results.jar.$modNameLow"
            addSnippetToAntFile  "$tmp" <<EOF
    <target name="testresults.module.$modNameLow" depends="test.module.$modNameLow">
        <mkdir dir="\${basedir}/out/artifacts"/>
        <jar destfile="\${basedir}/out/artifacts/$modNameLow-testresults.jar" filesetmanifest="skip">
            <zipfileset file="\${basedir}/TEST-*.xml"/>
        </jar>
    </target>
EOF
            cat "$tmp" | xmlstarlet fo | compareAndOverwrite "$xml"
            rm "$tmp"

            if [[ "$subs" != "" ]]; then
                subs+=","
            fi
            subs+="testresults.module.$modNameLow"
        fi
    done
    local tmp="build.xml.tmp"
    cp "build.xml" "$tmp"
    rmTargetFromAntFile "$tmp" "test"
    addSnippetToAntFile  "$tmp" <<EOF
    <target name="test" depends="$subs">
        <echo>all tests done</echo>
    </target>
EOF
    cat "$tmp" | xmlstarlet fo | compareAndOverwrite "build.xml"
    rm "$tmp"
}
generateAntJavadocTargets() {
    if [[ ! -f "build.xml" ]]; then
        echo "::error::there is no ant file build.xml, please generate it first"
        exit 77
    fi
    local subs=""
    local modDirAndName
    local all
    all="$(getIntellijModules)"
    for modDirAndName in $all; do
        local modDir modName
        IFS=/ read -r modDir modName <<<"$modDirAndName"
        local modNameLow="${modName,,}"
        local        xml="$modDir/module_$modNameLow.xml"
        local        tmp="$xml.tmp"

        if [[ ! -f "$xml" ]]; then
            echo "::error::there is no ant file $xml, please generate it first"
            exit 77
        fi
        cp "$xml" "$tmp"
        rmTargetFromAntFile "$tmp" "javadoc.module.$modNameLow"
        addSnippetToAntFile  "$tmp" <<EOF
    <target name="javadoc.module.$modNameLow">
        <property name="$modNameLow.javadoc.dir" value="\${basedir}/out/artifacts"/>
        <property name="$modNameLow.javadoc.tmp" value="\${$modNameLow.javadoc.dir}/tmp"/>
        <property name="$modNameLow.javadoc.jar" value="\${$modNameLow.javadoc.dir}/$modName-javadoc.jar"/>
        <javadoc sourcepathref="$modNameLow.module.test.sourcepath" destdir="\${$modNameLow.javadoc.tmp}" classpathref="$modNameLow.module.classpath"/>
        <jar destfile="\${$modNameLow.javadoc.jar}" filesetmanifest="skip">
            <zipfileset dir="\${$modNameLow.javadoc.tmp}"/>
        </jar>
        <delete dir="\${$modNameLow.javadoc.tmp}"/>
    </target>
EOF
        cat "$tmp" | xmlstarlet fo | compareAndOverwrite "$xml"
        rm "$tmp"

        if [[ "$subs" != "" ]]; then
            subs+=","
        fi
        subs+="javadoc.module.$modNameLow"
    done
    local tmp="build.xml.tmp"
    cp "build.xml" "$tmp"
    rmTargetFromAntFile "$tmp" "javadoc"
    addSnippetToAntFile  "$tmp" <<EOF
    <target name="javadoc" depends="$subs">
        <echo>all javadoc generated</echo>
    </target>
EOF
    cat "$tmp" | xmlstarlet fo | compareAndOverwrite "build.xml"
    rm "$tmp"
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

    local lib="lib"
    mkdir -p "$lib"
    mvn_ "$token" dependency:copy-dependencies -Dmdep.stripVersion=true -DoutputDirectory="$lib"
    mvn_ "$token" dependency:copy-dependencies -Dmdep.stripVersion=true -DoutputDirectory="$lib" -Dclassifier=javadoc
    mvn_ "$token" dependency:copy-dependencies -Dmdep.stripVersion=true -DoutputDirectory="$lib" -Dclassifier=sources
}
getFirstArtifactWithFlags() {
    if [[ ! -f "project.sh" ]]; then
        echo "::error::project.sh file not found" 1>&2
        exit 45
    fi
    local artifacts=()
    . project.sh
    printf "%s\n" "${artifacts[0]}"
}
getDependencyGavesWithFlags() {
    if [[ ! -f "project.sh" ]]; then
        echo "::error::project.sh file not found" 1>&2
        exit 45
    fi
    local dependencies=()
    . project.sh
    printf "%s\n" "${dependencies[@]}" | sort -u
}
getIntellijModules() {
    local modules=".idea/modules.xml"
    if [[ ! -f "$modules" ]]; then
        echo "::error::intellij modules.xml file not found" 1>&2
        exit 45
    fi
    xmlstarlet sel -t -v project/component/modules/module/@filepath -n "$modules" |sed 's/\$[^$]*\$//g;s|^/||;s|\.iml$||'
}
