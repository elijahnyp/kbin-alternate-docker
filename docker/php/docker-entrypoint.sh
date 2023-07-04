#!/bin/sh
set -e

# # merge env into .env
dos2unix /srv/app/default-env # just in case it comes in with dos line endings, which breaks the sh magic
export > /srv/app/.env.cache
cat /srv/app/default-env|grep -v ^#|grep -v -E '^\s?$'|sed -r 's/(\S+)/export \1/' > /srv/app/.env.stock
source /srv/app/.env.stock
source /srv/app/.env.cache
export | sed -r 's/export //' | grep '=' > /srv/app/.env

echo "$@"

if [[ -n "$S3_HOST" && -n "$S3_PORT" ]]; then
  export S3_ENDPOINT=${S3_PROTOCOL:-http}://${S3_HOST}:${S3_PORT}
fi

if [ "$1" == "caddy" ]; then
    # setup caddy variables
    if [[ -z "$AWS_ACCESS_KEY_ID" ]]; then
        export AWS_ACCESS_KEY_ID=${S3_KEY:-!DUMMY}
    fi
    if [[ -z "$AWS_SECRET_ACCESS_KEY" ]]; then
        export AWS_SECRET_ACCESS_KEY=${S3_SECRET:-!DUMMYlongtemppassword}
    fi
    if [[ "${S3_USE_PATH_STYLE_ENDPOINTS}" != "false" ]]; then
        export S3_USE_PATH_STYLE_ENDPOINTs="true"
    fi
    if [[ -z "$MERCURE_PUBLISHER_JWT_KEY" ]]; then
        export MERCURE_PUBLISHER_JWT_KEY=${CADDY_MERCURE_JWT_SECRET:-!ChangeThisMercureHubJWTSecretKey!}
    fi
    if [[ -z "$MERCURE_SUBSCRIBER_JWT_KEY" ]]; then
        export MERCURE_SUBSCRIBER_JWT_KEY=${CADDY_MERCURE_JWT_SECRET:-!ChangeThisMercureHubJWTSecretKey!}
    fi

    export | sed -r 's/export //' | grep '=' > /srv/app/.env
    
    # do variable replacement for variables not supported in json for caddy - it's messy
    dos2unix /etc/caddy/config.template
    echo 'cat << END_OF_TEXT' > temp.sh
    cat "/etc/caddy/config.template" >> temp.sh
    sh temp.sh > /etc/caddy/config.json
    rm temp.sh

    # fix bash escaped characters - we did set the expectation that it's messy
    sed -i 's/\\/\\\\/g' /etc/caddy/config.json

    # disable caddy ssl
    if [[ "${CADDY_DISABLE_SSL:-false}" != "false" ]]; then
        echo "disabling caddy ssl"
        jq 'del(.apps.http.servers.https)' /etc/caddy/config.json > /etc/caddy/config.temp
        mv /etc/caddy/config.temp /etc/caddy/config.json
    fi

    set -- /usr/bin/caddy run --config /etc/caddy/config.json
fi

# construct composite variables if not set
if [[ -z "${DATABASE_URL}" ]]; then 
#   export DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT:-5432}?serverVersion=${POSTGRES_VERSION:-13}&charset=${POSTGRES_CHARSET:-utf8}"
  export DATABASE_URL="postgresql://${POSTGRES_USER:-kbin}:${POSTGRES_PASSWORD:-ChangeMe}@${POSTGRES_HOST:-database}:${POSTGRES_PORT:-5432}/${POSTGRES_DATABASE:-kbin}?serverVersion=${POSTGRES_VERSION:-13}&charset=${POSTGRES_CHARSET:-utf8}"
fi
if [[ -n "${REDIS_PASSWORD}" && -n "${REDIS_HOST}" ]]; then 
  export REDIS_DNS="redis://${REDIS_PASSWORD}@${REDIS_HOST:-redis}:${REDIS_PORT:-6379}"
fi
if [[ -z "${LOCK_DSN}" ]]; then 
  export LOCK_DSN="redis://${REDIS_PASSWORD}@${REDIS_HOST:-redis}:${REDIS_PORT:-6379}"
fi
if [[ -z "${MESSENGER_TRANSPORT_DSN}" ]]; then 
  export MESSENGER_TRANSPORT_DSN="amqp://${RABBITMQ_USER:-kbin}:${RABBITMQ_PASSWORD}@${RABBITMQ_HOST:-rabbitmq}:5672/%2f/messages"
fi

export | sed -r 's/export //' | grep '=' > /srv/app/.env

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
    set -- php-fpm "$@"
fi

if [ "$1" = 'php-fpm' ] || [ "$1" = 'php' ] || [ "$1" = 'bin/console' ]; then
        # if running as a service install assets
    if [ ! -f /srv/app/generated ]; then
        # composer dump-autoload --classmap-authoritative --no-dev; \
        # composer run-script --no-dev post-install-cmd; \
        # chmod +x bin/console; sync;
    
        # finally build the front-end once all else is build
        # yarn install && yarn build && yarn cache clean && rm -rf node_modules

        touch /srv/app/generated
        php /srv/app/bin/s3loader.php
    fi
    if [ "$1" == "php-fpm" ]; then
        echo "Starting as servce..."

        # dump out a config php file if an environment file is found and we are in production
        if [ "$APP_ENV" == "prod" ]; then
            composer dump-env prod
        fi

        echo "Waiting for db to be ready..."
        ATTEMPTS_LEFT_TO_REACH_DATABASE=60
        until [ $ATTEMPTS_LEFT_TO_REACH_DATABASE -eq 0 ] || DATABASE_ERROR=$(bin/console dbal:run-sql "SELECT 1" 2>&1); do
            if [ $? -eq 255 ]; then
                # If the Doctrine command exits with 255, an unrecoverable error occurred
                ATTEMPTS_LEFT_TO_REACH_DATABASE=0
                break
            fi
            sleep 1
            ATTEMPTS_LEFT_TO_REACH_DATABASE=$((ATTEMPTS_LEFT_TO_REACH_DATABASE - 1))
            echo "Still waiting for db to be ready... Or maybe the db is not reachable. $ATTEMPTS_LEFT_TO_REACH_DATABASE attempts left"
        done

        if [ $ATTEMPTS_LEFT_TO_REACH_DATABASE -eq 0 ]; then
            echo "The database is not up or not reachable:"
            echo "$DATABASE_ERROR"
            exit 1
        else
            echo "The db is now ready and reachable"
        fi

        if [ "$( find ./migrations -iname '*.php' -print -quit )" ]; then
            bin/console doctrine:migrations:migrate --no-interaction
        fi
        # composer run-script --no-dev post-install-cmd
    fi
fi

exec "$@"