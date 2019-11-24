#!/usr/bin/env bash
set -euo pipefail

genFileSets() {
    ls -d out/test/* \
        | while read d; do
            echo "<fileset dir=\"$d\"><include name=\"**/*Test.*\"/><include name=\"**/*Tests.*\"/></fileset>"
        done
}
generateAntTestFile() {
    local name="$1"; shift

    cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project name="$name" default="all">

    <path id="cp">
        <path>
            <pathelement location="\${path.variable.maven_repository}/junit/junit/4.12/junit-4.12.jar"/>
            <pathelement location="\${path.variable.maven_repository}/org/hamcrest/hamcrest-core/1.3/hamcrest-core-1.3.jar"/>
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
$(genFileSets)
                <formatter type="xml"/>
            </batchtest>
        </junit>
    </target>
</project>
EOF
}
