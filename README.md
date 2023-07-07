# Alternate Docker Deployment for kbin

** THIS IS CURRENTLY A WORK IN PROGRESS **
** Documentation may be old and incomplete **

## Quickstart

### docker compose
* clone this repo
* customize environment in docker-compose.yml to your needs
* `docker compose up` (or `docker compose up -d` to run in background)

### helm quickstart
* clone this repo
* in Chart/kbin, copy values.yaml
* customize your copy of values.yaml to suit your needs
* `helm install kbin  Charts/kbin/ --namespace {some namespace} -f {your values file}`

## Old Build Yourself
* git clone https://codeberg.org/Kbin/kbin-core.git
* remove the following (`rm -R docker*` is sufficient)
  * Dockerfile
  * docker directory
  * all docker-compose files
* copy/move new docker directory, Dockerfile, and docker-compose.yml file in place of files you just removed
* create .env file (.env.example is sufficient to get it running but NOT for production)
* `docker compose up --build` to run in the foregroud, run `docker compose up -d --build` to run in backgound
  * if you didn't make any changes to theme, .env, etc. you don't need the `--build` after the initial startup

## Major Modifications to stock kbin
* simplified docker file that only leverages 2 custom images
  * custom caddy image with S3 filesystem, S3 proxy, and entrypoint that templates caddy json config (caddyfile is NOT supported at this time since virtual filesystems are leveraged)
  * images can be built and committed to a repo, with appropriate modifications to docker-compose.yml
* changed from 'unix socket' to 'tcp' for FastCGI to support instances on different nodes
* reworked all logging to log to stdout in all containers
* all shared volumes are eliminated - any volume mount is strictly local storage for that container and /should/ be ephemeral
* reworked docker-compose.yml accordingly

## Implementation
* changes are made ONLY in the following locations - replace these to try this approach
  * the docker folder
  * Dockerfile
  * docker-compose.yml
* S3 is only tested with private S3 compatible storage (minio tested so far) - but should work for official as well
* removing S3 from this setup isn't supported - the caddy config is reliant on S3 storage and would require significant reworking of the config and build process

## Operational Considerations
* caddy can't be scaled unless mercur is reconfigured to a cluster transport
  * this would probably be necessary to support larger and/or high availability instances
* php should be scalable, but it's untested
* a redis cluster should work, but at this time hasn't been tested
  * next phase is developing kubernetes manifests for deployment
* minio could be adapted to scale, but if deploying in kubernetes it's better to leverage a provider's storage or something like rook-ceph for local clusters

## S3 Configuration
* configuration is based on S3 storage
* compose file approach deployes minio as storage back-end

## Debugging
To get a stacktrace in the logs, uncomment the following 2 lines in monolog.yaml
```
formatter: debug_logger
include_stacktraces: true
```

## Gotchas
* RUNTIME VARIABLES IN docker-compose AND .env MUST MACH BEFORE CONTAINER BUILD
  * this will be fixed later and the containers will be 'static' and 'generic'
* if working in windows, ensure you disable git line ending adjustment PRIOR to cloning kbin repo
  * `git config core.autocrlf false`
* if you get 500 errors on federation, it's probably a bad instance key.  Just nuke it from redis and all should be good again.  I don't know why it gets set to a short string when it sould be a cert, but it does.
  1. `docker compose exec -it redis redis-cli`
  2. `auth <redis password>`
  3. `KEYS *private*`
  4. `expire <key name> 1`

## Still to Do
* all real-world testing
* rework containers to have all environment specific settings and assets overridable/built at runtime3
* restore https auto-config after testing
  * initial usage of this work will be deploying kbin in kubernetes behind an nginx proxy
    * yes, caddy is sligtly redundant but it is doing the S3 proxy and the mercurial hub work

## Contact
Best way to get a hold of me is via mastodon - https://mast.wangwood.house/@elijah


## The First User

```
docker exec -it kbin-core-php-1 php bin/console kbin:user:create username email@exmple.com password
docker exec -it kbin-core-php-1 php bin/console kbin:user:admin username
```