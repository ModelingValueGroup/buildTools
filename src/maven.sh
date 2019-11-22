#!/usr/bin/env bash

######################################################
### bash functions to access maven repositories
### see: https://repository.sonatype.org/nexus-restlet1x-plugin/default/docs/rest.html
######################################################

declare -A mavenBases=(
     [maven]="https://repo.maven.apache.org/maven2"
  [sonatype]="https://repository.sonatype.org"
    [github]="https://maven.pkg.github.com/$GITHUB_REPOSITORY"
)

         NEXUS_BASE="${mavenBases[maven]}"
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
selectBase() {
  local name="$1"; shift

  NEXUS_BASE="${mavenBases[$name]}"
}
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

  curl -s -L "$NEXUS_BASE/$REST_PATH/$rest?r=$r&$(gave2Url "$gave")" -o "$out"
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
