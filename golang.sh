#!/bin/bash
set -euo pipefail

curl -sL https://raw.githubusercontent.com/Luzifer/github-publish/master/SHA256SUMS |
	grep "golang.sh" | sha256sum -c || exit 2

(which zip 2>&1 1>/dev/null) || {
	(which apk 2>&1 1>/dev/null) && apk add --update zip
	(which apt-get 2>&1 1>/dev/null) && apt-get update && apt-get install -y zip
}

function step() {
	echo "===> $@..."
}

VERSION=$(git describe --tags --always || echo "dev")
PWD=$(pwd)
godir=${PWD/${GOPATH}\/src\//}
REPO=${REPO:-$(echo ${godir} | cut -d '/' -f 3)}
GHUSER=${GHUSER:-$(echo ${godir} | cut -d '/' -f 2)}
ARCHS=${ARCHS:-"linux/amd64 linux/arm darwin/amd64 windows/amd64"}
DEPLOYMENT_TAG=${DEPLOYMENT_TAG:-${VERSION}}
PACKAGES=${PACKAGES:-$(echo ${godir} | cut -d '/' -f 1-3)}
BUILD_DIR=${BUILD_DIR:-.build}
DRAFT=${DRAFT:-true}
FORCE_SKIP_UPLOAD=${FORCE_SKIP_UPLOAD:-false}
MOD_MODE=${MOD_MODE:-}

go version

step "Retrieve dependencies"
pushd ${GOPATH}
go get github.com/aktau/github-release
go get github.com/mitchellh/gox
popd

step "Test code"
test_params=()

if [[ -n ${MOD_MODE} ]]; then
	test_params+=(-mod="${MOD_MODE}")
fi

go vet "${test_params[@]}" ${PACKAGES}
go test "${test_params[@]}" ${PACKAGES}

step "Cleanup build directory if present"
rm -rf ${BUILD_DIR}

step "Compile program"
mkdir ${BUILD_DIR}

build_params=(
	-ldflags="-X main.version=${VERSION}"
	-osarch="${ARCHS}"
	-output="${BUILD_DIR}/{{.Dir}}_{{.OS}}_{{.Arch}}"
)

if [[ -n ${MOD_MODE} ]]; then
	build_params+=(-mod="${MOD_MODE}")
fi

gox \
	"${build_params[@]}" \
	${PACKAGES}

step "Generate binary SHASUMs"
cd ${BUILD_DIR}
sha256sum * >SHA256SUMS

step "Packing archives"
for file in *; do
	if [ "${file}" = "SHA256SUMS" ]; then
		continue
	fi

	if [[ ${file} == *linux* ]]; then
		tar -czf "${file%%.*}.tar.gz" "${file}"
	else
		zip "${file%%.*}.zip" "${file}"
	fi

	rm "${file}"
done

step "Generate archive SHASUMs"
sha256sum * >>SHA256SUMS
grep -v 'SHA256SUMS' SHA256SUMS >SHA256SUMS.tmp
mv SHA256SUMS.tmp SHA256SUMS

echo -e "\n\n=== Recorded checksums ==="
cat SHA256SUMS

if [[ ${FORCE_SKIP_UPLOAD} == "true" ]]; then
	echo "Upload is skipped, stopping build now."
	exit 0
fi

step "Publish builds to Github"

if ! git describe --tags --exact-match; then
	echo "No tag present, stopping build now."
	exit 0
fi

if [ -z "${GITHUB_TOKEN}" ]; then
	echo 'Please set $GITHUB_TOKEN environment variable'
	exit 1
fi

if [[ ${DRAFT} == "true" ]]; then
	step "Create a drafted release"
	github-release release --user ${GHUSER} --repo ${REPO} --tag ${DEPLOYMENT_TAG} --name ${DEPLOYMENT_TAG} --draft || true
else
	step "Create a published release"
	github-release release --user ${GHUSER} --repo ${REPO} --tag ${DEPLOYMENT_TAG} --name ${DEPLOYMENT_TAG} || true
fi

step "Upload build assets"
for file in *; do
	echo "- ${file}"
	github-release upload --user ${GHUSER} --repo ${REPO} --tag ${DEPLOYMENT_TAG} --name ${file} --file ${file}
done

cd -
