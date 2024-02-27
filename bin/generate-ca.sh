#!/usr/bin/env bash

BASE=$(dirname $(readlink -f $(dirname $0)))
. ${BASE}/settings

# Example K3s CA certificate generation script.
# 
# This script will generate files sufficient to bootstrap K3s cluster certificate
# authorities.  By default, the script will create the required files under
# /var/lib/rancher/k3s/server/tls, where they will be found and used by K3s during initial
# cluster startup. Note that these files MUST be present before K3s is started the first
# time; certificate data SHOULD NOT be changed once the cluster has been initialized.
#
# The output path may be overridden with the DATA_DIR environment variable.
# 
# This script will also auto-generate certificates and keys for both root and intermediate
# certificate authorities if none are found.
# If you have existing certs, you must place then in `DATA_DIR`.
# If you have only an existing root CA, provide:
#   root-ca.pem
#   root-ca.key
# If you have an existing root and intermediate CA, provide:
#   root-ca.pem
#   intermediate-ca.pem
#   intermediate-ca.key

set -e
umask 027

#TIMESTAMP=$(date +%s)
TIMESTAMPY=$(date +%Y)
TIMESTAMPYM=$(date +%Y%m)
#LEAFTYPE=${LEAFTYPE:-kube/service.key kube/client-ca kube/server-ca kube/request-header-ca kube/etcd/peer-ca kube/etcd/server-ca}
LEAFTYPE=""
DATA_DIR=$CERTDIR
SKIP_INT=0
if [ "$1" != "" ] ; then
    ROOTCN=$1
fi
if [ "$2" != "" ] ; then
    INTERMEDIATECN=$2
fi

if type -t openssl-3 &>/dev/null; then
  OPENSSL=openssl-3
else
  OPENSSL=openssl
fi

echo "Using $(type -p ${OPENSSL}): $(${OPENSSL} version)"

if ! ${OPENSSL} ecparam -name prime256v1 -genkey -noout -out /dev/null &>/dev/null; then
  echo "openssl not found or missing Elliptic Curve (ecparam) support."
  exit 1
fi

${OPENSSL} version | grep -qF 'OpenSSL 3' && OPENSSL_GENRSA_FLAGS=-traditional

mkdir -p "${BASE}/certs"
mkdir -p "${BASE}/private"
chmod 0700 "${BASE}/private"
mkdir -p "${BASE}/db/certs"
touch "${BASE}/db/index"

cd "${BASE}"

CONFIGPATH="./"
#EXTFILE=$CONFIGPATH/extensions

# Use existing root CA if present
if [[ -e certs/${ROOTCN}.pem ]]; then
  echo "Using existing root certificate"
else
  echo "Generating root certificate authority key and certificate"
  #${OPENSSL} genrsa ${OPENSSL_GENRSA_FLAGS:-} -out private/${ROOTCN}.key -passout file:secrets/password-${ROOTCN} 4096
  ${OPENSSL} ecparam -name secp384r1 -genkey |  openssl ec -aes256  -out private/${ROOTCN}.key -passout file:secrets/password-${ROOTCN}
  echo "Generating root certificate authority certificate"
  ${OPENSSL} req -x509 -new -nodes -sha384 -days $DAYSROOT \
                 -passin file:secrets/password-${ROOTCN} \
                 -subj "/C=${C}/O=${O}/CN=${ROOTCN}" \
                 -key private/${ROOTCN}.key \
                 -out certs/${ROOTCN}.pem \
                 -config $CONFIGPATH/config \
                 -extensions ${ROOTCN}
  echo "Generating root certificate der form"
  ${OPENSSL} x509 -outform der -in certs/${ROOTCN}.pem -out certs/${ROOTCN}.der
  echo "Generating root certificate crl"
  ${OPENSSL} ca -gencrl \
                 -passin file:secrets/password-${ROOTCN} \
                 -keyfile private/${ROOTCN}.key \
                 -cert certs/${ROOTCN}.pem \
                 -config $CONFIGPATH/config |
  ${OPENSSL} crl -outform der -out certs/${ROOTCN}.crl
  cat certs/${ROOTCN}.pem > certs/${ROOTCN}.crt
  chmod a-w certs/${ROOTCN}.* private/${ROOTCN}.*
fi

# Use existing intermediate CA if present

if [[ -e certs/${INTERMEDIATECN}.pem ]]; then
  echo "Using existing intermediate certificate"
