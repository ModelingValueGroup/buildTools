#!/usr/bin/env bash
set -euo pipefail

###############################################################################
export         GITHUB_BASEURL="https://github.com"
export GITHUB_PACKAGE_BASEURL="https://maven.pkg.github.com"
export     GITHUB_API_BASEURL="https://api.github.com"
###############################################################################
if [[ "${GITHUB_REPOSITORY:-}" == "" ]]; then
  # not on github actions, probably a localbuild
  export           USERNAME="$(git remote -v | head -1 | sed "s|.*$GITHUB_BASEURL/||;s|.*:||;s|\.git .*||;s/ .*//" | sed 's|\([^/]*\)/\(.*\)|\1|')"
  export          REPOSNAME="$(git remote -v | head -1 | sed "s|.*$GITHUB_BASEURL/||;s|.*:||;s|\.git .*||;s/ .*//" | sed 's|\([^/]*\)/\(.*\)|\2|')"
  export  GITHUB_REPOSITORY="$USERNAME/$REPOSNAME"
else
  # on github actions
  export           USERNAME="${GITHUB_REPOSITORY/\/*}"
  export          REPOSNAME="${GITHUB_REPOSITORY/*\/}"
fi
###############################################################################
export     GITHUB_PACKAGE_URL="$GITHUB_PACKAGE_BASEURL/$GITHUB_REPOSITORY"
export          GIHUB_API_URL="$GITHUB_API_BASEURL/repos/$USERNAME/$REPOSNAME"
export           ARTIFACT_DIR="out/artifacts" # default for IntelliJ
export             OUR_DOMAIN="you.need.to.set.OUR_DOMAIN"
export            OUR_PRODUCT="youNeedToSet_OUR_PRODUCT"
###############################################################################
