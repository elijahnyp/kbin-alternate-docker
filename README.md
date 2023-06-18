# Fully Containerized Docker Deployment

** THIS IS CURRENTLY A WORK IN PROGRESS **

## Quickstart
* git clone https://codeberg.org/Kbin/kbin-core.git
* remove the following
  * Dockerfile
  * docker directory
  * all docker-compose files
* copy/move new docker directory, Dockerfile, and docker-compose.yml file in place of files you just removed
* create .env file
* `docker compose up --build` to run in the foregroud, run `docker compose up -d --build` to run in backgound
  * if you didn't make any changes to theme, .env, etc. you don't need the `--build`

## Major Modifications to stock kbin
* simplified docker file that only leverages 2 images
  * custom caddy image can likely be eliminated in the future
  * images can be built and committed to a repo, with appropriate modifications to docker-compose.yml
* changed from 'unix socket' to 'tcp' for FastCGI to support instances on different nodes
* reworked all logging to log to stdout in all containers
* reworked docker-compose.yml accordingly

## Implementation
* changes are made ONLY in the following locations - replace these to try this approach
  * the docker folder
  * Dockerfile
  * docker-compose.yml
* unless leveraging S3 for media, the 'media' volume needs to be shared among all php containers.
  * S3 is only tested with private S3 compatible storage (minio tested so far) - but should work for official as well

## Operational Considerations
* caddy can't be scaled unless mercur is reconfigured to a cluster transport
  * this would probably be necessary to support larger and/or high availability instances
* php should be scalable, but it's untested
* a redis cluster should work, but at this time hasn't been tested
  * next phase is developing kubernetes manifests for deployment

## S3 Configuration
* make sure S3 lines in dockerfile are NOT commented
* configure in environment (at build time, so .env approach)
* switch the adapter in oneup_filesystem.yaml
* profit! (hopefully)

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

## Still to Do
* all real-world testing
* rework containers to have all environment specific settings and assets overridable/built at runtime
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