#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

(
set -o errexit
set -o nounset
set -o pipefail

export HELM_TARGET_REPO=https://nexus.ecp.eastbanctech.com/repository/testraw
export HELM_TARGET_REPO_USER=admin
#export HELM_TARGET_REPO_PASSWORD=admin123

cd target
MERGE_OPTS=""
if curl --progress-bar -O -f $HELM_TARGET_REPO/index.yaml; then
  MERGE_OPTS="--merge ./index.yaml"
fi

helm repo index charts/ --url "$HELM_TARGET_REPO" $MERGE_OPTS
cd charts
for X in *.{yaml,tgz}; do
  echo Uploading $X
  curl --progress-bar --user "$HELM_TARGET_REPO_USER:$HELM_TARGET_REPO_PASSWORD" --upload-file ./$X $HELM_TARGET_REPO/$X
done
)