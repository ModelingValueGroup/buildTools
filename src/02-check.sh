#!/usr/bin/env bash
set -euo pipefail

if [[ "${GITHUB_REPOSITORY:-}" == "" ]]; then
  echo "::error:: variable GITHUB_REPOSITORY undefined"
  exit 67
fi

