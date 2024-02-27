set -e
cd /var/lib/rancher/k3s/server/tls
openssl verify -CAfile client-ca.crt `ls client*crt | grep -v client-auth-proxy.crt`
openssl verify -CAfile request-header-ca.crt client-auth-proxy.crt
openssl verify -CAfile server-ca.crt serving*.crt
openssl verify -CAfile etcd/server-ca.crt etcd/client.crt etcd/server-client.crt
openssl verify -CAfile etcd/peer-ca.crt etcd/peer-server-client.crt
