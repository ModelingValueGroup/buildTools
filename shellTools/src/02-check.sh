#!/usr/bin/env bash
set -euo pipefail

if [[ "${GITHUB_REPOSITORY:-}" == "" ]]; then
  echo "::error:: variable GITHUB_REPOSITORY undefined"
  exit 67
fi
if ! command -v mvn &>/dev/null; then
  echo "::error:: mvn not installed"
  exit 68
fi
if ! command -v xmlstarlet &>/dev/null; then
  echo "::error:: xmlstarlet not installed"
  exit 69
fi
