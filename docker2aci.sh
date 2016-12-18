#!/bin/bash

set -o pipefail

curl -sL https://raw.githubusercontent.com/Luzifer/github-publish/master/SHA256SUMS | \
  grep "docker2aci.sh" | sha256sum -c || exit 2

VERSION=$(git describe --tags --exact-match)
PWD=$(pwd)
REPO=${REPO:-$(basename ${PWD})}
DOCKERFILE_PATH=${DOCKERFILE_PATH:-.}

set -e

if [ -z "${VERSION}" ]; then
  echo "No tag present, stopping build now."
  exit 0
fi

if [ -z "${GITHUB_TOKEN}" ]; then
  echo "Please set \$GITHUB_TOKEN environment variable"
  exit 1
fi

if [ -z "${REPO}" ]; then
  echo "Please set \$REPO environment variable"
  exit 1
fi

if [ -z "${GHUSER}" ]; then
  echo "Please set \$GHUSER environment variable"
  exit 1
fi

DOCKER_IMAGE="${GHUSER,,}/${REPO,,}:${VERSION,,}"
ACIMAGE="${GHUSER,,}-${REPO,,}-${VERSION,,}.aci"

set -x

# Retrieve dependencies
curl -sL https://github.com/appc/docker2aci/releases/download/v0.14.0/docker2aci-v0.14.0.tar.gz | \
  tar -xvz -f - --wildcards --strip-components=1 '*/docker2aci'

docker build -t "${GHUSER}/${REPO}:${VERSION}" ${DOCKERFILE_PATH}
docker save -o build.docker "${GHUSER}/${REPO}:${VERSION}"

./docker2aci build.docker

# TODO: Sign release

sha256sum ${ACIMAGE} > SHA256SUMS

# Create a drafted release
github-release release --user ${GHUSER} --repo ${REPO} --tag ${VERSION} --name ${VERSION} --draft || true

# Upload build assets
for file in ${ACIMAGE} SHA256SUMS; do
  github-release upload --user ${GHUSER} --repo ${REPO} --tag ${VERSION} --name ${file} --file ${file}
done

