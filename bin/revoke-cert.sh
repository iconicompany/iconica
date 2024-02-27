#ROOTCN=iconicompany-ca INTERMEDIATECN=kube-ca  openssl ca -config ../config/config -keyfile  ./kube-ca.key -cert ./kube-ca.pem -revoke ./k3s/server/tls/server-ca.pem 
