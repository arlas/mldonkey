# mldonkey
crosscompile from cygwin to windows executables (32)

Using **nano** or **Notepad++** for CRLF line endings problem. Pay attention to this.

## Installing

### 1) Installing Cygwin
Install Cygwin by running [Setup](https://www.cygwin.com/setup-x86.exe)

Install the following packages (View full):
```
automake
bison
curl
dos2unix
flexdll
gettext-devel
git
libintl-devel
libreadline-devel
libtool
libX11-devel
make
m4
mingw64-i686-binutils
mingw64-i686-gcc-core
mingw64-i686-gcc-fortran
mingw64-i686-gcc-g++
mingw64-i686-gmp
mingw64-i686-openssl
mingw64-i686-pkg-config
mingw64-i686-sqlite3
	/* for 64 bit:
	mingw64-x86_64-gcc-core
	mingw64-x86_64-gmp
	mingw64-x86_64-openssl
	mingw64-x86_64-pkg-config
	mingw64-x86_64-sqlite3
	*/
nano
patch
pkg-config
rlwrap
rsync
unzip
wget
```
execute
```
nano c:/cygwin/etc/fstab
```
**append the following line:**
```
/usr/i686-w64-mingw32/sys-root/mingw /mingw none bind
```
>c:/users/alas /alas none bind

execute
```
nano ~/.bashrc
```
append (check your version)
```
export PATH=/mingw/bin:/usr/i686-w64-mingw32/bin:/usr/local/bin:/usr/bin:/usr/lib/gcc/i686-w64-mingw32/5.4.0
export CC=/usr/bin/i686-w64-mingw32-gcc
export CXX=/usr/bin/i686-w64-mingw32-g++
export PKG_CONFIG_PATH=/mingw/lib/pkgconfig
```

### 2) Installing ZLIB
```
wget http://zlib.net/zlib-1.2.8.tar.gz
tar xzvf zlib-1.2.8.tar.gz
cd zlib-1.2.8
nano win32/Makefile.gcc
```
Change **CC = $(PREFIX)gcc** in
```
CC=/usr/bin/i686-w64-mingw32-gcc
```
Change **RC = $(PREFIX)windres** in
```
RC = i686-w64-mingw32-windres
```
execute
```
make -fwin32/Makefile.gcc
cp -iv zlib1.dll /mingw/bin
cp -iv zconf.h zlib.h /mingw/include
cp -iv libz.a /mingw/lib
cp -iv libz.dll.a /mingw/lib
```
### 3) Installing BZIP2
```
wget http://bzip.org/1.0.6/bzip2-1.0.6.tar.gz
tar xzvf bzip2-1.0.6.tar.gz
cd bzip2-1.0.6
nano bzlib.h
```
Change line 78 **#ifdef _WIN32** in
```
#if defined(_WIN32) && !defined(__MINGW32__)
```
execute
```
nano Makefile
```
Change **CC=gcc** in
```
CC=/usr/bin/i686-w64-mingw32-gcc
```
execute
```
make
cp bzlib.h /mingw/include/
cp libbz2.a /mingw/lib
```
### 4) Installing LIBICONV
```
wget http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.14.tar.gz
tar xzvf libiconv-1.14.tar.gz
cd libiconv-1.14
./configure --build=i686-w64-mingw32 --prefix=/mingw --enable-static
nano lib/Makefile
```
Change **RC=windres** in
```
RC=i686-w64-mingw32-windres
```
execute
```
nano src/Makefile
```
change **WINDRES = windres** in
```
WINDRES = i686-w64-mingw32-windres
```
execute
```
make
make install
```
### 5) Installing JPEG
```
wget http://www.ijg.org/files/jpegsrc.v9b.tar.gz
tar xzvf jpegsrc.v9b.tar.gz
cd jpeg-9b
./configure --build=i686-w64-mingw32 --prefix=/mingw
make
make install
```
### 6) Installing LIBPNG
```
wget ftp://ftp.simplesystems.org/pub/libpng/png/src/libpng16/libpng-1.6.26.tar.gz
tar xzvf libpng-1.6.26.tar.gz
cd libpng-1.6.26
./configure --build=i686-w64-mingw32 --prefix=/mingw
make
make install
```
### 7) Installing FREETYPE
```
wget https://download.savannah.gnu.org/releases/freetype/freetype-2.7.tar.gz
tar xzvf freetype-2.7.tar.gz
cd freetype-2.7
./configure --build=i686-w64-mingw32 --prefix=/mingw
nano builds/exports.mk
```
Change
```
U2W := `cygpath -w %`
$(EXPORTS_LIST): $(APINAMES_EXE) $(PUBLIC_HEADERS)
          $(subst /,$(SEP),$(APINAMES_EXE)) \
          -o$(patsubst %,$(U2W),$@ $(APINAMES_OPTIONS) $(PUBLIC_HEADERS))
          @echo TT_New_Context >> $(EXPORTS_LIST)
          @echo TT_RunIns >> $(EXPORTS_LIST)
```
execute
```
make
make install
```
### 8) Installing GD Graphics Library
```
./bootstrap.sh
./configure --build=i686-w64-mingw32 --prefix=/mingw LIBS="-lbz2 -ljpeg -lws2_32 -liconv"
```
execute
```
make
```
