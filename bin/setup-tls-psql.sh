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

mkdir -p $HOME/.postgresql
ln -vfs $(readlink -f ${KEYDIR}/${CN}.key) $HOME/.postgresql/postgresql.key
ln -vfs $(readlink -f ${CERTDIR}/${CN}.crt) $HOME/.postgresql/postgresql.crt
ln -vfs $(readlink -f ${CACERTDIR}/${ROOTCN}.crt) $HOME/.postgresql/root.crt
