#!/bin/bash

######################################################
### bash functions to access maven repositories
### see: https://repository.sonatype.org/nexus-restlet1x-plugin/default/docs/rest.html
######################################################

mavenBases=(
  "https://repository.sonatype.org"
  "https://repo.maven.apache.org/maven2"
  "https://repo1.maven.org/maven2"
  "https://maven.pkg.github.com/OWNER/REPOSITORY"
)

         NEXUS_BASE="${mavenBases[0]}"
          REST_PATH="service/local"
     VERSION_LATEST="LATEST"
    VERSION_RELEASE="RELEASE"
     REPOS_RELEASES="releases"
    REPOS_SNAPSHOTS="snapshots"

        R_ALL_REPOS="all_repositories"
R_ARTIFACT_REDIRECT="artifact/maven/redirect"
 R_ARTIFACT_CONTENT="artifact/maven/content"
 R_ARTIFACT_RESOLVE="artifact/maven/resolve"
  R_CONTENT_CLASSES="components/repo_content_classes"
       R_REPO_TYPES="components/repo_types"
      R_REPO_GROUPS="repo_groups"

######################################################
# in browser:
#    basename           gives UI
#    basename/content/  gives simple tree browser
######################################################
gave2Url() {
  local gave="$1"; shift

  local g a v e; IFS=: read g a v e <<<"$gave"
  printf "g=%s&a=%s&v=%s&e=%s" "$g" "$a" "$v" "$e"
}
gave2File() {
  local gave="$1"; shift

  local g a v e; IFS=: read g a v e <<<"$gave"
  printf "%s.%s" "$a" "$e"
}
callRestTo() {
  local rest="$1"; shift
  local gave="$1"; shift
  local    r="$1"; shift
  local  out="$1"; shift

set -x
  curl -L "$NEXUS_BASE/$REST_PATH/$rest?r=$r&$(gave2Url "$gave")" -o "$out"
set +x
echo
}
callRestToStdout() {
  local rest="$1"; shift
  local gave="$1"; shift
  local    r="$1"; shift

  callRestTo "$rest" "$gave" "$r" "-"
}
callRestToDir() {
  local rest="$1"; shift
  local gave="$1"; shift
  local    r="$1"; shift
  local  dir="$1"; shift

  callRestTo "$rest" "$gave" "$r" "$dir/$(gave2File "$gave")"
}
######################################################
nexusArtifactRedirect() {
  local gave="$1"; shift
  local    r="$1"; shift
  local  dir="$1"; shift

  callRestToDir "$R_ARTIFACT_REDIRECT" "$gave" "$r" "$dir"
}
nexusArtifactContent() {
  local gave="$1"; shift
  local    r="$1"; shift
  local  dir="$1"; shift

  callRestToDir "$R_ARTIFACT_CONTENT" "$gave" "$r" "$dir"
}
nexusArtifactResolve() {
  local gave="$1"; shift
  local    r="$1"; shift
  local  dir="$1"; shift

  callRestToStdout "$R_ARTIFACT_RESOLVE" "$gave" "$r"
}
nexusContentClasses() {
  callRestToStdout "$R_CONTENT_CLASSES"
}
nexusRepoTypes() {
  callRestToStdout "$R_REPO_TYPES"
}
nexusRepoGroups() {
  callRestToStdout "$R_REPO_GROUPS"
}
######################################################

if false; then
  #curl "$NEXUS_BASE/$REST_PATH/repositories/$r/content/${g//.//}/$a/maven-metadata.xml" -o -

  ###############################################
  rm -rf /tmp/tmp*
  mkdir /tmp/tmp1 /tmp/tmp2 /tmp/tmp3
  nexusArtifactRedirect "org.sonatype.nexus:nexus-utils:LATEST:jar" snapshots /tmp/tmp1
  nexusArtifactContent  "org.sonatype.nexus:nexus-utils:LATEST:jar" snapshots /tmp/tmp2
  nexusArtifactResolve  "org.sonatype.nexus:nexus-utils:LATEST:jar" snapshots
  file /tmp/tmp*/*
  ###############################################


  https://repository.sonatype.org/service/local/components/schedule_types
  https://maven.pkg.github.com/service/local

  dummy-org-gsd-days    spring-boot-example    0.0.8
  https://maven.pkg.github.com/dummy-org-gsd-days/spring-boot-example/service/local/artifact/maven/redirect?r=snapshots&g=org.sonatype.nexus&a=nexus-utils&v=LATEST&e=jar
  https://maven.pkg.github.com/dummy-org-gsd-days/spring-boot-example/service/local/artifact/maven/redirect?r=snapshots&g=dummy-org-gsd-days&a=spring-boot-example&v=LATEST
fi