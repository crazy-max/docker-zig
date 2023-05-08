variable "ZIG_VERSION" {
  default = null
}

variable "NPROC" {
  default = null
}

target "_common" {
  args = {
    ZIG_VERSION = ZIG_VERSION
    NPROC = NPROC
  }
}

target "_platforms" {
  platforms = [
    "darwin/amd64",
    "darwin/arm64",
#    "freebsd/amd64",
    "linux/386",
    "linux/amd64",
    "linux/arm/v5",
    "linux/arm/v6",
    "linux/arm/v7",
    "linux/arm64",
    "linux/ppc64le",
    "linux/riscv64",
#    "linux/s390x",
#    "linux/mips",
#    "linux/mipsle",
#    "linux/mips64",
#    "linux/mips64le",
    "windows/amd64",
    "windows/arm",
    "windows/arm64"
  ]
}

group "default" {
  targets = ["archive"]
}

target "base" {
  inherits = ["_common"]
  target = "build-host"
  output = ["type=cacheonly"]
}

target "image" {
  inherits = ["_common"]
  target = "dist"
}

target "image-cross" {
  inherits = ["image", "_platforms"]
}

target "image-local" {
  inherits = ["image"]
  tags = ["zig:local"]
  output = ["type=docker"]
}

target "archive" {
  inherits = ["_common"]
  target = "dist-tgz"
  output = ["./dist"]
}

target "archive-cross" {
  inherits = ["archive", "_platforms"]
}
