#!/bin/bash
docker buildx create --name kbin-builder-dev
docker buildx use kbin-builder-dev

docker build -t ghcr.io/elijahnyp/kbin-alternate-docker:1fe3fd3dd4 -t ghcr.io/elijahnyp/kbin-alternate-docker:latest-f Dockerfile .