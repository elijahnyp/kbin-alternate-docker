#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
KBIN_VERSION=$(cd $SCRIPT_DIR/kbin-core; git rev-parse --short HEAD; cd ..)

sed -i "s/\(ghcr\.io\/elijahnyp\/kbin-alternate-docker:\)[^ ]\{8\}/\1$KBIN_VERSION/" build.sh
sed -i "s/\(ghcr\.io\/elijahnyp\/kbin-alternate-docker:\)[^ ]\{8\}/\1$KBIN_VERSION/" build_prod.sh
sed -i "s/^\(appVersion: \).*$/\1\"$KBIN_VERSION\"/" Chart/kbin/Chart.yaml
