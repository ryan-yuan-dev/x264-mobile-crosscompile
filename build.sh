# 获取 iOS SDK 路径
export SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)
export CC=$(xcrun --sdk iphoneos --find clang)
export CXX=$(xcrun --sdk iphoneos --find clang++)
export AS=$(xcrun --sdk iphoneos --find as)
export AR=$(xcrun --sdk iphoneos --find ar)
export RANLIB=$(xcrun --sdk iphoneos --find ranlib)
export STRIP=$(xcrun --sdk iphoneos --find strip)
export LD=$(xcrun --sdk iphoneos --find ld)
export CFLAGS="-arch arm64 -isysroot $SDKROOT -miphoneos-version-min=11.0"
export LDFLAGS="-arch arm64 -isysroot $SDKROOT"

# 运行 configure 脚本
./configure \
  --host=arm-apple-darwin \
  --sysroot=$SDKROOT \
  --extra-cflags="$CFLAGS" \
  --extra-ldflags="$LDFLAGS" \
  --enable-shared \
  --enable-pic \
  --disable-cli \
  --prefix=$(pwd)/ios-build \
  --disable-asm \
  --enable-static
