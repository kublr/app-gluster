#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

(
set -o errexit
set -o nounset
set -o pipefail

rm -rf target
mkdir -p target/charts
cd target/charts
helm package ../../app-gluster
)
