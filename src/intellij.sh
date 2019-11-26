#!/usr/bin/env bash
set -euo pipefail

cleanupIntellijAntFiles() {
    local extraAntFiles=("$@")

    for xml in build.xml */module_*.xml "${extraAntFiles[@]}"; do
        if [[ -f "$xml" ]]; then
            # - unfortunately IntellJ generates absolute paths for some zipfileset:
            # - add includeantruntime="false" for all <javac> calls:
            cat "$xml" \
                | sed 's|<zipfileset dir="/.*/jdclare/|<zipfileset dir="${basedir}/|' \
                | sed 's|<javac \([^i]\)|<javac includeantruntime="false" \1|' \
                | compareAndOverwrite "$xml"
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
        ls -d out/test/* \
            | while read d; do
                echo "<fileset dir=\"$d\"><include name=\"**/*Test.*\"/><include name=\"**/*Tests.*\"/></fileset>"
            done
    }

    cat <<EOF | xmlstarlet fo | compareAndOverwrite "test.xml"
<?xml version="1.0" encoding="UTF-8"?>
<project name="test" default="test">
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

    <target name="artifact.test-results" depends="init.artifacts" description="Build &#39;TEST-results&#39; artifact">
        <property name="artifact.temp.output.test-results" value="${artifacts.temp.dir}/TEST_results"/>
        <mkdir dir="${artifact.temp.output.test-results}"/>
        <jar destfile="${temp.jar.path.TEST-results.jar}" duplicate="preserve" filesetmanifest="mergewithoutmain">
            <zipfileset file="${basedir}/TEST-org.modelingvalue.collections.test.AgeTest.xml"/>
            <zipfileset file="${basedir}/TEST-org.modelingvalue.collections.test.DefaultMapTest.xml"/>
            <zipfileset file="${basedir}/TEST-org.modelingvalue.collections.test.LambdaTest.xml"/>
            <zipfileset file="${basedir}/TEST-org.modelingvalue.collections.test.ListTest.xml"/>
            <zipfileset file="${basedir}/TEST-org.modelingvalue.collections.test.MapTest.xml"/>
            <zipfileset file="${basedir}/TEST-org.modelingvalue.collections.test.SerializeTest.xml"/>
            <zipfileset file="${basedir}/TEST-org.modelingvalue.collections.test.SetTest.xml"/>
        </jar>
        <copy file="${temp.jar.path.TEST-results.jar}" tofile="${artifact.temp.output.test-results}/TEST-results.jar"/>
    </target>
</project>
EOF
    if [[ -f build.xml ]]; then
        cat "build.xml" \
            | sed 's|<import file="${basedir}/test.xml"/>||' \
            | sed 's|</project>|<import file="${basedir}/test.xml"/>&|' \
            | compareAndOverwrite "build.xml"
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

    cat <<EOF | compareAndOverwrite "$modDir/javadoc.xml"
<?xml version="1.0" encoding="UTF-8"?>
<project name="javadoc.$modName" default="javadoc.module.$modName">
    <property name="$modName.javadoc.dir" value="${module.$modName.basedir}/../out/javadoc/$modName"/>
    <property name="$modName.javadoc.tmp" value="${$modName.javadoc.dir}/tmp"/>
    <property name="$modName.javadoc.jar" value="${$modName.javadoc.dir}/$modName-javadoc.jar"/>

    <target name="javadoc.module.$modName">
        <javadoc sourcepathref="$modName.module.test.sourcepath" destdir="${$modName.javadoc.tmp}" classpathref="$modName.module.classpath"/>
        <jar destfile="${$modName.javadoc.jar}" duplicate="preserve" filesetmanifest="skip">
            <zipfileset dir="${$modName.javadoc.tmp}"/>
        </jar>
        <delete dir="${$modName.javadoc.tmp}"/>
    </target>
</project>
EOF
    if [[ -f build.xml ]]; then
        cat "build.xml" \
            | sed 's|<import file="${basedir}/$modDir/javadoc.xml"/>||' \
            | sed 's|</project>|<import file="${basedir}/$modDir/javadoc.xml"/>&|' \
            | compareAndOverwrite "build.xml"
    fi
}
intellijDependenciesGaves() {
    local libxml
    for libxml in .idea/libraries/*.xml; do
      xmlstarlet sel -t -v component/library/@name <"$libxml" | sed 's/^Maven: *//'
      echo
    done | sort -u
}
intellijModules() {
    local modules=".idea/modules.xml"
    if [[ ! -f "$modules" ]]; then
        echo "::error::intellij modules.xml file not found"
        exit 45
    fi
    xmlstarlet sel -t -v project/component/modules/module/@filepath -n <x.xml |sed 's/\$[^$]*\$//g;s|^/||;s|\.iml$||'
}
