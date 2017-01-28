# mldonkey
crosscompile from cygwin to windows executables (32)

1) there is a problem in latest ocaml version. 
2) Using **nano** or **Notepad++** for CRLF line endings problem. Pay attention to this.

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
export PATH=/mingw/bin:/usr/i686-w64-mingw32/bin:/usr/local/bin:/usr/bin:/usr/lib/gcc/i686-w64-mingw32/5.4.0:/cygdrive/c/ocamlmgw/bin
export CC=/usr/bin/i686-w64-mingw32-gcc
export CXX=/usr/bin/i686-w64-mingw32-g++
export PKG_CONFIG_PATH=/mingw/lib/pkgconfig
```

### 2) Installing ZLIB
```
wget http://zlib.net/zlib-1.2.11.tar.gz
tar xzvf zlib-1.2.11.tar.gz
cd zlib-1.2.11
nano win32/Makefile.gcc
```
Change **CC = $(PREFIX)gcc** in
```
CC=/usr/bin/i686-w64-mingw32-gcc
```
Change **RC = $(PREFIX)windres** (line 57) in
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
Change **CC=gcc** (line 18) in
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
Change **RC=windres** (line 34) in
```
RC=i686-w64-mingw32-windres
```
execute
```
nano src/Makefile
```
change **WINDRES = windres** (line 30) in
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
wget ftp://ftp.simplesystems.org/pub/libpng/png/src/libpng16/libpng-1.6.28.tar.gz
tar xzvf libpng-1.6.28.tar.gz
cd libpng-1.6.28
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
(still have some problems crosscompiling this)
```
./bootstrap.sh
./configure --build=i686-w64-mingw32 --prefix=/mingw LIBS="-lbz2 -ljpeg -lws2_32 -liconv"
```
execute
```
make
```

### 9) Installing REGEX
```
wget https://ftp.gnu.org/old-gnu/regex/regex-0.12.tar.gz
tar xzvf regex-0.12.tar.gz
cd regex-0.12
i686-w64-mingw32-gcc -DSTDC_HEADERS -DHAVE_STRING_H=1 -I. -c regex.c
ar ru libregex.a regex.o
cp -iv libregex.a /mingw/lib
cp -iv libregex.a /mingw/lib/libgnurx.a
cp -iv regex.h /mingw/include
```

### 10) Installing FILE - libmagic
latest source on github: https://github.com/file/file.git

```
libtoolize --force
aclocal
autoheader
automake --force-missing --add-missing
autoconf
./configure --build=i686-w64-mingw32 --prefix=/mingw
nano config.h
```
add the following lines:
```
#define WIN32 1
#ifndef MAGIC
#define MAGIC "magic"
#endif
```
execute
```
make
make install
```

### 11) Installing OCAML
latest source on github: https://github.com/ocaml/ocaml.git
execute (will install in **C:/ocamlmgw** )
(git checkout d2281a23770b68300351b0d40ff48e2b92db6683
edit of 27/12/2016)
```
cp config/m-nt.h config/m.h
cp config/s-nt.h config/s.h
cp config/Makefile.mingw config/Makefile
make -f Makefile.nt flexdll world bootstrap opt opt.opt install
```

### 12) Installing OCAMLBUILD
that's necessary only on certain OCAML versions (?)
latest sources on github: https://github.com/ocaml/ocamlbuild.git
```
make configure
make
make install
```

### 13) Installing CAMLP4
latest sources on github: https://github.com/ocaml/camlp4.git
(git checkout 9020330105b28f0d6ef088665632df681fb7a412)
```
./configure
make all
make install
nano ~/.bashrc
```
append:
```
export CAMLP4LIB=C:/ocamlmgw/lib/camlp4
```

### 14) Compile MLDONKEY
```
./configure --build=i686-w64-mingw32 --prefix=/mingw --disable-fasttrack
make depend
make
```

windres should be changed in i686-w64-mingw32-windres -o resfile.o config/mldonkey.rc

### recompile MLDONKEY
```
make clean
make
```