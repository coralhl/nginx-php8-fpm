#!/bin/bash

docker build \
    -f Dockerfile.node \
    -t coralhl/nginx-php8-fpm-node:php8.2.16 \
    -t coralhl/nginx-php8-fpm-node:latest .
