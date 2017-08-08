#!/bin/bash

curl -sL https://raw.githubusercontent.com/Luzifer/github-publish/master/SHA256SUMS | \
  grep "golang.sh" | sha256sum -c || exit 2

VERSION=$(git describe --tags --exact-match || echo "ghpublish__notags")
PWD=$(pwd)
godir=${PWD/${GOPATH}\/src\/}
REPO=${REPO:-$(echo ${godir} | cut -d '/' -f 3)}
GHUSER=${GHUSER:-$(echo ${godir} | cut -d '/' -f 2)}
ARCHS=${ARCHS:-"linux/amd64 linux/arm darwin/amd64 windows/amd64"}
DEPLOYMENT_TAG=${DEPLOYMENT_TAG:-${VERSION}}

set -ex

# Retrieve dependencies
go get github.com/aktau/github-release
go get github.com/mitchellh/gox

# Test code (used in PR tests, branch tests, and builds)
go vet .
go test .

# Compile program
gox -ldflags="-X main.version=${VERSION}" -osarch="${ARCHS}"

# Publish builds to Github

set +x

if ( test "${VERSION}" == "ghpublish__notags" ); then
  echo "No tag present, stopping build now."
  exit 0
fi

if [ -z "${GITHUB_TOKEN}" ]; then
  echo "Please set \$GITHUB_TOKEN environment variable"
  exit 1
fi

set -x

# Generate SHASUMs
sha256sum ${REPO}_* > SHA256SUMS

# Create a drafted release
DESC="${VERSION}"
if [ -f History.md ]; then
  sv=$(echo ${VERSION} | sed 's/^v//')
  DESC=$(awk "/# ${sv}/{flag=1;next} /# /{flag=0} flag" History.md | head -n -1 | tail -n +2)
fi

github-release release --user ${GHUSER} --repo ${REPO} \
                       --tag ${DEPLOYMENT_TAG} --name ${DEPLOYMENT_TAG} \
                       --description ${DESC} --draft || true

# Upload build assets
for file in ${REPO}_* SHA256SUMS; do
  github-release upload --user ${GHUSER} --repo ${REPO} --tag ${DEPLOYMENT_TAG} --name ${file} --file ${file}
done

echo -e "\n\n=== Recorded checksums ==="

cat SHA256SUMS