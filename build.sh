#!/bin/bash
docker buildx create --name kbin-builder
docker buildx use kbin-builder

docker build -t ghcr.io/elijahnyp/kbin-alternate-docker:1fe3fd3dd4 -t ghcr.io/elijahnyp/kbin-alternate-docker:latest -f Dockerfile .
