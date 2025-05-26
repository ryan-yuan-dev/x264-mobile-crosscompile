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
# 指定 Android NDK 路径
NDK_PATH=
# 指定 Android SDK 路径
SDK_PATH=
# 指定 arch-abi
ARCH_ABI=arm64-v8a
ARCH=armv8-a
PROC=aarch64
CPU=arm64
# 指定 api 版本
API_VERSION=24
CLANG_TARGET="aarch64-none-linux-android${API_VERSION}"
# C 编译器
# C++ 编译器

# ----- 内部计算 -----

# 脚本所在目录
SCRIPT_DIR=

# `configure` 文件路径
CONFIGURE_FILE=

# cmake 执行文件所在目录，${SDK_PATH}/cmake/3.22.1/bin
CMAKE_HOME=
# android.toolchain.cmake 文件路径
# CMAKE_TOOLCHAIN_FILE=
# ${NDK_PATH}/toolchains/llvm/prebuilt/{host-tag}/bin, 使用 ${NDK_PATH}/ndk-which 自动获取
TOOLCHAIN_BIN=
# strip/ranlib 等路径前缀
TOOLCHAIN_PREFIX=
CLANG_TARGET=
#
SYSROOT=

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
  echo "  --abi                         指定目标架构， 默认 arm64-v8a"
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
    --abi)
      ARCH_ABI="$2"
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

# 获取当前脚本所在目录
get_this_script_dir() {
  # 获取当前脚本的绝对路径
  local SCRIPT_PATH
  SCRIPT_PATH="$(realpath "$0")"
  # 获取当前脚本所在的目录
  SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
  echo "BUILD_DIR $BUILD_DIR"
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

# 是否定义了 NDK_ROOT 或者 NDK_HOME 环境变量
check_ndk() {
  if [ -n "$ANDROID_NDK" ]; then
    NDK_PATH="$ANDROID_NDK"
  fi

  if [ -z "$NDK_PATH" ] && [ -n "$NDK_ROOT" ]; then
    NDK_PATH="$NDK_ROOT"
  fi

  if [ -z "$NDK_PATH" ] && [ -n "$NDK_HOME" ]; then
    NDK_PATH="$NDK_HOME"
  fi

  if [ -z "$NDK_PATH" ]; then
    echo "Please define NDK_ROOT or NDK_HOME environment variable"
    exit 1
  fi
  echo "NDK PATH found ${NDK_PATH}"
}

# 检测是否定义了 Android SDK 环境变量
check_sdk() {
  if [ -n "$ANDROID_ROOT" ]; then
    SDK_PATH="$ANDROID_ROOT"
  elif [ -n "$ANDROID_HOME" ]; then
    SDK_PATH="$ANDROID_HOME"
  fi

  if [ -z "$SDK_PATH" ]; then
    echo "Please define ANDROID_ROOT or ANDROID_HOME environment variable"
    exit 1
  fi
  echo "SDK PATH found ${SDK_PATH}"
}

# 检测是否安装了 Android Cmake
check_cmake() {
  CMAKE_HOME="${SDK_PATH}/cmake/3.22.1"
  # 判断 ${CMAKE_HOME}/bin/cmake 文件是否存在
  if [ ! -f "${CMAKE_HOME}/bin/cmake" ]; then
    echo "Please install cmake 3.22.1 from [Android Studio]-[Android SDK]"
    exit 1
  fi
  echo "CMAKE PATH fount ${CMAKE_HOME}/bin/cmake; ccmake cpack ctest and ninja are in path too"
  export PATH=${CMAKE_HOME}/bin:$PATH
}

set_cpu_info_by_abi() {
  if [ "$ARCH_ABI" = "arm64-v8a" ]; then
    PROC="aarch64"
    ARCH="armv8-a"
    CLANG_TARGET="aarch64-none-linux-android${API_VERSION}"
    # CPU="arm64"
    return
  fi
  if [ "$ARCH_ABI" = "armeabi-v7a" ]; then
    PROC="arm"
    ARCH="armv7-a"
    CLANG_TARGET="armv7-none-linux-androideabi${API_VERSION}"
    # CPU="armv7-a"
    return
  fi
  if [ "$ARCH_ABI" = "x86" ]; then
    PROC="i686"
    ARCH="x86"
    CLANG_TARGET="i686-none-linux-android${API_VERSION}"
    # CPU="x86"
    return
  fi
  if [ "$ARCH_ABI" = "x86_64" ]; then
    PROC="x86_64"
    ARCH="x86_64"
    CLANG_TARGET="x86_64-none-linux-android${API_VERSION}"
    # CPU="x86_64"
    return
  fi
}

collect_build_info() {
  set_cpu_info_by_abi
  # aarch64-linux-android21
  local STRIP_PATH
  STRIP_PATH=$(dirname "$("${NDK_PATH}"/ndk-which strip)")
  TOOLCHAIN_BIN=$(realpath "$STRIP_PATH")
  TOOLCHAIN_PREFIX="${TOOLCHAIN_BIN}/llvm-"
  SYSROOT="$(dirname "${TOOLCHAIN_BIN}")/sysroot"
  HOST="${PROC}-linux-android"
  export CC="${TOOLCHAIN_BIN}/clang --target=${CLANG_TARGET}"
  export CXX="${TOOLCHAIN_BIN}/clang++ --target=${CLANG_TARGET}"
  export LD=${SDK_NATIVE_PATH}/ld
  export CFLAGS="-g --target=${CLANG_TARGET} -DANDROID -fdata-sections -ffunction-sections -funwind-tables -fstack-protector-strong -no-canonical-prefixes -mstackrealign -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security  -fno-limit-debug-info  -fPIC -I${SYSROOT}/usr/include"
  export CXXFLAGS="-g -DANDROID -fdata-sections -ffunction-sections -funwind-tables -fstack-protector-strong -no-canonical-prefixes -mstackrealign -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security  -fno-limit-debug-info  -fPIC -I${SYSROOT}/usr/include"
  export LDFLAGS="-L${SYSROOT}/usr/lib/${PROC}-linux-android/${API_VERSION} -lm -ldl"
  echo "TOOLCHAIN_BIN: ${TOOLCHAIN_BIN}; SYSROOT: ${SYSROOT}"
}

# cmake  使用收集到的信息创建 Makefile
build() {
  FLAVOR_BUILD_DIR="${BUILD_DIR}/${ARCH_ABI}"
  FLAVOR_INSTALL_DIR="${INSTALL_DIR}/${ARCH_ABI}"
  mkdir -p "${FLAVOR_BUILD_DIR}"
  mkdir -p "${FLAVOR_INSTALL_DIR}"
  echo "FLAVOR_BUILD_DIR: ${FLAVOR_BUILD_DIR}"
  echo "FLAVOR_INSTALL_DIR: ${FLAVOR_INSTALL_DIR}"

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

  # 使用 sed 移除 config.mak 文件中的 -lpthread
  sed -i '' 's/\s*-lpthread\s*/ /g' config.mak
  sed -i '' 's/\s*-lpthread\s*/ /g' x264.pc

  # make clean
  # make -j8
  # make install
}

main() {
  sh clear.sh
  echo ""
  echo "当前工作目录：$(pwd)"
  echo ""
  parse_arguments "$@"
  check_paths
  check_ndk
  check_sdk
  check_cmake
  collect_build_info
  get_configure_file
  build
}

main "$@"

# cmake -DCMAKE_TOOLCHAIN_FILE="crosscompile.cmake" -G "Unix Makefiles" ../../source && ccmake ../../source
