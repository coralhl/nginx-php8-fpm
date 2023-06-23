#!/bin/bash

docker build \
    -f Dockerfile.node \
    -t ghcr.io/coralhl/nginx-php8-fpm-node:php8.2.7 \
    -t ghcr.io/coralhl/nginx-php8-fpm-node:latest .