else
  if [[ ! -e private/${ROOTCN}.key ]]; then
    echo "Cannot generate intermediate certificate without root certificate private key"
    exit 1
  fi

  echo "Generating intermediate certificate authority key"
  #${OPENSSL} genrsa ${OPENSSL_GENRSA_FLAGS:-} -out private/${INTERMEDIATECN}.key -pass file:secrets/password-${INTERMEDIATECN} 4096
  ${OPENSSL} ecparam -name secp384r1 -genkey |  openssl ec -aes256  -out private/${INTERMEDIATECN}.key -passout file:secrets/password-${INTERMEDIATECN}
  echo "Generating intermediate certificate authority certificate"
  ${OPENSSL} req -new -nodes \
                 -passin file:secrets/password-${INTERMEDIATECN} \
                 -subj "/C=${C}/O=${O}/CN=${INTERMEDIATECN}" \
                 -config $CONFIGPATH/config \
                 -key private/${INTERMEDIATECN}.key |
  ${OPENSSL} ca  -batch -notext -md sha384 -days $DAYSINT \
                 -passin file:secrets/password-${ROOTCN} \
                 -in /dev/stdin \
                 -out certs/${INTERMEDIATECN}.pem \
                 -keyfile private/${ROOTCN}.key \
                 -cert certs/${ROOTCN}.pem \
                 -config $CONFIGPATH/config \
                 -rand_serial \
                 -extensions ${INTERMEDIATECN}
  ${OPENSSL} x509 -outform der -in certs/${INTERMEDIATECN}.pem -out certs/${INTERMEDIATECN}.der
  ${OPENSSL} ca -gencrl \
                 -passin file:secrets/password-${INTERMEDIATECN} \
                 -keyfile private/${INTERMEDIATECN}.key \
                 -cert certs/${INTERMEDIATECN}.pem \
                 -config $CONFIGPATH/config |
  ${OPENSSL} crl -outform der -out certs/${INTERMEDIATECN}.crl
  cat certs/${INTERMEDIATECN}.pem certs/${ROOTCN}.pem > certs/${INTERMEDIATECN}.crt
  chmod a-w certs/${INTERMEDIATECN}.* private/${INTERMEDIATECN}.*
fi

if [[ ! -e private/${INTERMEDIATECN}.key ]]; then
  echo "Cannot generate leaf certificates without intermediate certificate private key"
  exit 1
fi

# Generate new leaf CAs for all the control-plane and etcd components
for TYPE in $LEAFTYPE; do
  FULL_CERT_NAME="$(echo ${TYPE} | tr / -)"
  CERT_NAME="$(echo ${TYPE} | cut -d / -f2- | tr / -)"
  OU="$(echo ${TYPE} | cut -d / -f1)"
  SUBJ="/C=${C}/O=${O}/OU=${OU}/CN=${CERT_NAME}-${TIMESTAMPY}"
  mkdir -p certs/$(dirname $TYPE)
  mkdir -p private/$(dirname $TYPE)
  if [[ "${TYPE#*.}" = "key" ]]; then
    # Don't overwrite the service account issuer key; we pass the key into both the controller-manager
    # and the apiserver instead of passing a cert list into the apiserver, so there's no facility for
    # rotation and things will get very angry if all the SA keys are invalidated.
    if [[ -e $TYPE ]]; then
      echo "Generating additional Kubernetes service account issuer RSA key"
      OLD_SERVICE_KEY="$(cat $TYPE)"
    else
      echo "Generating Kubernetes service account issuer RSA key"
    fi
    ${OPENSSL} genrsa ${OPENSSL_GENRSA_FLAGS:-} -out certs/$TYPE 2048
    echo "${OLD_SERVICE_KEY}" >> $TYPE
  else
    EXTNAME=${OU}-ca
    if grep -Fxq "[${FULL_CERT_NAME}]" $CONFIGPATH/config
    then
        EXTNAME=${FULL_CERT_NAME}
    fi
    echo "Generating ${SUBJ} leaf certificate authority EC key and certificate. EXTNAME = ${EXTNAME}"
    ${OPENSSL} ecparam -name prime256v1 -genkey -noout -out private/${TYPE}.key
    ${OPENSSL} req -new -nodes \
                 -subj ${SUBJ} \
                 -config $CONFIGPATH/config \
                 -key private/${TYPE}.key |
    ${OPENSSL} ca  -batch -notext  -days $DAYSLEAF \
                 -in /dev/stdin \
                 -out certs/${TYPE}.pem \
                 -keyfile private/${INTERMEDIATECN}.key \
                 -cert certs/${INTERMEDIATECN}.pem \
                 -rand_serial \
                 -config $CONFIGPATH/config \
                 -extensions ${EXTNAME}
    cat certs/${TYPE}.pem \
        certs/${INTERMEDIATECN}.pem certs/${ROOTCN}.pem > certs/${TYPE}.crt
  fi
done

