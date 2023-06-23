#!/bin/bash

docker build \
    -f Dockerfile \
    -t ghcr.io/coralhl/nginx-php8-fpm:php8.2.7 \
    -t ghcr.io/coralhl/nginx-php8-fpm:latest .
