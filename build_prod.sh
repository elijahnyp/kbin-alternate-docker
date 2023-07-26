#!/bin/bash

docker buildx create --name kbin-builder
docker buildx use kbin-builder

docker buildx build --platform linux/arm64,linux/amd64 --push -t ghcr.io/elijahnyp/kbin-alternate-docker:3f688bdb -t ghcr.io/elijahnyp/kbin-alternate-docker:latest -f Dockerfile .
