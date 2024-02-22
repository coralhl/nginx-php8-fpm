FROM php:8.2.16-fpm-alpine3.19

LABEL org.opencontainers.image.authors="coral (coralhl@gmail.com)"
LABEL org.opencontainers.image.url="https://www.github.com/coralhl/nginx-php8-fpm"
LABEL org.opencontainers.image.source="https://www.github.com/coralhl/nginx-php8-fpm"

USER root

WORKDIR /var/www/html

ENV TZ=Europe/Moscow
#ENV LANG ru_RU.UTF-8
#ENV LANGUAGE ru_RU.UTF-8
#ENV LC_ALL ru_RU.UTF-8
ENV NGINX_VERSION 1.25.3
ENV PKG_RELEASE   1

RUN set -x \
    && apk update \
    && apkArch="$(cat /etc/apk/arch)" \
    && nginxPackages=" \
        nginx=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-xslt=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-geoip=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-image-filter=${NGINX_VERSION}-r${PKG_RELEASE} \
    " \
    && case "$apkArch" in \
        x86_64|aarch64) \
# arches officially built by upstream
            set -x \
            && KEY_SHA512="de7031fdac1354096d3388d6f711a508328ce66c168967ee0658c294226d6e7a161ce7f2628d577d56f8b63ff6892cc576af6f7ef2a6aa2e17c62ff7b6bf0d98 *stdin" \
            && apk add --no-cache --virtual .cert-deps \
                openssl \
            && wget -O /tmp/nginx_signing.rsa.pub https://nginx.org/keys/nginx_signing.rsa.pub \
            && if [ "$(openssl rsa -pubin -in /tmp/nginx_signing.rsa.pub -text -noout | openssl sha512 -r)" = "$KEY_SHA512" ]; then \
                echo "key verification succeeded!"; \
                mv /tmp/nginx_signing.rsa.pub /etc/apk/keys/; \
            else \
                echo "key verification failed!"; \
                exit 1; \
            fi \
            && apk del .cert-deps \
            && apk add -X "https://nginx.org/packages/mainline/alpine/v$(egrep -o '^[0-9]+\.[0-9]+' /etc/alpine-release)/main" --no-cache $nginxPackages \
            ;; \
        *) \
# we're on an architecture upstream doesn't officially build for
# let's build binaries from the published packaging sources
            set -x \
            && tempDir="$(mktemp -d)" \
            && chown nobody:nobody $tempDir \
            && apk add --no-cache --virtual .build-deps \
                alpine-sdk \
                bash \
                findutils \
                gcc \
                gd-dev \
                geoip-dev \
                libc-dev \
                libedit-dev \
                libxslt-dev \
                linux-headers \
                make \
                mercurial \
                openssl-dev \
                pcre-dev \
                perl-dev \
                zlib-dev \
            && su nobody -s /bin/sh -c " \
                export HOME=${tempDir} \
                && cd ${tempDir} \
                && hg clone https://hg.nginx.org/pkg-oss \
                && cd pkg-oss \
                && hg up ${NGINX_VERSION}-${PKG_RELEASE} \
                && cd alpine \
                && make all \
                && apk index -o ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz ${tempDir}/packages/alpine/${apkArch}/*.apk \
                && abuild-sign -k ${tempDir}/.abuild/abuild-key.rsa ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz \
                " \
            && cp ${tempDir}/.abuild/abuild-key.rsa.pub /etc/apk/keys/ \
            && apk del .build-deps \
            && apk add -X ${tempDir}/packages/alpine/ --no-cache $nginxPackages \
            ;; \
    esac \
# if we have leftovers from building, let's purge them (including extra, unnecessary build deps)
    && if [ -n "$tempDir" ]; then rm -rf "$tempDir"; fi \
    && if [ -n "/etc/apk/keys/abuild-key.rsa.pub" ]; then rm -f /etc/apk/keys/abuild-key.rsa.pub; fi \
    && if [ -n "/etc/apk/keys/nginx_signing.rsa.pub" ]; then rm -f /etc/apk/keys/nginx_signing.rsa.pub; fi \
# Bring in gettext so we can get `envsubst`, then throw
# the rest away. To do this, we need to install `gettext`
# then move `envsubst` out of the way so `gettext` can
# be deleted completely, then move `envsubst` back.
    && apk add --no-cache --virtual .gettext gettext \
    && mv /usr/bin/envsubst /tmp/ \
    \
    && runDeps="$( \
        scanelf --needed --nobanner /tmp/envsubst \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk add --no-cache $runDeps \
    && apk del .gettext \
    && mv /tmp/envsubst /usr/local/bin/ \
# Bring in tzdata so users could set the timezones through the environment
# variables
    && apk add --no-cache tzdata musl musl-utils musl-locales \
# Bring in curl and ca-certificates to make registering on DNS SD easier
    && apk add --no-cache curl ca-certificates

