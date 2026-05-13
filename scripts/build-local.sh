#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "${script_dir}/.." && pwd)

whmcs_version=$(tr -d '[:space:]' < "${repo_root}/WHMCS_VERSION.txt")
php_version=$(tr -d '[:space:]' < "${repo_root}/PHP_VERSION.txt")

cd "${repo_root}"

docker buildx bake \
  --set "image.args.WHMCS_RELEASE=${whmcs_version}" \
  --set "image.args.PHP_RELEASE=${php_version}" \
  "$@"
