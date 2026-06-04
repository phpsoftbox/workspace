# syntax=docker/dockerfile:1.6

ARG PHP_FPM_IMAGE=php:8.5-fpm

FROM ${PHP_FPM_IMAGE} AS base

ARG NODE_MAJOR=22
ARG XDEBUG_VERSION=3.5.0
ARG USER_NAME=dev
ARG USER_ID=1000
ARG GROUP_ID=1000

ENV TZ=Europe/Moscow \
    COMPOSER_ALLOW_SUPERUSER=1

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ${PHPIZE_DEPS} \
        bash-completion \
        ca-certificates \
        curl \
        default-mysql-client \
        git \
        libfreetype6-dev \
        libicu-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libpq-dev \
        libsqlite3-dev \
        libssl-dev \
        libzip-dev \
        locales \
        openssh-client \
        postgresql-client \
        unzip \
        zlib1g-dev; \
    sed -i 's/^# *\(ru_RU.UTF-8 UTF-8\)/\1/' /etc/locale.gen; \
    locale-gen ru_RU.UTF-8; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-configure intl; \
    docker-php-ext-configure pcntl --enable-pcntl; \
    docker-php-ext-install -j"$(nproc)" \
        bcmath \
        gd \
        intl \
        pcntl \
        pdo_mysql \
        pdo_pgsql \
        pdo_sqlite \
        zip; \
    rm -rf /var/lib/apt/lists/*

ENV LANG=ru_RU.UTF-8 \
    LANGUAGE=ru_RU:ru \
    LC_ALL=ru_RU.UTF-8

COPY --from=ghcr.io/php/pie:1.4.5-bin /pie /usr/local/bin/pie

RUN set -eux; \
    pie install --no-cache "xdebug/xdebug:${XDEBUG_VERSION}"

RUN set -eux; \
    curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash -; \
    apt-get update; \
    apt-get install -y --no-install-recommends nodejs; \
    npm i -g yarn@1.22.22; \
    rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer
COPY docker/php/conf.d /usr/local/etc/php/conf.d
COPY docker/php/bash_completion.d /etc/bash_completion.d

RUN set -eux; \
    if ! getent group "${GROUP_ID}" >/dev/null; then \
        groupadd -g "${GROUP_ID}" "${USER_NAME}"; \
    fi; \
    group_name="$(getent group "${GROUP_ID}" | cut -d: -f1)"; \
    useradd -l -u "${USER_ID}" -g "${GROUP_ID}" -d "/home/${USER_NAME}" -m "${USER_NAME}"; \
    mkdir -p "/home/${USER_NAME}/.cache/composer" "/home/${USER_NAME}/.cache/yarn"; \
    chown -R "${USER_NAME}:${group_name}" "/home/${USER_NAME}"; \
    { \
        echo ''; \
        echo 'if [ -f /etc/bash_completion ]; then'; \
        echo '    . /etc/bash_completion'; \
        echo 'fi'; \
        echo 'if [ -f /etc/bash_completion.d/psb ]; then'; \
        echo '    . /etc/bash_completion.d/psb'; \
        echo 'fi'; \
    } >> "/home/${USER_NAME}/.bashrc"; \
    sed -ri "s/^user = .*/user = ${USER_NAME}/" /usr/local/etc/php-fpm.d/www.conf; \
    sed -ri "s/^group = .*/group = ${group_name}/" /usr/local/etc/php-fpm.d/www.conf; \
    sed -ri "s/^;?clear_env = .*/clear_env = no/" /usr/local/etc/php-fpm.d/www.conf

WORKDIR /app

FROM base AS fpm

EXPOSE 9000 5173
CMD ["php-fpm"]

FROM base AS cli

USER ${USER_NAME}
EXPOSE 5173
CMD ["bash"]
