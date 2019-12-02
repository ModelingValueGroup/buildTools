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
##     Wim Bast, Carel Bast, Tom Brus                                                                                  ~
## Contributors:                                                                                                       ~
##     Arjan Kok, Ronald Krijgsheld                                                                                    ~
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

set -euo pipefail

cleanupIntellijAntFiles() {
    local extraAntFiles=("$@")

    for xml in build.xml */module_*.xml "${extraAntFiles[@]}"; do
        if [[ -f "$xml" ]]; then

            # - add includeantruntime="false" for all <javac> calls:
            sed 's|<javac \([^i]\)|<javac includeantruntime="false" \1|' "$xml" | compareAndOverwrite "$xml"

            # - unfortunately IntellJ generates absolute paths for some zipfileset, I cant find a way to correct this automatically....
            if grep -Fq '="/' "$xml"; then
                echo "::error::the ant file '$xml' may contain an absolute path: $(grep -F '="/' "$xml")"
                exit 83
            fi
        fi
    done
}
updateAllPomsFromIntellijDependencies() {
  local pom
  for pom in *pom.xml; do
    if [[ -f "$pom" ]]; then
      updatePomFromIntellijDependencies "$pom"
    fi
  done
}
updatePomFromIntellijDependencies() {
    local pom="$1"; shift

    local g a v e
    gave2vars "$(extractGaveFromPom "$pom")" "" ""
    e="${e:-jar}"

    intellijDependenciesToPom() {
      local gave
      for gave in $(intellijDependenciesGaves); do
          local g a v e
          gave2vars "$gave" "" ""
          echo "<dependency><groupId>$g</groupId><artifactId>$a</artifactId><version>$v</version></dependency>"
      done
    }

    cat <<EOF | xmlstarlet fo | compareAndOverwrite "$pom"
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <!--==============================================================-->
    <!-- WARNING: this file will be overwritten by the build scripts! -->
    <!--==============================================================-->
    <!-- only the 4 lines below will survive -->
    <groupId>$g</groupId>
    <artifactId>$a</artifactId>
    <version>$v</version>
    <packaging>$e</packaging>
    <!--==============================================================-->
    <dependencies>
$(intellijDependenciesToPom)
    </dependencies>
</project>
EOF
}
generateAntTestFilesFromIntellij() {
    local mm
    for mm in $(intellijModules); do
        local modDir modName
        IFS=/ read -r modDir modName <<<"$mm"
        generateAntTestFileFromIntellij "$modDir" "$modName"
    done
}
generateAntTestFileFromIntellij() {
    local  modDir="$1"; shift
    local modName="$1"; shift

    if [[ -d "$modDir/tst" ]]; then
        local xml="$modDir/test.xml"

        genTestLibPaths() {
            local gave
            for gave in $(intellijDependenciesGaves); do
                local g a v e
                gave2vars "$gave" "" ""
                echo "<pathelement location=\"\${path.variable.maven_repository}/${g//.//}/$a/$v/$a-$v.jar\"/>"
            done
        }

        cat <<EOF | xmlstarlet fo | compareAndOverwrite "$xml"
<?xml version="1.0" encoding="UTF-8"?>
<project name="test.$modName" default="test.results.jar.$modName">
    <!--==============================================================-->
    <!-- WARNING: this file will be overwritten by the build scripts! -->
    <!--==============================================================-->
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
}
generateAntJavadocFilesFromIntellij() {
    local mm
    for mm in $(intellijModules); do
        local modDir modName
        IFS=/ read -r modDir modName <<<"$mm"
        generateAntJavadocFileFromIntellij "$modDir" "$modName"
    done
}
generateAntJavadocFileFromIntellij() {
    local  modDir="$1"; shift
    local modName="$1"; shift

    local xml="$modDir/javadoc.xml"

    cat <<EOF | compareAndOverwrite "$xml"
<?xml version="1.0" encoding="UTF-8"?>
<project name="javadoc.$modName" default="javadoc.module.$modName">
    <!--==============================================================-->
    <!-- WARNING: this file will be overwritten by the build scripts! -->
    <!--==============================================================-->
    <property name="$modName.javadoc.dir" value="\${basedir}/out/artifacts"/>
    <property name="$modName.javadoc.tmp" value="\${$modName.javadoc.dir}/tmp"/>
    <property name="$modName.javadoc.jar" value="\${$modName.javadoc.dir}/$modName-javadoc.jar"/>

    <target name="javadoc.module.$modName">
        <javadoc sourcepathref="$modName.module.test.sourcepath" destdir="\${$modName.javadoc.tmp}" classpathref="$modName.module.classpath"/>
        <jar destfile="\${$modName.javadoc.jar}" filesetmanifest="skip">
            <zipfileset dir="\${$modName.javadoc.tmp}"/>
        </jar>
        <delete dir="\${$modName.javadoc.tmp}"/>
    </target>
</project>
EOF
    importIntoAntFile "build.xml" "$xml"
}
importIntoAntFile() {
    local   into="$1"; shift
    local import="$1"; shift

    if [[ ! -f "$into" ]]; then
        echo "::error::importIntoAntFile can not find $into"
        exit 72
    fi
    if [[ ! -f "$import" ]]; then
        echo "::error::importIntoAntFile can not find $import"
        exit 72
    fi
    local statement="<import file=\"\${basedir}/$import\"/>"
    if ! grep -Fq "$statement" "$into"; then
        sed "s|</project>|$statement&|" "$into" | compareAndOverwrite "$into"
    fi
}
intellijDependenciesGaves() {
    local libxml
    for libxml in .idea/libraries/*.xml; do
      xmlstarlet sel -t -v component/library/@name "$libxml" | sed 's/^Maven: *//'
      echo
    done | sort -u
}
intellijModules() {
    local modules=".idea/modules.xml"
    if [[ ! -f "$modules" ]]; then
        echo "::error::intellij modules.xml file not found"
        exit 45
    fi
    xmlstarlet sel -t -v project/component/modules/module/@filepath -n "$modules" |sed 's/\$[^$]*\$//g;s|^/||;s|\.iml$||'
}
