#!/usr/bin/env bash
#############################################################################################################
# Script to generate six binary, statically-compiled versions of executables that Giocoso makes use of.
# The intent is to isolate Giocoso from the whims of the developers of these packages: the Giocoso-specific
# versions will get rebuilt when I'm ready, not when they decide!
#
# Intended to be run on a freshly-built Mac Intel system, with Xcode command line tools installed, and using
# Macports (for build tools only). Results in (up to) six executables being created in $HOME/.local/share/giocoso4/exec.
#
#############################################################################################################
set -euo pipefail

FFMPEG_DIR="$HOME/ffmpeg"
FLAC_DIR="$HOME/flac"
IMAGEMAGICK_DIR="$HOME/ImageMagick-7.1.2-30"
IMAGEMAGICK_VERSION="7.1.2-30"
IMAGEMAGICK_ARCHIVE="ImageMagick-$IMAGEMAGICK_VERSION.tar.gz"
SIXEL_DIR="$HOME/libsixel"
LIBS_DIR="$HOME/giolibs"                 # Static JPEG, PNG and FreeType libraries for magick
LIBS_SRC="$HOME/giolibs-src"
AUDIO_DIR="$HOME/gioaudiolibs"           # Static LAME, Ogg and Vorbis libraries for ffmpeg
AUDIO_SRC="$HOME/gioaudiolibs-src"
LAME_VERSION="3.100"
OGG_VERSION="1.3.5"
VORBIS_VERSION="1.3.7"
BIN_DIR="$HOME/.local/share/giocoso4/exec"
PREFIX="$HOME/.local/share/giocoso4"
JOBS="$(sysctl -n hw.ncpu)"
VERSION_STRING="bbritten-4.0.0"
export MACOSX_DEPLOYMENT_TARGET="10.15"     # Everything built here declares, and keeps to, MacOS 10.15 (Catalina) as the oldest it runs on

function prebuild {
if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "x86_64" ]]; then
  echo "ERROR: This script requires macOS on Intel."
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  echo "ERROR: Install the Xcode Command Line Tools first."
  exit 1
fi

if ! command -v port >/dev/null 2>&1; then
  echo "ERROR: MacPorts is required."
  exit 1
fi

for tool in git make clang awk sed grep curl tar; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $tool"
    exit 1
  fi
done

for package in autoconf automake libtool nasm pkgconfig cmake; do
  if ! port installed "$package" | grep -q "(active)"; then
    echo "Installing missing prerequisite: $package"
    sudo port install "$package"
  fi
done

# Create working and output directories.
mkdir -p "$FFMPEG_DIR" "$FLAC_DIR" "$BIN_DIR" "$PREFIX/txt"
}

