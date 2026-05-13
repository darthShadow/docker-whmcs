# Local builds must set WHMCS_RELEASE via the environment or --set because the
# Dockerfile no longer falls back to the WHMCS API. scripts/build-local.sh reads
# WHMCS_VERSION.txt and PHP_VERSION.txt and passes both args for local use.

# ---- groups ----

group "default" {
  targets = ["image-local"]
}

group "publish" {
  targets = ["publish"]
}

# ---- variables ----

variable "BASE_IMAGE" {
    default = "lscr.io/linuxserver/baseimage-ubuntu:noble"
}

# Canonical PHP version lives in PHP_VERSION.txt; the workflow reads it and
# passes it as a build arg. This default is only used for local `docker buildx
# bake` invocations and should be kept in sync with PHP_VERSION.txt.
variable "PHP_RELEASE" {
    default = "8.2"
}

# Canonical WHMCS version lives in WHMCS_VERSION.txt; the workflow reads it
# and passes it as a build arg. Local builds must set this explicitly.
variable "WHMCS_RELEASE" {
    default = ""
}

variable "WHMCS_SHA256" {
    default = ""
}

# Optional SHA256 pins for the loader downloads, per architecture. Leave empty
# to skip verification; set to a known-good SHA256 to fail the build on
# mismatch. Generate values by running the build once and copying the
# "SHA256:" lines from the build log.
variable "SOURCEGUARDIAN_SHA256_AMD64" {
    default = ""
}

variable "SOURCEGUARDIAN_SHA256_ARM64" {
    default = ""
}

variable "IONCUBE_SHA256_AMD64" {
    default = ""
}

variable "IONCUBE_SHA256_ARM64" {
    default = ""
}

# ---- targets ----

target "docker-metadata-action" {}

target "image" {
  inherits = ["docker-metadata-action"]
  dockerfile = "Dockerfile"
  context = "."
  args = {
    BASE_IMAGE = BASE_IMAGE
    PHP_RELEASE = PHP_RELEASE
    WHMCS_RELEASE = WHMCS_RELEASE
    WHMCS_SHA256 = WHMCS_SHA256
    SOURCEGUARDIAN_SHA256_AMD64 = SOURCEGUARDIAN_SHA256_AMD64
    SOURCEGUARDIAN_SHA256_ARM64 = SOURCEGUARDIAN_SHA256_ARM64
    IONCUBE_SHA256_AMD64 = IONCUBE_SHA256_AMD64
    IONCUBE_SHA256_ARM64 = IONCUBE_SHA256_ARM64
  }
}

target "image-local" {
  inherits = ["image"]
  output = ["type=docker"]
}

target "publish" {
  inherits = ["image"]
  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]
}

target "image-single" {
  inherits = ["image"]
}
