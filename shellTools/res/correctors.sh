#!/usr/bin/env bash
set -euo pipefail

correctEols() {
  java -cp buildTools.jar correctors.EolCorrector
}
correctHeaders() {
  local headerTemplate="$1"; shift

  java -cp buildTools.jar correctors.HeaderCorrector "$headerTemplate"
}