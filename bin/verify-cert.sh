#!/bin/bash
BASE=$(dirname $(readlink -f $(dirname $0)))
. ${BASE}/settings

cd ${BASE}

if [ "$1" == ""  ] ; then
    echo "ERROR: No cn given"
    echo "USAGE: $0 <cn> <ca>"
    exit 1
fi

cn=$1
if [ "$2" != "" ] ; then
    INTERMEDIATECN=$2
fi

certDir="certs"
keyDir="private"
caCertDir="certs"

openssl x509 -in ${certDir}/$cn.crt -noout -text
openssl verify -CAfile ${caCertDir}/$ROOTCN.crt -untrusted ${caCertDir}/${INTERMEDIATECN}.crt ${certDir}/$cn.pem
