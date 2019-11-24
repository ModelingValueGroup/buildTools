#!/usr/bin/env bash
set -ue

if [[ "${GITHUB_REPOSITORY:-}" == "" ]]; then
  echo "::error:: variable GITHUB_REPOSITORY undefined"
  exit 67
fi

