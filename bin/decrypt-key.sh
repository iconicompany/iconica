#!/usr/bin/env bash
set -e
if [ "$1" == ""  ] ; then
    echo "ERROR: No cn given"
    echo "USAGE: $0 <cn> <ca>"
    exit 1
fi

BASE=$(dirname $(readlink -f $(dirname $0)))
. ${BASE}/settings

cd ${BASE}
CN=$1

openssl ec -in private/${CN}.key -out private/${CN}.dec.key
mv -v private/${CN}.dec.key private/${CN}.key
