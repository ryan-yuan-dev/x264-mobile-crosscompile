#!/bin/bash
# Run this from within a bash shell

# ----- 外部设置 -----

# 指定 CMakeLists.txt 所在文件夹
SOURCE_DIR=
# 指定构建文件目录
BUILD_DIR=
FLAVOR_BUILD_DIR=
INSTALL_DIR=
FLAVOR_INSTALL_DIR=
ARCH_ABI=arm64
ARCH=arm64
PROC=aarch64

# 指定 iPhone SDK 路径
SDK_PATH=
TOOLCHAIN_BIN=$(dirname "$(xcrun --sdk iphoneos -f clang)")
TOOLCHAIN_PREFIX=
CC=
CXX=
AR=
AS=
RANLIB=
STRIP=
STRINGS=
LD=
# 指定 arch-abi
PLATFORM=OS64
# 指定 api 版本
API_VERSION="13.0"

# ----- 内部计算 -----

# 显示脚本帮助信息
help() {
  echo "$(pwd)/$0 执行说明："
  echo ""
  echo "- 请设置以下环境变量："
  echo "- ANDROID_HOME sdk              所在目录，比如： /xx/Android/sdk"
  echo "- ANDROID_NDK ndk               所在目录，比如： /xx/Android/sdk/ndk/26.3.11579264"
  echo ""
  echo "- 选项:"
  echo "  -h                            显示此帮助信息"
  echo "  -S, --src_dir                 * 必传，指定源目录 DIR 为 CMakeLists.txt 文件所在路径"
  echo "  -B, --build_dir               * 必传，指定构建目录，必传"
  echo "  -I, --install_dir             * 必传，指定静态库和动态库的安装目录"
  echo "  --platform                    指定目标架构， 默认 OS64"
  echo "  --api                         指定目标 api 版本， 默认 21"
  exit 0
}

