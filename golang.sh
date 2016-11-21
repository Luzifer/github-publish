#!/bin/bash

curl -sL https://raw.githubusercontent.com/Luzifer/github-publish/master/SHA256SUMS | \
  grep "golang.sh" | sha256sum -c || exit 2

VERSION=$(git describe --tags --exact-match)
PWD=$(pwd)
godir=${PWD/${GOPATH}\/src\/}
REPO=${REPO:-$(echo ${godir} | cut -d '/' -f 3)}
USER=${USER:-$(echo ${godir} | cut -d '/' -f 2)}
ARCHS=${ARCHS:-"linux/amd64 linux/arm darwin/amd64 windows/amd64"}

set -e

if [ -z "${VERSION}" ]; then
  echo "No tag present, stopping build now."
  exit 0
fi

if [ -z "${GITHUB_TOKEN}" ]; then
  echo "Please set \$GITHUB_TOKEN environment variable"
  exit 1
fi

set -x

# Retrieve dependencies
go get github.com/aktau/github-release
go get github.com/mitchellh/gox

# Compile program
gox -ldflags="-X main.version=${VERSION}" -osarch="${ARCHS}"
# Generate SHASUMs
sha256sum ${REPO}_* > SHA256SUMS

# Create a drafted release
github-release release --user ${USER} --repo ${REPO} --tag ${VERSION} --name ${VERSION} --draft || true

# Upload build assets
for file in ${REPO}_* SHA256SUMS; do
  github-release upload --user ${USER} --repo ${REPO} --tag ${VERSION} --name ${file} --file ${file}
done
