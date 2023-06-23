#!/bin/bash

docker build \
    -t ghcr.io/coralhl/nginx-php8-fpm:php8.2.7_node20.3.1 \
    -t ghcr.io/coralhl/nginx-php8-fpm:latest .
