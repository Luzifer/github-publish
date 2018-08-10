default:
	true

auto-hook-pre-commit: hash
	git add SHA256SUMS || true

hash:
	shasum -a 256 *.sh > SHA256SUMS
