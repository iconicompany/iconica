#!/usr/bin/env bash
set -e
BASE=$(dirname $(readlink -f $(dirname $0)))
. ${BASE}/settings


mkdir -p ${BASE}/certs/k3s/server/tls
cp  -v ${BASE}/certs/${ROOTCN}.pem ${BASE}/certs/k3s/server/tls/root-ca.pem
cp  -v ${BASE}/certs/kube-ca.pem ${BASE}/certs/k3s/server/tls/intermediate-ca.pem
cp  -v ${BASE}/private/kube-ca.key ${BASE}/certs/k3s/server/tls/intermediate-ca.key
curl -sL https://github.com/k3s-io/k3s/raw/master/contrib/util/generate-custom-ca-certs.sh \
    | sed -e 's/3700/370/' \
        -e '/\[v3_ca\]/a authorityInfoAccess = caIssuers;URI:http://ca.iconicompany.com/certs/kube-ca.der' \
        -e '/\[v3_ca\]/a crlDistributionPoints = URI:http://ca.iconicompany.com/certs/kube-ca.crl' \
    | tee /tmp/test \
    |  DATA_DIR=${BASE}/certs/k3s bash -

rm -fv ${BASE}/certs/k3s/server/tls/root-ca.*
rm -fv ${BASE}/certs/k3s/server/tls/intermediate-ca.*
