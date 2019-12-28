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
      for gave in $(getdependencyGaves); do
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
generateIntellijLibraryFilesFromDependencies() {
    while read flags g a v e; do
        generateIntellijLibraryFileFromDependencies "$flags" "$g" "$a" "$v" "$e" > ".idea/libraries/Maven__${g//./_}_${a//-/_}.xml"
    done < <(sed 's/ *#.*//;/^$/d' dependencies)
}
generateIntellijLibraryFilesFromDependencies() {
    while read flags g a v e; do
        generateIntellijLibraryFileFromDependencies "$flags" "$g" "$a" "$v" "$e"
    done < <(sed 's/ *#.*//;/^$/d' dependencies)
}
generateIntellijLibraryFileFromDependencies() {
    local flags="$1"; shift
    local     g="$1"; shift
    local     a="$1"; shift
    local     v="$1"; shift
    local     e="$1"; shift

    cat <<EOF
<component name="libraryTable">
  <library name="Maven: $g:$a">
$(
if [[ "$flags" =~ 1.. ]]; then
    echo "    <CLASSES>"
    echo "      <root url=\"jar://\$MAVEN_REPOSITORY\$/${g//.//}/$a/$v/$a-$v.$e!/\" />"
    echo "    </CLASSES>"
else
    echo "    <CLASSES />"
fi
)
$(
if [[ "$flags" =~ .1. ]]; then
    echo "    <JAVADOC>"
    echo "      <root url=\"jar://\$MAVEN_REPOSITORY\$/${g//.//}/$a/$v/$a-$v-javadoc.$e!/\" />"
    echo "    </JAVADOC>"
else
    echo "    <JAVADOC />"
fi
)
$(
if [[ "$flags" =~ ..1 ]]; then
    echo "    <SOURCES>"
    echo "      <root url=\"jar://\$MAVEN_REPOSITORY\$/${g//.//}/$a/$v/$a-$v-sources.$e!/\" />"
    echo "    </SOURCES>"
else
    echo "    <SOURCES />"
fi
)
  </library>
</component>
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
            for gave in $(getdependencyGaves); do
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

    local        xml="$modDir/javadoc.xml"
    local modNameLow="${modName,,}"

    cat <<EOF | compareAndOverwrite "$xml"
<?xml version="1.0" encoding="UTF-8"?>
<project name="javadoc.$modName" default="javadoc.module.$modName">
    <!--==============================================================-->
    <!-- WARNING: this file will be overwritten by the build scripts! -->
    <!--==============================================================-->
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
getdependencyGaves() {
    if [[ -f dependencies ]]; then
        while read flags g a v e; do
            echo "$g:$a:$v:$e"
        done < <(sed 's/ *#.*//;/^$/d' dependencies)
    else
        local libxml
        for libxml in .idea/libraries/*.xml; do
          xmlstarlet sel -t -v component/library/@name "$libxml" | sed 's/^Maven: *//'
          echo
        done
    fi | sort -u
}
intellijModules() {
    local modules=".idea/modules.xml"
    if [[ ! -f "$modules" ]]; then
        echo "::error::intellij modules.xml file not found"
        exit 45
    fi
    xmlstarlet sel -t -v project/component/modules/module/@filepath -n "$modules" |sed 's/\$[^$]*\$//g;s|^/||;s|\.iml$||'
}
