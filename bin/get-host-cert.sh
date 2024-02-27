set -e

if [ "$1" == ""  ] ; then
    echo "ERROR: No host given"
    echo "USAGE: $0 <host> <port>"
    exit 1
fi

HOST=$1
PORT=${2:-443}

openssl s_client -connect $HOST:$PORT > $HOST.pem