# 解析脚本参数
parse_arguments() {
  # 解析参数
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h)
      help # 调用帮助函数并退出
      ;;
    --src_dir)
      if [[ "$2" == /* ]]; then
        SOURCE_DIR="$2"
      else
        SOURCE_DIR="$(pwd)/$2"
      fi
      shift 2
      ;;
    --build_dir)
      if [[ "$2" == /* ]]; then
        BUILD_DIR="$2"
      else
        BUILD_DIR="$(pwd)/$2"
      fi
      shift 2
      ;;
    --install_dir)
      if [[ "$2" == /* ]]; then
        INSTALL_DIR="$2"
      else
        INSTALL_DIR="$(pwd)/$2"
      fi
      shift 2
      ;;
    -S)
      if [[ "$2" == /* ]]; then
        SOURCE_DIR="$2"
      else
        SOURCE_DIR="$(pwd)/$2"
      fi
      shift 2
      ;;
    -B)
      if [[ "$2" == /* ]]; then
        BUILD_DIR="$2"
      else
        BUILD_DIR="$(pwd)/$2"
      fi
      shift 2
      ;;
    -I)
      if [[ "$2" == /* ]]; then
        INSTALL_DIR="$2"
      else
        INSTALL_DIR="$(pwd)/$2"
      fi
      shift 2
      ;;
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    --api)
      API_VERSION="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      help # 显示帮助并退出
      ;;
    esac
  done
}

# 获取当前脚本所在目录
get_this_script_dir() {
  # 获取当前脚本的绝对路径
  local SCRIPT_PATH=
  SCRIPT_PATH="$(realpath "$0")"
  # 获取当前脚本所在的目录
  SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
  echo "BUILD_DIR $BUILD_DIR"
}

# 检查是否设置了 SOURCE_DIR 和 BUILD_DIR
check_paths() {
  if [ -z "${SOURCE_DIR}" ]; then
    echo "Please specify the source directory with --src_dir or -S"
    exit 1
  fi
  echo "SOURCE_DIR $SOURCE_DIR"
  if [ -z "${BUILD_DIR}" ]; then
    echo "Please specify the build directory with --build_dir or -B"
    exit 1
  fi
  echo "BUILD_DIR $BUILD_DIR"
  if [ -z "${INSTALL_DIR}" ]; then
    echo "Please specify the install directory with --install_dir or -I"
    exit 1
  fi
  echo "INSTALL_DIR $INSTALL_DIR"
}

set_toolchain_file() {
  # # 获取当前脚本的绝对路径
  # local SCRIPT_PATH
  # SCRIPT_PATH="$(realpath "$0")"
  # SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
  SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
  SYSROOT="$SDK_PATH"
  TOOLCHAIN_BIN=$(dirname "$(xcrun --sdk iphoneos -f clang)")
  export CC="$(xcrun --sdk iphoneos -f clang) --target=arm64-apple-ios${API_VERSION}"
  export CXX="$(xcrun --sdk iphoneos -f clang++) --target=arm64-apple-ios${API_VERSION}"
  TOOLCHAIN_PREFIX="${TOOLCHAIN_BIN}/llvm-"
  export AR=$(xcrun --sdk iphoneos -f ar)
  export AS=$(xcrun --sdk iphoneos -f as)
  export LD=$(xcrun --sdk iphoneos -f ld)
  export RANLIB=$(xcrun --sdk iphoneos -f ranlib)
  export STRIP=$(xcrun --sdk iphoneos -f strip)
  export STRINGS=$(xcrun --sdk iphoneos -f strings)
  export CFLAGS="-fembed-bitcode -fvisibility=default  -DNDEBUG -O3 -isysroot ${SYSROOT} -miphoneos-version-min=${API_VERSION} -I${SYSROOT}/usr/include"
  export LDFLAGS="-L${SYSROOT}/usr/lib -lm -ldl -lpthread"
  echo "SDK_PATH: $SDK_PATH"
  echo "SYSROOT: $SYSROOT"
  echo "TOOLCHAIN_BIN: $TOOLCHAIN_BIN"
  echo "CC: $CC"
  echo "CXX: $CXX"
  echo "TOOLCHAIN_PREFIX: $TOOLCHAIN_PREFIX"
  echo "AR: $AR"
  echo "AS: $AS"
  echo "LD: $LD"
  echo "RANLIB: $RANLIB"
  echo "STRIP: $STRIP"
}

get_configure_file() {
  get_this_script_dir
  CONFIGURE_FILE="$(realpath "${SCRIPT_DIR}/../configure")"
  if [ ! -f "$CONFIGURE_FILE" ]; then
    echo "Configure file not found at scripts/../configure"
    exit 1
  fi
  echo "CONFIGURE_FILE: ${CONFIGURE_FILE}"
}

# cmake  使用收集到的信息创建 Makefile
build() {
  FLAVOR_BUILD_DIR="${BUILD_DIR}/${ARCH_ABI}"
  FLAVOR_INSTALL_DIR="${INSTALL_DIR}/${ARCH_ABI}"
  mkdir -p "${FLAVOR_BUILD_DIR}"
  mkdir -p "${FLAVOR_INSTALL_DIR}"
  echo "FLAVOR_BUILD_DIR: ${FLAVOR_BUILD_DIR}"
  echo "FLAVOR_INSTALL_DIR: ${FLAVOR_INSTALL_DIR}"

  HOST="aarch64-apple-darwin"

  "${CONFIGURE_FILE}" \
    --prefix="${FLAVOR_INSTALL_DIR}" \
    --exec-prefix="${FLAVOR_INSTALL_DIR}" \
    --cross-prefix="${TOOLCHAIN_PREFIX}" \
    --host="${HOST}" \
    --extra-cflags="${CFLAGS}" \
    --extra-ldflags="${LDFLAGS}" \
    --disable-cli \
    --enable-shared \
    --disable-win32thread \
    --disable-asm \
    --enable-pic
  make clean
  make -j8
  make install
}

main() {
  git restore ffbuild/.
  git restore Makefile
  echo ""
  echo "当前工作目录：$(pwd)"
  echo ""
  parse_arguments "$@"
  check_paths
  set_toolchain_file
  get_configure_file
  build
}

main "$@"
# fix_math_funcs_conflicts
