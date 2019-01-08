#! /usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

openssl req \
    -new \
    -newkey rsa:4096 \
    -days 3650 \
    -nodes \
    -x509 \
    -subj "/C=IN/ST=Karnataka/L=Bangalore/O=Julia/CN=www.example.com" \
    -keyout ${DIR}/www.example.com.key \
    -out ${DIR}/www.example.com.cert
