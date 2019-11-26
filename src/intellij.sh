#!/usr/bin/env bash
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

    <groupId>$g</groupId>
    <artifactId>$a</artifactId>
    <version>$v</version>
    <packaging>$e</packaging>

    <dependencies>
$(intellijDependenciesToPom)
    </dependencies>
</project>
EOF
}
generateAntTestFileFromIntellij() {
    genTestLibPaths() {
        local gave
        for gave in $(intellijDependenciesGaves); do
            local g a v e
            gave2vars "$gave" "" ""
            echo "<pathelement location=\"\${path.variable.maven_repository}/${g//.//}/$a/$v/$a-$v.jar\"/>"
        done
    }
    genTestFileSets() {
        find out/test/* -maxdepth 0 -type d -exec echo "<fileset dir=\"{}\"><include name=\"**/*Test.*\"/><include name=\"**/*Tests.*\"/></fileset>" \;
    }

    cat <<EOF | xmlstarlet fo | compareAndOverwrite "test.xml"
<?xml version="1.0" encoding="UTF-8"?>
<project name="test" default="TEST-results.jar">
    <property file="build.properties"/>
    <path id="cp">
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

    <target name="test">
        <junit haltonfailure="on" logfailedtests="on" fork="on" forkmode="once"><!-- fork="on" forkmode="perTest" threads="8" -->
            <classpath refid="cp"/>
            <batchtest todir=".">
$(genTestFileSets)
                <formatter type="xml"/>
            </batchtest>
        </junit>
    </target>

    <target name="TEST-results.jar" depends="test">
        <mkdir dir="\${basedir}/out/artifacts"/>
        <jar destfile="\${basedir}/out/artifacts/TEST-results.jar" filesetmanifest="skip">
            <zipfileset file="\${basedir}/TEST-*.xml"/>
        </jar>
    </target>
</project>
EOF
    importIntoAntFile "build.xml" "test.xml"
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

    cat <<EOF | compareAndOverwrite "$modDir/javadoc.xml"
<?xml version="1.0" encoding="UTF-8"?>
<project name="javadoc.$modName" default="javadoc.module.$modName">
    <property name="$modName.javadoc.dir" value="\${module.$modName.basedir}/../out/javadoc/$modName"/>
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
    importIntoAntFile "build.xml" "$modDir/javadoc.xml"
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
    if ! grep -F "$statement"; then
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
