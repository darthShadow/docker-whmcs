# ---- groups ----

group "default" {
  targets = ["image-local"]
}

group "publish" {
  targets = ["publish"]
}

# ---- variables ----

variable "PHP_RELEASE" {
    default = "7.4"
}

variable "WHMCS_RELEASE" {
    default = "8.7.3"
}

# ---- targets ----

target "docker-metadata-action" {}

target "image" {
  inherits = ["docker-metadata-action"]
  dockerfile = "Dockerfile"
  context = "."
  args = {
    PHP_RELEASE = PHP_RELEASE
    WHMCS_RELEASE = WHMCS_RELEASE
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
