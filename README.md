# Luzifer / github-publish

This repository contains a set of build scripts to publish the build artifacts to Github.

## Golang

This script is intended for repositories containing vendored dependencies as it does not fetch external sources. The code will be tested with some very basic checks and afterwards built for different platforms.

Usage in a Makefile:

```Makefile
ci:
	curl -sSLo golang.sh https://raw.githubusercontent.com/Luzifer/github-publish/master/golang.sh
	bash golang.sh
```

## Docker2ACI (DRAFT)

This script is intended to build ACImages from Docker images, sign them and publish them to Github.
