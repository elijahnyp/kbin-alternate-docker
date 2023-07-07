#!/bin/bash
docker buildx create --name kbin-builder-dev
docker buildx use kbin-builder-dev

docker build -t ghcr.io/elijahnyp/kbin-alternate-docker:0.0.2 -f Dockerfile.submodule .