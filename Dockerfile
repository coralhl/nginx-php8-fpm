FROM node:20.3.1-alpine3.18 AS nodejs

FROM coralhl/nginx-php8-fpm:php8.2.7_withoutNodejs

LABEL org.opencontainers.image.authors="coral (coralhl@gmail.com)"
LABEL org.opencontainers.image.url="https://www.github.com/coralhl/nginx-php8-fpm"

USER root

WORKDIR /var/www/html

COPY --from=nodejs /opt /opt
COPY --from=nodejs /usr/local /usr/local

COPY start.sh /start.sh

EXPOSE 443 80

CMD ["/start.sh"]
