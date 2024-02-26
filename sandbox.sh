#!/usr/bin/env bash
#

[[ ${0%/*} == ${0} ]] && dir='.' || dir=${0%/*}
echo "$dir"
echo $(dirname $0)
