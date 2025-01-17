#!/bin/bash

docker build \
    -f Dockerfile \
    -t coralhl/nginx-php8-fpm:php8.2.16 \
    -t coralhl/nginx-php8-fpm:latest \
    -t ghcr.io/coralhl/nginx-php8-fpm:php8.2.16 \
    -t ghcr.io/coralhl/nginx-php8-fpm:latest .
