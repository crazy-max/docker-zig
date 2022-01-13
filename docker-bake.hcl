variable "ZIG_VERSION" {
  default = "0.8.1"
}

group "default" {
  targets = ["zig-tgz"]
}

group "zig-tgz" {
  targets = [for v in [
    "linux-386",
    "linux-amd64",
    "linux-arm64",
    "linux-armv6",
    "linux-armv7",
    "linux-ppc64le",
    "linux-riscv64",
    "linux-s390x",
    "windows-amd64"
  ]: "zig-${v}-tgz"]
}

target "zig-tgz-base" {
  target = "zig-static-tgz"
  args = {
    ZIG_VERSION = ZIG_VERSION
  }
  //platforms = ["linux/amd64", "linux/arm64"]
  output = ["./dist"]
}

target "zig-linux-amd64-tgz" {
  inherits = ["zig-tgz-base"]
  args = {
    ZIG_TARGET = "linux-amd64"
  }
}

target "zig-linux-arm64-tgz" {
  inherits = ["zig-tgz-base"]
  args = {
    ZIG_TARGET = "linux-arm64"
  }
}
