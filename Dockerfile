#syntax=docker/dockerfile:1.4

FROM caddy:2.7-builder-alpine AS app_caddy_builder

RUN xcaddy build v2.6.4 \
	--with github.com/dunglas/mercure/caddy \
	--with github.com/dunglas/vulcain/caddy \
	--with github.com/lindenlab/caddy-s3-proxy \
	--with github.com/sagikazarmark/caddy-fs-s3

FROM php:8.2-fpm-alpine AS app_php

# Allow to use development versions of Symfony
ARG STABILITY="stable"
ENV STABILITY ${STABILITY}

# Allow to select Symfony version
ARG SYMFONY_VERSION=""
ENV SYMFONY_VERSION ${SYMFONY_VERSION}

ENV APP_ENV=prod
ENV SYMFONY_LOGLEVEL="info"

WORKDIR /srv/app

# php extensions installer: https://github.com/mlocati/docker-php-extension-installer
COPY --from=mlocati/php-extension-installer:latest --link /usr/bin/install-php-extensions /usr/local/bin/

# persistent / runtime deps
RUN apk add --no-cache \
		acl \
		fcgi \
		file \
		gettext \
		git \
		make \
        php-sysvsem \
        apk-cron \
		yarn \
		jq \
		nss-tools \
	;

RUN set -eux; \
    install-php-extensions \
    	intl \
    	zip \
    	apcu \
		opcache \
        gd \
        sysvsem \
        redis \
        amqp \
    ;

###> recipes ###
###> doctrine/doctrine-bundle ###
RUN apk add --no-cache --virtual .pgsql-deps postgresql-dev; \
	docker-php-ext-install -j$(nproc) pdo_pgsql; \
	apk add --no-cache --virtual .pgsql-rundeps so:libpq.so.5; \
	apk del .pgsql-deps
###< doctrine/doctrine-bundle ###
###< recipes ###

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY --link docker/php/conf.d/app.ini $PHP_INI_DIR/conf.d/
COPY --link docker/php/conf.d/app.prod.ini $PHP_INI_DIR/conf.d/

COPY --link docker/php/php-fpm.d/zz-docker.conf /usr/local/etc/php-fpm.d/zz-docker.conf
RUN mkdir -p /var/run/php

COPY --link docker/php/docker-healthcheck.sh /usr/local/bin/docker-healthcheck
RUN chmod +x /usr/local/bin/docker-healthcheck

HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD ["docker-healthcheck"]

USER root

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV PATH="${PATH}:/root/.composer/vendor/bin"

COPY --from=composer/composer:2-bin --link /composer /usr/bin/composer

# prevent the reinstallation of vendors at every changes in the source code
COPY --link kbin-core/composer.* kbin-core/symfony.* ./
# downgrade flysystem due to bug introduced in 4.8 where it ignores environment variables
RUN composer require "oneup/flysystem-bundle:4.7" --prefer-dist --no-scripts --no-progress
RUN set -eux; \
	composer install --prefer-dist --no-dev --no-autoloader --no-scripts --no-progress; \
	composer clear-cache; 

# copy sources
COPY --link ./default-env ./kbin-core/ ./
RUN rm -Rf docker/
# RUN cp default-env .env
RUN cp .env.example .env
COPY --link docker/php/monolog.yaml docker/php/cache.yaml ./config/packages/prod/

# S3 storage stuff
COPY --link docker/php/oneup_flysystem.yaml docker/php/liip_imagine.yaml ./config/packages/prod/
# COPY --link docker/php/oneup_flysystem.yaml docker/php/liip_imagine.yaml ./config/packages/
COPY --link docker/php/services_prod.yaml ./config/services_prod.yaml
# COPY --link docker/php/services.yaml ./config/
COPY --link docker/php/s3loader.php ./bin/

# caddy added in stuff (single image, different commands approach which puts all inter-linked requirements in one image)
RUN mkdir -p /etc/caddy
COPY --from=app_caddy_builder --link /usr/bin/caddy /usr/bin/caddy
COPY --link docker/caddy/config.template /etc/caddy/config.template



RUN set -eux; \
	mkdir -p var/cache; \
	composer dump-autoload --classmap-authoritative --no-dev; \
	composer run-script --no-dev post-install-cmd; \
	chmod +x bin/console; sync;
	
ENTRYPOINT ["docker-entrypoint"]
CMD ["php-fpm", "-R"]
# finally build the front-end once all else is build
RUN yarn install --lock-frozen && yarn build --mode production && yarn cache clean && rm -rf node_modules

COPY --link docker/php/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint
