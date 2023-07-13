#!/bin/bash
docker buildx create --name kbin-builder
docker buildx use kbin-builder

docker buildx build --push -t ghcr.io/elijahnyp/kbin-alternate-docker:test -f Dockerfile .
