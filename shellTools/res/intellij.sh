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
    generateAntTestFilesFromIntellij
    generateAntJavadocFilesFromIntellij
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
set -x
    local g a v e flags
    read g a v e flags < <(getFirstArtifactWithFlags)
    cat <<EOF | compareAndOverwrite "pom.xml"
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
            echo "<dependency><groupId>$g</groupId><artifactId>$a</artifactId><version>$v</version></dependency>"
        fi
    done
)
    </dependencies>
</project>
EOF
set +x
}
generateIntellijLibraryFilesFromDependencies() {
    local g a v e flags
    mkdir -p ".idea/libraries"
    getDependencyGavesWithFlags | while read g a v e flags; do
        if [[ $g != '' ]]; then
            cat <<EOF | compareAndOverwrite ".idea/libraries/Maven__${g//./_}_${a//-/_}.xml"
<!--==============================================================-->
<!-- WARNING: this file will be overwritten by the build scripts! -->
<!--          change  project.sh  instead                         -->
<!--==============================================================-->
<component name="libraryTable">
  <library name="Maven: $g:$a">
$(
if [[ "$flags" =~ .*j.* ]]; then
    echo "    <CLASSES>"
    echo "      <root url=\"jar://\$MAVEN_REPOSITORY\$/$(makeArtifactPath "$g" "$a" "$v" "$e" "")!/\" />"
    echo "    </CLASSES>"
else
    echo "    <CLASSES />"
fi
)
$(
if [[ "$flags" =~ .*d.* ]]; then
    echo "    <JAVADOC>"
    echo "      <root url=\"jar://\$MAVEN_REPOSITORY\$/$(makeArtifactPath "$g" "$a" "$v" "$e" "javadoc")!/\" />"
    echo "    </JAVADOC>"
else
    echo "    <JAVADOC />"
fi
)
$(
if [[ "$flags" =~ .*s.* ]]; then
    echo "    <SOURCES>"
    echo "      <root url=\"jar://\$MAVEN_REPOSITORY\$/$(makeArtifactPath "$g" "$a" "$v" "$e" "sources")!/\" />"
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
generateAntTestFilesFromIntellij() {
    local modDirAndName
    local all
    all="$(getIntellijModules)"
    for modDirAndName in $all; do
        local modDir modName
        IFS=/ read -r modDir modName <<<"$modDirAndName"

        if [[ -d "$modDir/tst" ]]; then
            local xml="$modDir/test.xml"

            genTestLibPaths() {
                local g a v e flags
                getDependencyGavesWithFlags | while read g a v e flags; do
                    echo "<pathelement location=\"\${path.variable.maven_repository}/$(makeArtifactPath "$g" "$a" "$v" "$e" "")\"/>"
                done
            }

            cat <<EOF | xmlstarlet fo | compareAndOverwrite "$xml"
<?xml version="1.0" encoding="UTF-8"?>
<!--==============================================================-->
<!-- WARNING: this file will be overwritten by the build scripts! -->
<!--          change  project.sh  instead                         -->
<!--==============================================================-->
<project name="test.$modName" default="test.results.jar.$modName">
    <path id="classpath.test.$modName">
        <path>
$(genTestLibPaths)
        </path>
        <dirset dir="out/production">
            <include name="*"/>
        </dirset>
        <dirset dir="out/test">
            <include name="*"/>
        </dirset>
    </path>

    <target name="test.$modName">
        <junit haltonfailure="on" logfailedtests="on" fork="on" forkmode="once"><!-- fork="on" forkmode="perTest" threads="8" -->
            <classpath refid="classpath.test.$modName"/>
            <batchtest todir=".">
                <fileset dir="out/test/$modDir">
                    <include name="**/*Test.*"/>
                    <include name="**/*Tests.*"/>
                </fileset>
                <formatter type="xml"/>
            </batchtest>
        </junit>
    </target>

    <target name="test.results.jar.$modName" depends="test.$modName">
        <mkdir dir="\${basedir}/out/artifacts"/>
        <jar destfile="\${basedir}/out/artifacts/$modName-testresults.jar" filesetmanifest="skip">
            <zipfileset file="\${basedir}/TEST-*.xml"/>
        </jar>
    </target>
</project>
EOF
            importIntoAntFile "build.xml" "$xml"
        fi
    done
}
generateAntJavadocFilesFromIntellij() {
    local modDirAndName
    local all
    all="$(getIntellijModules)"
    for modDirAndName in $all; do
        local modDir modName
        IFS=/ read -r modDir modName <<<"$modDirAndName"
        local modNameLow="${modName,,}"
        local xml="$modDir/javadoc.xml"

        cat <<EOF | compareAndOverwrite "$xml"
<?xml version="1.0" encoding="UTF-8"?>
<!--==============================================================-->
<!-- WARNING: this file will be overwritten by the build scripts! -->
<!--          change  project.sh  instead                         -->
<!--==============================================================-->
<project name="javadoc.$modName" default="javadoc.module.$modName">
    <property name="$modNameLow.javadoc.dir" value="\${basedir}/out/artifacts"/>
    <property name="$modNameLow.javadoc.tmp" value="\${$modNameLow.javadoc.dir}/tmp"/>
    <property name="$modNameLow.javadoc.jar" value="\${$modNameLow.javadoc.dir}/$modName-javadoc.jar"/>

    <target name="javadoc.module.$modName">
        <javadoc sourcepathref="$modNameLow.module.test.sourcepath" destdir="\${$modNameLow.javadoc.tmp}" classpathref="$modNameLow.module.classpath"/>
        <jar destfile="\${$modNameLow.javadoc.jar}" filesetmanifest="skip">
            <zipfileset dir="\${$modNameLow.javadoc.tmp}"/>
        </jar>
        <delete dir="\${$modNameLow.javadoc.tmp}"/>
    </target>
</project>
EOF
        importIntoAntFile "build.xml" "$xml"
    done
}
importIntoAntFile() {
    local   into="$1"; shift
    local import="$1"; shift

    if [[ ! -f "$into" ]]; then
        echo "::error::importIntoAntFile can not find $into" 1>&2
        exit 72
    fi
    if [[ ! -f "$import" ]]; then
        echo "::error::importIntoAntFile can not find $import" 1>&2
        exit 72
    fi
    local statement="<import file=\"\${basedir}/$import\"/>"
    if ! grep -Fq "$statement" "$into"; then
        sed "s|</project>|$statement&|" "$into" | compareAndOverwrite "$into"
    fi
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
