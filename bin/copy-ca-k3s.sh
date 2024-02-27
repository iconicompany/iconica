#!/usr/bin/env bash

BASE=$(dirname $(readlink -f $(dirname $0)))
sudo mkdir -p /var/lib/rancher/k3s/server/tls
sudo cp -vr $BASE/certs/k3s/server/tls/* /var/lib/rancher/k3s/server/tls
