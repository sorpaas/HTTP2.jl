#! /usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HOSTNAME=$1

openssl req \
    -new \
    -newkey rsa:4096 \
    -days 3650 \
    -nodes \
    -x509 \
    -subj "/C=IN/ST=Karnataka/L=Bangalore/O=Julia/CN=$HOSTNAME" \
    -keyout ${DIR}/$HOSTNAME.key \
    -out ${DIR}/$HOSTNAME.cert
