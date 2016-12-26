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
