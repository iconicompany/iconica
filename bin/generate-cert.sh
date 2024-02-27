#!/bin/bash

set -e
BASE=$(dirname $(readlink -f $(dirname $0)))
. ${BASE}/settings

if [ "$1" == ""  ] ; then
    echo "ERROR: No cn given"
    echo "USAGE: $0 <cn> <ca>"
    exit 1
fi

CN=$1
if [ "$2" != "" ] ; then
    INTERMEDIATECN=$2
fi

CONFIGPATH="./"
cd "${BASE}"

echo "Generate certificate and key for ${CN}:"

tempDir=$(mktemp -d)
configFile=$tempDir/req.cnf
SUBJALTNAME=""
if [[ ${CN} == *@* ]]; then
    SUBJALTNAME="email:${CN}"
elif [[ ${CN} == *.* ]]; then
    SUBJALTNAME="DNS:${CN}"
else
    SUBJALTNAME="email:${CN}@${DOMAIN}"
fi

cat > $configFile << EOF
[v3_req]
keyUsage = digitalSignature, nonRepudiation, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth, emailProtection, codeSigning
subjectAltName = ${SUBJALTNAME}
authorityInfoAccess = caIssuers;URI:http://ca.iconicompany.com/certs/${INTERMEDIATECN}.der
crlDistributionPoints = URI:http://ca.iconicompany.com/certs/${INTERMEDIATECN}.crl
EOF

openssl ecparam -name prime256v1 -genkey -noout -out "${KEYDIR}/${CN}.key"
chmod 0600 ${KEYDIR}/${CN}.key

echo "Using config $configFile"
openssl req -new -key "${KEYDIR}/${CN}.key" -out "${CERTDIR}/${CN}.csr" \
    -subj "/C=ru/O=${O}/OU=${OU}/CN=${CN}" \
    -config $CONFIGPATH/config
openssl x509 -req -sha512 -days $DAYSCERT -in "${CERTDIR}/${CN}.csr" \
     -extfile $configFile -extensions 'v3_req' \
     -CA ${CACERTDIR}/${INTERMEDIATECN}.crt -CAkey ${KEYDIR}/${INTERMEDIATECN}.key -CAcreateserial \
     -out ${CERTDIR}/${CN}.pem
cat ${CERTDIR}/${CN}.pem ${CACERTDIR}/${INTERMEDIATECN}.crt > ${CERTDIR}/${CN}.crt
rm -f $configFile "${CERTDIR}/${CN}.csr"

bin/verify-cert.sh $1 $2
