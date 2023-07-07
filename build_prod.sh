#!/bin/bash

docker buildx create --name kbin-builder
docker buildx use kbin-builder

docker buildx build --platform linux/arm64,linux/amd64 --push -t ghcr.io/elijahnyp/kbin-alternate-docker:0.0.3 -f Dockerfile .
