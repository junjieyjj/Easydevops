#!/bin/bash

SCRIPT_BASEDIR=$(dirname "$0")

cd ${SCRIPT_BASEDIR}
SCRIPT_BASEDIR="$PWD"

#source lib/utils/utils.sh
source lib/utils/test.sh

test_green
