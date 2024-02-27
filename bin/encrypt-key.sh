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

openssl ec -aes256 -in private/${CN}.key -out private/${CN}.enc.key
mv -v private/${CN}.enc.key private/${CN}.key