function reset_and_update {
local repo="$1"
local file="$2"
local marker="$3"
local changed
local -a changed_files=()

if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: Not a Git repository: $repo"
  exit 1
fi

if ! git -C "$repo" diff --cached --quiet; then
  echo "ERROR: Staged changes found in $repo. Nothing has been changed."
  exit 1
fi

if [[ -n "$(git -C "$repo" ls-files --others --exclude-standard)" ]]; then
  echo "ERROR: Untracked files found in $repo. Nothing has been changed."
  git -C "$repo" status --short
  exit 1
fi

while IFS= read -r changed; do
  [[ -z "$changed" ]] && continue
  changed_files+=("$changed")
done < <(git -C "$repo" diff --name-only)

for changed in "${changed_files[@]}"; do
  if [[ "$changed" != "$file" ]]; then
    echo "ERROR: Unexpected modified file in $repo: $changed"
    git -C "$repo" status --short
    exit 1
  fi
done

if [[ ${#changed_files[@]} -gt 0 ]]; then
  if ! grep -Fq "$marker" "$repo/$file"; then
    echo "ERROR: The expected branding marker is missing from $repo/$file"
    exit 1
  fi

  echo "Removing local branding edit from $repo/$file..."
  git -C "$repo" restore -- "$file"
fi

if ! git -C "$repo" diff --quiet || ! git -C "$repo" diff --cached --quiet; then
  echo "ERROR: $repo is not clean after removing branding."
  git -C "$repo" status --short
  exit 1
fi

if ! git -C "$repo" symbolic-ref --quiet --short HEAD >/dev/null; then
  echo "ERROR: $repo is in detached-HEAD state."
  exit 1
fi

echo "Updating $repo..."
git -C "$repo" pull --ff-only
}

function build_flac {
# Download FLAC source
if [[ ! -d "$FLAC_DIR/.git" ]]; then
  git clone https://github.com/xiph/flac.git "$FLAC_DIR"
fi

reset_and_update "$FLAC_DIR" "src/libFLAC/format.c" "FLAC__VERSION_STRING = \"$VERSION_STRING\";"

cd "$FLAC_DIR"

if ! grep -Fq "FLAC__VERSION_STRING = \"$VERSION_STRING\";" src/libFLAC/format.c; then
  tmp="$(mktemp)"

  if ! awk -v version="$VERSION_STRING" '
    /^#if \(defined GIT_COMMIT_HASH && defined GIT_COMMIT_DATE\)$/ {
      printf "FLAC_API const char *FLAC__VERSION_STRING = \"%s\";\n", version
      printf "FLAC_API const char *FLAC__VENDOR_STRING = \"%s\";\n", version
      depth = 1
      patched = 1
      next
    }
  
    depth > 0 {
      if (/^[[:space:]]*#[[:space:]]*if(n?def)?([[:space:]]|$)/) depth++
      if (/^[[:space:]]*#[[:space:]]*endif([[:space:]]|$)/) depth--
      if (depth == 0) next
      next
    }
    { print }
    END { if (!patched || depth != 0) exit 2 }
    ' src/libFLAC/format.c > "$tmp"; then
    rm -f "$tmp"
    echo "ERROR: FLAC version-generation code has changed."
    exit 1
  fi

  mv "$tmp" src/libFLAC/format.c
fi

if [[ -f Makefile ]]; then
  echo "Cleaning FLAC build..."
  make distclean
fi

echo "Regenerating FLAC build files..."
./autogen.sh

echo "Configuring FLAC..."
./configure --prefix="$PREFIX" --bindir="$PREFIX/bin" --disable-shared --enable-static --disable-ogg --disable-version-from-git
echo "Building FLAC and metaflac..."
make -j"$JOBS"
}

function build_audiolibs {
# Static LAME (MP3), Ogg and Vorbis libraries, so ffmpeg can write MP3 and Ogg files without depending on any
# installed copies of them
rm -rf "$AUDIO_DIR" "$AUDIO_SRC"
mkdir -p "$AUDIO_DIR" "$AUDIO_SRC"
cd "$AUDIO_SRC"
curl -fL -o lame.tar.gz "https://downloads.sourceforge.net/project/lame/lame/$LAME_VERSION/lame-$LAME_VERSION.tar.gz"
curl -fL -o libogg.tar.gz "https://github.com/xiph/ogg/releases/download/v$OGG_VERSION/libogg-$OGG_VERSION.tar.gz"
curl -fL -o libvorbis.tar.gz "https://github.com/xiph/vorbis/releases/download/v$VORBIS_VERSION/libvorbis-$VORBIS_VERSION.tar.gz"
for f in lame libogg libvorbis; do tar -xzf "$f.tar.gz"; done

# These packages' own config.guess/config.sub predate some newer processors, so use automake's current copies
for d in "lame-$LAME_VERSION" "libogg-$OGG_VERSION" "libvorbis-$VORBIS_VERSION"; do
  cp -f "$(automake --print-libdir)/config.guess" "$(automake --print-libdir)/config.sub" "$d/"
done

# MacOS fixes, as Homebrew applies: LAME lists a function it doesn't have, and libvorbis uses a linker flag
# that current Apple tools reject
sed -i '' '/lame_init_old/d' "lame-$LAME_VERSION/include/libmp3lame.sym"
sed -i '' 's/ -force_cpusubtype_ALL//g' "libvorbis-$VORBIS_VERSION/configure"

echo "Building static LAME, Ogg and Vorbis libraries..."
cd "$AUDIO_SRC/lame-$LAME_VERSION"
./configure --prefix="$AUDIO_DIR" --disable-shared --enable-static --disable-frontend --disable-decoder >/dev/null
make -j"$JOBS" >/dev/null
make install >/dev/null

cd "$AUDIO_SRC/libogg-$OGG_VERSION"
./configure --prefix="$AUDIO_DIR" --disable-shared --enable-static >/dev/null
make -j"$JOBS" >/dev/null
make install >/dev/null

cd "$AUDIO_SRC/libvorbis-$VORBIS_VERSION"
./configure --prefix="$AUDIO_DIR" --disable-shared --enable-static --with-ogg="$AUDIO_DIR" --disable-docs --disable-examples --disable-oggtest >/dev/null
make -j"$JOBS" >/dev/null
make install >/dev/null
}

function build_ffmpeg {
if [[ ! -d "$FFMPEG_DIR/.git" ]]; then
  git clone https://git.ffmpeg.org/ffmpeg.git "$FFMPEG_DIR"
fi

reset_and_update "$FFMPEG_DIR" "ffbuild/version.sh" "version=$VERSION_STRING"

# Brand FFmpeg and ffprobe.
cd "$FFMPEG_DIR"

if ! grep -Fq "version=$VERSION_STRING" ffbuild/version.sh; then
  if ! grep -Fq 'version=$(cd "$1" && cat FF_VERSION 2> /dev/null)' ffbuild/version.sh; then
    echo "ERROR: FFmpeg version-generation logic has changed."
    exit 1
  fi

  sed -i '' "s|version=\$(cd \"\$1\" && cat FF_VERSION 2> /dev/null)|version=$VERSION_STRING|" ffbuild/version.sh
fi

if [[ -f ffbuild/config.mak ]]; then
  echo "Cleaning FFmpeg build..."
  make distclean
fi

echo "Configuring FFmpeg..."
PKG_CONFIG_LIBDIR="$AUDIO_DIR/lib/pkgconfig" ./configure --prefix="$PREFIX" --bindir="$PREFIX/bin" --disable-everything --enable-ffmpeg --enable-ffprobe --disable-ffplay --disable-sdl2 --disable-iconv --enable-static --disable-shared --disable-doc --disable-network --enable-protocol=file,pipe --enable-demuxer=concat,flac,ape,mov,mp3,ogg,asf,wav,aiff,dsf --enable-decoder=flac,ape,aac,alac,mp3,mp3float,vorbis,opus,wmav1,wmav2,wmapro,wmalossless,'pcm*',dsd_lsbf,dsd_msbf,dsd_lsbf_planar,dsd_msbf_planar,mjpeg,png --enable-parser=flac,mpegaudio,aac,vorbis,opus,mjpeg,png --enable-encoder=flac,libmp3lame,libvorbis,wmav2,pcm_s16le,pcm_s24le,pcm_s32le,pcm_s16be,pcm_s24be,pcm_s32be,png --enable-muxer=flac,mp3,ogg,asf,wav,aiff,md5,null,image2 --enable-filter=adelay,volume,volumedetect,aresample,aformat,lowpass,showspectrumpic,scale,format --enable-libmp3lame --enable-libvorbis --extra-cflags="-I$AUDIO_DIR/include" --extra-ldflags="-L$AUDIO_DIR/lib" --extra-libs="-lvorbis -logg -lm" --enable-outdev=audiotoolbox --disable-version-tracking

echo "Building FFmpeg and ffprobe..."
make -j"$JOBS"

# ffmpeg and ffprobe must use nothing but MacOS's own libraries: stop if they still point at Homebrew or MacPorts
if otool -L ffmpeg ffprobe | grep -E "/opt/homebrew|/usr/local/(opt|Cellar|lib)|/opt/local"; then
  echo "ERROR: ffmpeg or ffprobe still depends on the libraries listed above."
  exit 1
fi
}

function build_imagelibs {
# Static JPEG, PNG and FreeType libraries, built here so magick never depends on Homebrew's or MacPorts' copies
rm -rf "$LIBS_DIR" "$LIBS_SRC"
mkdir -p "$LIBS_DIR" "$LIBS_SRC"
cd "$LIBS_SRC"
git -c advice.detachedHead=false clone -q --depth 1 --branch 3.2.1 https://github.com/libjpeg-turbo/libjpeg-turbo.git
git -c advice.detachedHead=false clone -q --depth 1 --branch v1.6.59 https://github.com/pnggroup/libpng.git
git -c advice.detachedHead=false clone -q --depth 1 --branch VER-2-15-0 https://github.com/freetype/freetype.git

echo "Building static JPEG, PNG and FreeType libraries..."
cmake -S libjpeg-turbo -B libjpeg-turbo/build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$LIBS_DIR" -DCMAKE_INSTALL_LIBDIR=lib \
  -DENABLE_SHARED=OFF -DWITH_TURBOJPEG=OFF >/dev/null
cmake --build libjpeg-turbo/build -j"$JOBS" >/dev/null
cmake --install libjpeg-turbo/build >/dev/null

cmake -S libpng -B libpng/build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$LIBS_DIR" -DCMAKE_INSTALL_LIBDIR=lib \
  -DPNG_SHARED=OFF -DPNG_TESTS=OFF -DPNG_TOOLS=OFF -DPNG_FRAMEWORK=OFF >/dev/null
cmake --build libpng/build -j"$JOBS" >/dev/null
cmake --install libpng/build >/dev/null

cmake -S freetype -B freetype/build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$LIBS_DIR" -DCMAKE_INSTALL_LIBDIR=lib \
  -DBUILD_SHARED_LIBS=OFF -DFT_DISABLE_BZIP2=ON -DFT_DISABLE_PNG=ON -DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_BROTLI=ON -DFT_DISABLE_HVF=ON >/dev/null
cmake --build freetype/build -j"$JOBS" >/dev/null
cmake --install freetype/build >/dev/null

# zlib comes from MacOS itself. This entry makes pkg-config say so, rather than finding MacPorts' or Homebrew's copy.
cat > "$LIBS_DIR/lib/pkgconfig/zlib.pc" <<'ZLIBPC'
Name: zlib
Description: MacOS's own zlib
Version: 1.2.12
Libs: -lz
Cflags:
ZLIBPC
}

function build_magick {
# Download and build ImageMagick.
cd "$HOME"

curl -fL -O "https://download.imagemagick.org/archive/releases/$IMAGEMAGICK_ARCHIVE"
tar -xzf "$IMAGEMAGICK_ARCHIVE"
cd "$IMAGEMAGICK_DIR"

# Brand ImageMagick.
if ! grep -Fq "PACKAGE_VERSION='$VERSION_STRING'" configure; then
  if ! grep -Fq "PACKAGE_VERSION='$IMAGEMAGICK_VERSION'" configure; then
    echo "ERROR: ImageMagick package version definition has changed."
    exit 1
  fi
  sed -i '' "s|PACKAGE_VERSION='$IMAGEMAGICK_VERSION'|PACKAGE_VERSION='$VERSION_STRING'|" configure
fi

if ! grep -Fq "MAGICK_VERSION=$VERSION_STRING" configure; then
  if ! grep -Fq "MAGICK_VERSION=$IMAGEMAGICK_VERSION" configure; then
    echo "ERROR: ImageMagick library version definition has changed."
    exit 1
  fi
  sed -i '' "s|MAGICK_VERSION=$IMAGEMAGICK_VERSION|MAGICK_VERSION=$VERSION_STRING|" configure
fi

if ! grep -Fq "PACKAGE_STRING='ImageMagick $VERSION_STRING'" configure; then
  if ! grep -Fq "PACKAGE_STRING='ImageMagick $IMAGEMAGICK_VERSION'" configure; then
    echo "ERROR: ImageMagick package string definition has changed."
    exit 1
  fi
  sed -i '' "s|PACKAGE_STRING='ImageMagick $IMAGEMAGICK_VERSION'|PACKAGE_STRING='ImageMagick $VERSION_STRING'|" configure
fi

if ! grep -Fq 'MAGICK_LIB_VERSION_TEXT="bbritten-4.0.0"' configure; then
  if ! grep -Fq 'MAGICK_LIB_VERSION_TEXT="${PACKAGE_BASE_VERSION}"' configure; then
    echo "ERROR: ImageMagick library version text definition has changed."
    exit 1
  fi
  sed -i '' 's|MAGICK_LIB_VERSION_TEXT="${PACKAGE_BASE_VERSION}"|MAGICK_LIB_VERSION_TEXT="bbritten-4.0.0"|' configure
fi

echo "Configuring ImageMagick..."
PKG_CONFIG_LIBDIR="$LIBS_DIR/lib/pkgconfig" ./configure PKG_CONFIG="pkg-config --static" CPPFLAGS="-I$LIBS_DIR/include" LDFLAGS="-L$LIBS_DIR/lib" --prefix="$PREFIX" --disable-installed --disable-shared --enable-static --disable-openmp --without-fontconfig --without-gvc --without-xml --without-perl --without-magick-plus-plus --without-bzlib --without-dps --without-djvu --without-fftw --without-flif --without-fpx --without-gslib --without-heic --without-jbig --without-jxl --without-lcms --without-lqr --without-lzma --without-openexr --without-openjp2 --without-pango --without-raw --without-rsvg --without-tiff --without-webp --without-zip --without-zstd --without-video --without-x --with-jpeg --with-png --with-freetype

echo "Building ImageMagick..."
make -j"$JOBS"

# magick must use nothing but MacOS's own libraries: stop if it still points at Homebrew or MacPorts
if otool -L utilities/magick | grep -E "/opt/homebrew|/usr/local/(opt|Cellar|lib)|/opt/local"; then
  echo "ERROR: magick still depends on the libraries listed above."
  exit 1
fi
}

function build_sixel {
if [[ ! -d "$SIXEL_DIR/.git" ]]; then
  git clone https://github.com/saitoha/libsixel.git "$SIXEL_DIR"
fi

cd "$SIXEL_DIR"

# Brand libsixel.
if ! grep -Fq 'AC_INIT([sixel], [bbritten-4.0.0]' configure.ac; then
  if ! grep -Fq 'AC_INIT([sixel], [1.8.7-r2]' configure.ac; then
    echo "ERROR: libsixel package version definition has changed."
    exit 1
  fi

  sed -i '' 's|AC_INIT(\[sixel\], \[1.8.7-r2\]|AC_INIT([sixel], [bbritten-4.0.0]|' configure.ac
fi

echo "Regenerating libsixel build files..."
./autogen.sh

echo "Configuring libsixel..."
./configure --prefix="$PREFIX" --disable-shared --enable-static --disable-python --without-libcurl --without-gd --without-gdk-pixbuf2 --without-jpeg --without-png   # libsixel's own JPG/PNG reader: no JPEG or PNG libraries needed

echo "Building img2sixel..."
make -j"$JOBS"
}

function validate {
# Copy the compiled executables into the binary collection.
echo "Installing branded binaries into $BIN_DIR..."
# Each old binary is deleted first: copying over one MacOS has already run can make it kill the new one ("Killed: 9")
rm -f "$BIN_DIR/ffmpeg-macos-x86_64"; cp "$FFMPEG_DIR/ffmpeg" "$BIN_DIR/ffmpeg-macos-x86_64"
rm -f "$BIN_DIR/ffprobe-macos-x86_64"; cp "$FFMPEG_DIR/ffprobe" "$BIN_DIR/ffprobe-macos-x86_64"
rm -f "$BIN_DIR/flac-macos-x86_64"; cp "$FLAC_DIR/src/flac/flac" "$BIN_DIR/flac-macos-x86_64"
rm -f "$BIN_DIR/metaflac-macos-x86_64"; cp "$FLAC_DIR/src/metaflac/metaflac" "$BIN_DIR/metaflac-macos-x86_64"
rm -f "$BIN_DIR/magick-macos-x86_64"; cp "$IMAGEMAGICK_DIR/utilities/magick" "$BIN_DIR/magick-macos-x86_64"
cp "$IMAGEMAGICK_DIR/config/colors.xml" "$PREFIX/txt/"
cp "$IMAGEMAGICK_DIR/config/configure.xml" "$PREFIX/txt/"
rm -f "$BIN_DIR/img2sixel-macos-x86_64"; cp "$SIXEL_DIR/converters/img2sixel" "$BIN_DIR/img2sixel-macos-x86_64"

chmod 755 "$BIN_DIR/ffmpeg-macos-x86_64" "$BIN_DIR/ffprobe-macos-x86_64" "$BIN_DIR/flac-macos-x86_64" "$BIN_DIR/metaflac-macos-x86_64" "$BIN_DIR/magick-macos-x86_64" "$BIN_DIR/img2sixel-macos-x86_64"

echo
echo "=== Rebuilt versions ==="
"$BIN_DIR/ffmpeg-macos-x86_64" -version | sed -n '1p'
"$BIN_DIR/ffprobe-macos-x86_64" -version | sed -n '1p'
"$BIN_DIR/flac-macos-x86_64" --version
"$BIN_DIR/metaflac-macos-x86_64" --version
"$BIN_DIR/magick-macos-x86_64" -version | sed -n '1p'
"$BIN_DIR/img2sixel-macos-x86_64" --version

if "$BIN_DIR/ffmpeg-macos-x86_64" -version | grep -Fq "version $VERSION_STRING" &&
  "$BIN_DIR/ffmpeg-macos-x86_64" -hide_banner -encoders | grep -q libmp3lame &&
  "$BIN_DIR/ffmpeg-macos-x86_64" -hide_banner -encoders | grep -q libvorbis &&
  "$BIN_DIR/ffprobe-macos-x86_64" -version | grep -Fq "version $VERSION_STRING" &&
  "$BIN_DIR/flac-macos-x86_64" --version | grep -Fq "flac $VERSION_STRING" &&
  "$BIN_DIR/metaflac-macos-x86_64" --version | grep -Fq "metaflac $VERSION_STRING" &&
  "$BIN_DIR/magick-macos-x86_64" -version | grep -Fq "ImageMagick $VERSION_STRING" &&
  "$BIN_DIR/img2sixel-macos-x86_64" --version | grep -Fq "img2sixel $VERSION_STRING"; then
  echo
  echo "All binaries rebuilt and verified successfully."
  echo "Removing source repositories..."
  rm -rf "$FFMPEG_DIR" "$FLAC_DIR" "$IMAGEMAGICK_DIR" "$SIXEL_DIR" "$LIBS_DIR" "$LIBS_SRC" "$AUDIO_DIR" "$AUDIO_SRC"
  rm -f "$HOME/$IMAGEMAGICK_ARCHIVE"
  echo "Source repositories removed."
else
  echo "ERROR: Binary verification failed. Source repositories retained."
  exit 1
fi
}

function main {
prebuild
build_flac
build_audiolibs
build_ffmpeg
build_imagelibs
build_magick
build_sixel
validate
}

main