mkdir -p ryan-build/mac
export PKG_CONFIG_PATH="/opt/homebrew/Cellar/sdl2/2.32.2/lib/pkgconfig"
SDL2_CFLAGS=$(pkg-config --static --cflags SDL2)
SDL2_LDFLAGS=$(pkg-config --static --libs SDL2)

./configure \
  --logfile=ryan-build/mac/log.txt \
  --prefix=ryan-build/mac \
  --enable-gpl \
  --enable-nonfree \
  --enable-sdl \
  --cc=clang \
  --cxx=clang++ \
  --extra-cflags="${SDL2_CFLAGS}" \
  --extra-ldflags="${SDL2_LDFLAGS}" \
  --enable-pic \
  --pkg-config-flags="--static --cflags SDL2 --libs SDL2" \
  --pkg-config=/opt/homebrew/bin/pkg-config >./ryan-build/mac/configure-log.txt
make clean
make -j8
make install
