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
# 指定 OHOS SDK native 路径.
# 如果安装了 DevEco Studio，则路径通常在 sdk/default/openharmony/native;
# 如果安装了独立的 sdk, 则路径通常在类似 sdk/11/native 这样的位置
SDK_NATIVE_PATH=
# 指定 arch-abi
ARCH_ABI=arm64-v8a
HOST=aarch64-linux
# 指定 api 版本
API_VERSION=1

# ----- 内部计算 -----

# cmake 执行文件所在目录，${SDK_PATH}/cmake/3.22.1/bin
CMAKE_HOME=
# android.toolchain.cmake 文件路径
CMAKE_TOOLCHAIN_FILE=

# 显示脚本帮助信息
help() {
  echo "$(pwd)/$0 执行说明："
  echo ""
  echo "- 请设置以下环境变量："
  echo "- OHOS_SDK sdk                 所在目录，比如： sdk/default/openharmony 或者 sdk/11"
  echo ""
  echo "- 选项:"
  echo "  -h                            显示此帮助信息"
  echo "  -S, --src_dir                 * 必传，指定源目录 DIR 为 CMakeLists.txt 文件所在路径"
  echo "  -B, --build_dir               * 必传，指定构建目录，必传"
  echo "  -I, --install_dir             * 必传，指定静态库和动态库的安装目录"
  echo "  --abi                         指定目标架构， 默认 arm64-v8a，可选 arm64-v8a, x86_64"
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

# 检测是否定义了 Android SDK 环境变量
check_sdk() {
  if [ -n "$OHOS_SDK_NATIVE" ]; then
    SDK_NATIVE_PATH="$OHOS_SDK_NATIVE"
  fi
  if [ -z "$SDK_NATIVE_PATH" ] && [ -n "$OHOS_SDK" ]; then
    SDK_NATIVE_PATH="$OHOS_SDK/native"
  fi
  if [ -z "$SDK_NATIVE_PATH" ]; then
    echo -e "Error: Environment variable OHOS_SDK_NATIVE or OHOS_SDK must be set. \n" \
      "Please configure it as follows: \n" \
      "    export OHOS_SDK_NATIVE=/path/to/native/sdk \n" \
      "    or \n" \
      "    export OHOS_SDK=/path/to/sdk/**/native" # Full SDK path"
    exit 1
  fi
  echo "SDK_NATIVE_PATH found ${SDK_NATIVE_PATH}"
}

# 检测是否安装了 Android Cmake
check_cmake() {
  CMAKE_HOME="${SDK_NATIVE_PATH}/build-tools/cmake"
  # 判断 ${CMAKE_HOME}/bin/cmake 文件是否存在
  if [ ! -f "${CMAKE_HOME}/bin/cmake" ]; then
    echo "cmake not found, be sure your OHOS_SDK is right"
    exit 1
  fi
  echo "CMAKE PATH fount ${CMAKE_HOME}/bin/cmake; ccmake cpack ctest and ninja are in path too"
  export PATH=${CMAKE_HOME}/bin:$PATH
}

set_cpu_info_by_abi() {
  if [ "$ARCH_ABI" = "arm64-v8a" ]; then
    PROC="aarch64"
    ARCH="armv8-a"
    # CPU="arm64"
    return
  fi
  if [ "$ARCH_ABI" = "x86_64" ]; then
    PROC="x86_64"
    ARCH="x86_64"
    # CPU="armv7-a"
    return
  fi
  echo "Abi ${ARCH_ABI} not supported"
  exit 1
}

collect_build_info() {
  set_cpu_info_by_abi
  TOOLCHAIN_BIN="${SDK_NATIVE_PATH}/llvm/bin"
  TOOLCHAIN_PREFIX="${TOOLCHAIN_BIN}/llvm-"
  HOST=${PROC}-linux
  export CC="${TOOLCHAIN_BIN}/${PROC}-unknown-linux-ohos-clang"
  export CXX="${TOOLCHAIN_BIN}/${PROC}-unknown-linux-ohos-clang"
  export LD=${SDK_NATIVE_PATH}/ld.lld
  export AS=${TOOLCHAIN_BIN}/llvm-as
  export STRIP=${TOOLCHAIN_BIN}/llvm-strip
  export RANLIB=${TOOLCHAIN_BIN}/llvm-ranlib
  export OBJDUMP=${TOOLCHAIN_BIN}/llvm-objdump
  export OBJCOPY=${TOOLCHAIN_BIN}/llvm-objcopy
  export NM=${TOOLCHAIN_BIN}/llvm-nm
  export AR=${OTOOLCHAIN_BIN}/llvm-ar
  export CFLAGS="-DOHOS_NDK -v --target=${PROC}-linux-ohos --gcc-toolchain=${SDK_NATIVE_PATH}/llvm -fdata-sections -ffunction-sections -funwind-tables -fstack-protector-strong -no-canonical-prefixes -fno-addrsig -Wa,--noexecstack -Wformat -Werror=format-security -D__MUSL__=1 -O0 -g -fno-limit-debug-info -fPIC -isysroot=${SYSROOT} -I${SYSROOT}/include/${PROC}-linux-ohos"
  export CXXFLAGS="-DOHOS_NDK -fPIC -D__MUSL__=1"
  export LDFLAGS="-L${SYSROOT}/usr/lib/${PROC}-linux-ohos"

  SYSROOT="${SDK_NATIVE_PATH}/sysroot"
  echo "CC: ${CC}"
  echo "CXX: ${CXX}"
  echo "TOOLCHAIN_BIN: ${TOOLCHAIN_BIN}"
  echo "SYSROOT: ${SYSROOT}"
  echo "TOOLCHAIN_PREFIX：${TOOLCHAIN_PREFIX}"
}

# 更新 ../config.h 文件
update_config_h() {
  # #define SYS_MACOSX 0 #define SYS_MACOSX 0
  sed -i '' 's/#define SYS_MACOSX 1/#define SYS_MACOSX 0/' config.h
  # sed -i '' 's/SONAME=libx264.so.164/SONAME=libx264.so/' config.mak
  # sed -i '' 's/SOFLAGS=-shared -Wl,-soname,$(SONAME)  -Wl,-Bsymbolic/SOFLAGS=-shared/' config.mak
  echo "#define SYS_LINUX 1" >>config.h
}

# cmake  使用收集到的信息创建 Makefile
build() {
  FLAVOR_BUILD_DIR="${BUILD_DIR}/${ARCH_ABI}"
  FLAVOR_INSTALL_DIR="${INSTALL_DIR}/${ARCH_ABI}"
  mkdir -p "${FLAVOR_BUILD_DIR}"
  mkdir -p "${FLAVOR_INSTALL_DIR}"
  rm -rf "${FLAVOR_INSTALL_DIR}"
  mkdir -p "${FLAVOR_INSTALL_DIR}"
  echo "FLAVOR_BUILD_DIR: ${FLAVOR_BUILD_DIR}"
  echo "FLAVOR_INSTALL_DIR: ${FLAVOR_INSTALL_DIR}"

  # 删除 $FLAVOR_BUILD_DIR/log.txt 文件，如果存在
  if [ -f "$FLAVOR_BUILD_DIR/log.txt" ]; then
    rm -f "$FLAVOR_BUILD_DIR/log.txt"
  fi

  "${CONFIGURE_FILE}" \
    --prefix="${FLAVOR_INSTALL_DIR}" \
    --exec-prefix="${FLAVOR_INSTALL_DIR}" \
    --cross-prefix="${TOOLCHAIN_PREFIX}" \
    --host="${HOST}" \
    --extra-cflags="${CFLAGS}" \
    --extra-ldflags="-L${SYSROOT}/usr/lib/${PROC}-linux-ohos" \
    --disable-cli \
    --enable-shared \
    --disable-win32thread \
    --disable-asm \
    --enable-pic

  update_config_h
  make clean
  make -j8 -d >ohos-make.log
  make install
}

reset() {
  # git restore ffbuild/.
  # git restore Makefile
  # git restore config.guess
  # git restore configure
  # rm **/*.o
  echo ""
}

main() {
  reset
  echo ""
  echo "当前工作目录：$(pwd)"
  echo ""
  parse_arguments "$@"
  check_paths
  check_sdk

  # check_cmake
  collect_build_info
  get_configure_file
  build
}

main "$@"

# cmake -DCMAKE_TOOLCHAIN_FILE="crosscompile.cmake" -G "Unix Makefiles" ../../source && ccmake ../../source
