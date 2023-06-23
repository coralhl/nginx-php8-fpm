#!/bin/bash

docker build \
    -f Dockerfile.withoutNodejs \
    -t ghcr.io/coralhl/nginx-php8-fpm:php8.2.7_withoutNodejs .