RUN curl http://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer \
    && apk add --no-cache \
        bash \
        bash-completion \
        c-client \
        coreutils \
        git \
        icu \
        icu-libs \
        icu-data-full \
        imagemagick \
        imap \
        libmemcached-libs \
        libcap \
        libpng \
        libstdc++ \
        libzip \
        linux-headers \
        lua-resty-core \
        mysql-client \
        nginx-mod-http-lua \
        postgresql-client \
        postgresql-libs \
        shadow \
        sqlite \
        supervisor \
        unzip \
        zip \
        # bitrix utils
        gifsicle \
        jpegoptim \
        libwebp-tools \
        optipng

ENV PHP_MODULE_DEPS \
        curl-dev \
        cyrus-sasl-dev \
        freetype-dev \
        gcc \
        icu-dev \
        imagemagick-dev \
        imap-dev \
        jpeg-dev \
        libc-dev \
        libjpeg-turbo-dev \
        libmemcached-dev \
        libpng-dev \
        libwebp-dev \
        libxml2-dev \
        libzip-dev \
        make \
        postgresql-dev \
        zlib-dev 

RUN set -xe \
    && apk add --no-cache --update --virtual .phpize-deps $PHPIZE_DEPS \
    && apk add --no-cache --update --virtual .all-deps $PHP_MODULE_DEPS \
    && docker-php-ext-configure \
        gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install \
        bcmath \
        dom \
        exif \
        gd \
        imap \
        intl \
        mysqli \
        opcache \
        pcntl \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        pgsql \
        soap \
        sockets \
        zip \
    && pecl install imagick && docker-php-ext-enable imagick \
    && pecl install igbinary && docker-php-ext-enable igbinary \
    && pecl install memcache && docker-php-ext-enable memcache \
    && pecl install memcached && docker-php-ext-enable memcached \
    && pecl install msgpack && docker-php-ext-enable msgpack \
    && pecl install -o -f redis && docker-php-ext-enable redis \
    && docker-php-ext-enable sockets \
    # && pecl install swoole && docker-php-ext-enable swoole \
    && rm -rf /tmp/pear \
    && apk del .all-deps .phpize-deps \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/* \
    && rm -f /etc/nginx/conf.d/default.conf.apk-new && rm -f /etc/nginx/nginx.conf.apk-new

COPY conf/supervisord.conf /etc/supervisord.conf
COPY conf/php-fpm.conf /etc/supervisor/conf.d/php-fpm.conf
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/default.conf /etc/nginx/conf.d/default.conf
# COPY conf/resolv.conf /etc/resolv.conf
COPY start.sh /start.sh
COPY conf/lsiown /usr/bin/lsiown

ENV fpm_conf /usr/local/etc/php-fpm.d/www.conf
ENV php_vars /usr/local/etc/php/conf.d/docker-vars.ini

RUN echo "cgi.fix_pathinfo=0" > ${php_vars} && \
    echo "upload_max_filesize = 100M"  >> ${php_vars} && \
    echo "post_max_size = 100M"  >> ${php_vars} && \
    echo "variables_order = \"EGPCS\""  >> ${php_vars} && \
    echo "memory_limit = 128M"  >> ${php_vars} && \
    sed -i \
        -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" \
        -e "s/pm.max_children = 5/pm.max_children = 64/g" \
        -e "s/pm.start_servers = 2/pm.start_servers = 8/g" \
        -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 8/g" \
        -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 32/g" \
        -e "s/;pm.max_requests = 500/pm.max_requests = 800/g" \
        -e "s/;listen.owner = www-data/listen.owner = abc/g" \
        -e "s/;listen.group = www-data/listen.group = abc/g" \
        -e "s/user = www-data/user = abc/g" \
        -e "s/group = www-data/group = abc/g" \
        -e "s/;listen.mode = 0660/listen.mode = 0666/g" \
        -e "s/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm.sock/g" \
        -e "s/^;clear_env = no$/clear_env = no/" \
        -e "s/;php_admin_value\[error_log\] = \/var\/log\/fpm-php.www.log/php_admin_value\[error_log\] = \/var\/log\/php\/error.log/g" \
        ${fpm_conf} \
    && cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini \
    # && sed -i 's/session.save_handler = files/session.save_handler = redis\nsession.save_path = "tcp:\/\/redis:6379"/g' /usr/local/etc/php/php.ini \
    && groupmod -g 1000 users \
    && useradd -u 911 -U -d /home/user -s /bin/false abc \
    && usermod -G users abc \
    &&  mkdir -p \
        /home/user \
    && set -ex \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && setcap 'cap_net_bind_service=+ep' /usr/local/bin/php \
    && mkdir -p /var/log/supervisor \
#    # forward request and error logs to docker log collector
#    && ln -sf /dev/stdout /var/log/nginx/access.log \
#    && ln -sf /dev/stderr /var/log/nginx/error.log \
    && chmod +x /start.sh \
    && chmod +x /usr/bin/lsiown

EXPOSE 443 80

HEALTHCHECK CMD wget -q --no-cache --spider localhost

CMD ["/start.sh"]