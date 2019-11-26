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
<project name="test" default="all">

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

    <target name="all">
        <junit haltonfailure="on" logfailedtests="on" fork="on" forkmode="once"><!-- fork="on" forkmode="perTest" threads="8" -->
            <classpath refid="cp"/>
            <batchtest todir=".">
$(genTestFileSets)
                <formatter type="xml"/>
            </batchtest>
        </junit>
    </target>
</project>
EOF
}
intellijDependenciesGaves() {
    local libxml
    for libxml in .idea/libraries/*.xml; do
      xmlstarlet sel -t -v component/library/@name <"$libxml" | sed 's/^Maven: *//'
      echo
    done | sort -u
}
