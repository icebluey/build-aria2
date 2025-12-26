#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

umask 022

LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now'
export LDFLAGS
_ORIG_LDFLAGS="${LDFLAGS}"

CC=gcc
export CC
CXX=g++
export CXX
/sbin/ldconfig

_private_dir='usr/lib64/aria2/private'

set -euo pipefail

_strip_files() {
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
    fi
    echo
}


_build_zlib() {
    /sbin/ldconfig
    set -euo pipefail
    local _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _zlib_ver="$(wget -qO- 'https://www.zlib.net/' | grep -io 'href="[^"]*\.tar\.gz"' | sed 's/href="//I;s/"//' | grep -i '^zlib-[0-9]' | sed 's/zlib-\(.*\)\.tar\.gz/\1/' | sort -V | tail -n1)"
    wget -c -t 9 -T 9 "https://www.zlib.net/zlib-${_zlib_ver}.tar.gz"
    tar -xof zlib-*.tar*
    rm -f zlib-*.tar*
    cd zlib-*
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"; export LDFLAGS
    ./configure --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --64
    make -j$(nproc --all) all
    rm -fr /tmp/zlib
    make DESTDIR=/tmp/zlib install
    cd /tmp/zlib
    _strip_files
    install -m 0755 -d "${_private_dir}"
    /bin/cp -af usr/lib64/*.so* "${_private_dir}"/
    /bin/rm -f /usr/lib64/libz.so*
    /bin/rm -f /usr/lib64/libz.a
    /bin/cp -afr * /
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/zlib
    /sbin/ldconfig
}

_build_sqlite() {
    /sbin/ldconfig
    set -euo pipefail
    local _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _sqlite_path="$(wget -qO- 'https://www.sqlite.org/download.html' | grep -i '20[2-9][4-9]/sqlite-autoconf-[1-9]' | sed 's|,|\n|g' | grep -i '^20[2-9][4-9]/sqlite-autoconf-[1-9]')"
    wget -c -t 9 -T 9 "https://www.sqlite.org/${_sqlite_path}"
    tar -xof sqlite-*.tar*
    sleep 1
    rm -f sqlite-*.tar*
    cd sqlite-*
    sed 's|http://|https://|g' -i configure shell.c sqlite3.1 sqlite3.c sqlite3.h sqlite3.rc
    sed 's|^LDFLAGS.rpath = .*|LDFLAGS.rpath =|g' -i Makefile.in
    #LDFLAGS='' ; LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --all --enable-math --enable-json --enable-load-extension \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    make -j$(nproc --all) all
    rm -fr /tmp/sqlite
    make install DESTDIR=/tmp/sqlite
    cd /tmp/sqlite
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib64/*.so* "${_private_dir}"/
    rm -f /usr/lib64/libsqlite3.*
    sleep 1
    /bin/cp -afr * /
    sleep 1
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/sqlite
    /sbin/ldconfig
}

rm -fr /usr/lib64/aria2/private
_build_zlib
_build_sqlite
###############################################################################

_build_brotli() {
    /sbin/ldconfig
    set -euo pipefail
    local _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    git clone --recursive 'https://github.com/google/brotli.git' brotli
    cd brotli
    rm -fr .git
    if [[ -f bootstrap ]]; then
        ./bootstrap
        rm -fr autom4te.cache
        LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,--disable-new-dtags -Wl,-rpath,\$$ORIGIN'; export LDFLAGS
        ./configure \
        --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
        --enable-shared --disable-static \
        --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
        make -j$(nproc --all) all
        rm -fr /tmp/brotli
        make install DESTDIR=/tmp/brotli
    else
        LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,--disable-new-dtags -Wl,-rpath,\$ORIGIN'; export LDFLAGS
        cmake \
        -S "." \
        -B "build" \
        -DCMAKE_BUILD_TYPE='Release' \
        -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
        -DCMAKE_INSTALL_PREFIX:PATH=/usr \
        -DINCLUDE_INSTALL_DIR:PATH=/usr/include \
        -DLIB_INSTALL_DIR:PATH=/usr/lib64 \
        -DSYSCONF_INSTALL_DIR:PATH=/etc \
        -DSHARE_INSTALL_PREFIX:PATH=/usr/share \
        -DLIB_SUFFIX=64 \
        -DBUILD_SHARED_LIBS:BOOL=ON \
        -DCMAKE_INSTALL_SO_NO_EXE:INTERNAL=0
        cmake --build "build" --parallel $(nproc --all) --verbose
        rm -fr /tmp/brotli
        DESTDIR="/tmp/brotli" cmake --install "build"
    fi
    cd /tmp/brotli
    _strip_files
    install -m 0755 -d "${_private_dir}"
    /bin/cp -af usr/lib64/*.so* "${_private_dir}"/
    /bin/cp -afr * /
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/brotli
    /sbin/ldconfig
}
_build_brotli
###############################################################################

_build_zstd() {
    /sbin/ldconfig
    set -euo pipefail
    local _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    git clone --recursive "https://github.com/facebook/zstd.git"
    cd zstd
    rm -fr .git
    sed '/^PREFIX/s|= .*|= /usr|g' -i Makefile
    sed '/^LIBDIR/s|= .*|= /usr/lib64|g' -i Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i Makefile
    sed '/^libdir/s|= .*|= /usr/lib64|g' -i Makefile
    sed '/^PREFIX/s|= .*|= /usr|g' -i lib/Makefile
    sed '/^LIBDIR/s|= .*|= /usr/lib64|g' -i lib/Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i lib/Makefile
    sed '/^libdir/s|= .*|= /usr/lib64|g' -i lib/Makefile
    sed '/^PREFIX/s|= .*|= /usr|g' -i programs/Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i programs/Makefile
    #LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,--disable-new-dtags -Wl,-rpath,\$$OOORIGIN'; export LDFLAGS
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"; export LDFLAGS
    make -j$(nproc --all) V=1 prefix=/usr libdir=/usr/lib64 -C lib lib-mt
    # build bin
    #LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"; export LDFLAGS
    #make -j$(nproc --all) V=1 prefix=/usr libdir=/usr/lib64 -C programs
    #make -j$(nproc --all) V=1 prefix=/usr libdir=/usr/lib64 -C contrib/pzstd
    rm -fr /tmp/zstd
    make install DESTDIR=/tmp/zstd -C lib
    #make install DESTDIR=/tmp/zstd
    #install -v -c -m 0755 contrib/pzstd/pzstd /tmp/zstd/usr/bin/
    cd /tmp/zstd
    #ln -svf zstd.1 usr/share/man/man1/pzstd.1
    _strip_files
    #find usr/lib64/ -type f -iname '*.so*' | xargs -I '{}' patchelf --force-rpath --set-rpath '$ORIGIN' '{}'
    install -m 0755 -d "${_private_dir}"
    /bin/cp -af usr/lib64/*.so* "${_private_dir}"/
    rm -f /usr/lib64/libzstd.*
    /bin/cp -afr * /
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/zstd
    /sbin/ldconfig
}
_build_zstd
###############################################################################

# _tmp_dir="$(mktemp -d)"
# cd "${_tmp_dir}"
# gmp_ver="$(wget -qO- 'https://ftp.gnu.org/gnu/gmp/' | grep -i 'href=' | sed -e 's|"|\n|g' | grep -i '^gmp-[1-9].*\.tar.xz$' | sed -e 's|gmp-||g' -e 's|\.tar.*||g' | sort -V | tail -n 1)"
# wget -c -t 9 -T 9 "https://ftp.gnu.org/gnu/gmp/gmp-${gmp_ver}.tar.xz"
# tar -xof gmp-*.tar*
# sleep 1
# rm -f gmp-*.tar*
# cd gmp-*
# LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"; export LDFLAGS
# ./configure --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
# --enable-shared --enable-static \
# --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
# make -j$(nproc --all) all
# rm -fr /tmp/gmp
# make install DESTDIR=/tmp/gmp
# cd /tmp/gmp
# _strip_files
# install -m 0755 -d "${_private_dir}"
# cp -af usr/lib64/*.so* "${_private_dir}"/
# sleep 1
# cp -afr * /
# sleep 1
# cd /tmp
# rm -fr "${_tmp_dir}"
# rm -fr /tmp/gmp
# /sbin/ldconfig
###############################################################################

# _tmp_dir="$(mktemp -d)"
# cd "${_tmp_dir}"
# for i in libgpg-error; do
#     _tarname=$(wget -qO- https://gnupg.org/ftp/gcrypt/${i}/ | sed -n 's/.*href="\([^"]*\.tar\.bz2\)".*/\1/p' | grep -v -- '-qt' | sort -V | tail -1)
#     [[ -n "$_tarname" ]] && wget -c -t 9 -T 9 "https://gnupg.org/ftp/gcrypt/${i}/${_tarname}"
# done
# _libgcrypt_tarname="$(wget -qO- https://gnupg.org/ftp/gcrypt/libgcrypt/ | sed -n 's/.*href="\([^"]*\.tar\.bz2\)".*/\1/p' | grep -v -- '-qt' | sort -V | tail -1)"
# wget -c -t 9 -T 9 "https://gnupg.org/ftp/gcrypt/libgcrypt/${_libgcrypt_tarname}"
# sleep 1
# ls -1 *.tar* | xargs -I '{}' tar -xof '{}'
# sleep 1
# rm -f *.tar*

# cd libgpg-error-*
# LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"; export LDFLAGS
# ./configure --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
# --enable-shared --enable-static \
# --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
# make -j$(nproc --all) all
# rm -fr /tmp/libgpg-error
# make install DESTDIR=/tmp/libgpg-error
# cd /tmp/libgpg-error
# _strip_files
# install -m 0755 -d "${_private_dir}"
# cp -af usr/lib64/*.so* "${_private_dir}"/
# sleep 1
# /bin/cp -afr * /
# sleep 1
# cd /tmp
# rm -fr /tmp/libgpg-error
# /sbin/ldconfig
# cd "${_tmp_dir}"
# rm -fr libgpg-error-*
# /sbin/ldconfig

# cd libgcrypt-*
# LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,--disable-new-dtags -Wl,-rpath,\$$ORIGIN'; export LDFLAGS
# ./configure --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
# --enable-shared --enable-static \
# --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
# make -j$(nproc --all) all
# rm -fr /tmp/libgcrypt
# make install DESTDIR=/tmp/libgcrypt
# cd /tmp/libgcrypt
# _strip_files
# install -m 0755 -d "${_private_dir}"
# cp -af usr/lib64/*.so* "${_private_dir}"/
# sleep 1
# /bin/cp -afr * /
# sleep 1
# cd /tmp
# rm -fr /tmp/libgcrypt
# /sbin/ldconfig
# cd "${_tmp_dir}"
# rm -fr libgcrypt-*

# cd /tmp
# rm -fr "${_tmp_dir}"
# /sbin/ldconfig
###############################################################################

_build_xz() {
    /sbin/ldconfig
    set -euo pipefail
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _xz_ver="$(wget -qO- 'https://github.com/tukaani-project/xz/releases' | grep -i '/tukaani-project/xz/releases/download/v[1-9]' | sed 's| |\n|g' | grep -i '/tukaani-project/xz/releases/download/v' | sed -e 's|.*/xz-||g' -e 's|"||g' | grep -ivE 'alpha|beta|rc|win' | sed 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/tukaani-project/xz/releases/download/v${_xz_ver}/xz-${_xz_ver}.tar.gz"
    tar -xof xz-*.tar*
    rm -f xz-*.tar*
    cd xz-*
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,--disable-new-dtags -Wl,-rpath,\$$ORIGIN'; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --enable-threads=yes --enable-year2038 \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    make -j$(nproc --all) all
    rm -fr /tmp/xz
    make install DESTDIR=/tmp/xz
    cd /tmp/xz
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib64/*.so* "${_private_dir}"/
    /bin/cp -afr * /
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/xz
    /sbin/ldconfig
}
#_build_xz
###############################################################################

_build_libxml2() {
    /sbin/ldconfig
    set -euo pipefail
    local _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _libxml2_ver="$(wget -qO- 'https://gitlab.gnome.org/GNOME/libxml2/-/tags' | grep '\.tar\.' | sed -e 's|"|\n|g' -e 's|/|\n|g' | grep -i '^libxml2-.*\.tar\..*' | grep -ivE 'alpha|beta|rc[1-9]' | sed -e 's|.*libxml2-v||g' -e 's|\.tar.*||g' | grep '^[1-9]' | sort -V | tail -n 1)"
    wget -c -t 9 -T 9 "https://download.gnome.org/sources/libxml2/${_libxml2_ver%.*}/libxml2-${_libxml2_ver}.tar.xz"
    tar -xof libxml2-*.tar*
    rm -f libxml2-*.tar*
    cd libxml2-*
    find doc -type f -executable -print -exec chmod 0644 {} ';'
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,--disable-new-dtags -Wl,-rpath,\$$ORIGIN'; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --with-legacy --with-ftp --with-xptr-locs --without-python \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    sed 's|^hardcode_libdir_flag_spec=.*|hardcode_libdir_flag_spec=""|g' -i libtool
    make -j$(nproc --all) all
    rm -fr /tmp/libxml2
    make install DESTDIR=/tmp/libxml2
    cd /tmp/libxml2
    rm -fr usr/share/doc
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib64/*.so* "${_private_dir}"/
    #rm -f /usr/lib64/libxml2.*
    /bin/cp -afr * /
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libxml2
    /sbin/ldconfig
}
_build_libxml2
###############################################################################

_build_cares() {
    /sbin/ldconfig
    set -euo pipefail
    local _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _cares_ver="$(wget -qO- 'https://github.com/c-ares/c-ares/releases' | grep -i 'href="/c-ares/c-ares/releases/tag/v[1-9]' | sed 's|"|\n|g' | grep -i '^/c-ares/c-ares/releases/tag/v[1-9]' | sed 's|.*/v||g' | sort -V | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/c-ares/c-ares/releases/download/v${_cares_ver}/c-ares-${_cares_ver}.tar.gz"
    tar -xof c-ares-*.tar*
    rm -f c-ares-*.tar*
    cd c-ares-*
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,--disable-new-dtags -Wl,-rpath,\$$ORIGIN'; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --enable-largefile --with-random=/dev/urandom \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    make -j$(nproc --all) all
    rm -fr /tmp/cares
    make install DESTDIR=/tmp/cares
    cd /tmp/cares
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib64/*.so* "${_private_dir}"/
    /bin/cp -afr * /
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/cares
    /sbin/ldconfig
}
_build_cares
###############################################################################

_build_openssl35() {
    /sbin/ldconfig
    set -euo pipefail
    local _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _openssl35_ver="$(wget -qO- 'https://openssl-library.org/source/index.html' | grep 'openssl-3\.5\.' | sed 's|"|\n|g' | sed 's|/|\n|g' | grep -i '^openssl-3\.5\..*\.tar\.gz$' | cut -d- -f2 | sed 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 https://github.com/openssl/openssl/releases/download/openssl-${_openssl35_ver}/openssl-${_openssl35_ver}.tar.gz
    tar -xof openssl-*.tar*
    rm -f openssl-*.tar*
    cd openssl-*
    sed '/install_docs:/s| install_html_docs||g' -i Configurations/unix-Makefile.tmpl
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,--disable-new-dtags -Wl,-rpath,\$$ORIGIN'; export LDFLAGS
    HASHBANGPERL=/usr/bin/perl
    ./Configure \
    --prefix=/usr \
    --libdir=/usr/lib64 \
    --openssldir=/etc/pki/tls \
    enable-zlib enable-zstd enable-brotli \
    enable-argon2 enable-tls1_3 threads \
    enable-camellia enable-seed \
    enable-rfc3779 enable-sctp enable-cms \
    enable-ec enable-ecdh enable-ecdsa \
    enable-ec_nistp_64_gcc_128 \
    enable-poly1305 enable-ktls enable-quic \
    enable-ml-kem enable-ml-dsa enable-slh-dsa \
    enable-md2 enable-rc5 \
    no-mdc2 no-ec2m \
    no-sm2 no-sm2-precomp no-sm3 no-sm4 \
    shared linux-x86_64 '-DDEVRANDOM="\"/dev/urandom\""'
    perl configdata.pm --dump
    make -j$(nproc --all) all
    rm -fr /tmp/openssl35
    make DESTDIR=/tmp/openssl35 install_sw
    cd /tmp/openssl35
    sed 's|http://|https://|g' -i usr/lib64/pkgconfig/*.pc
    _strip_files
    install -m 0755 -d "${_private_dir}"
    /bin/cp -af usr/lib64/*.so* "${_private_dir}"/
    rm -fr /usr/include/openssl
    rm -fr /usr/include/x86_64-linux-gnu/openssl
    /bin/cp -afr * /
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/openssl35
    /sbin/ldconfig
}
_build_openssl35
###############################################################################

_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"
#wget -c -t 9 -T 9 "https://github.com/aria2/aria2/releases/download/release-1.37.0/aria2-1.37.0.tar.xz"
#tar -xof aria2-*.tar*
#sleep 1
#rm -f aria2-*.tar*

git clone 'https://github.com/aria2/aria2.git'

LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"; export LDFLAGS

cd aria2*
autoreconf -ivf
./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --prefix=/opt/aria2 --libdir=/opt/aria2/lib64

make -j$(nproc --all) all
make install DESTDIR=/tmp/aria2

cd /tmp/aria2
mkdir opt/aria2/lib64
cp -afr /usr/lib64/aria2/private opt/aria2/lib64/
strip opt/aria2/bin/aria2c
sleep 1
patchelf --force-rpath --set-rpath '$ORIGIN/../lib64/private' opt/aria2/bin/aria2c
sleep 1
_aria2_ver=$(./opt/aria2/bin/aria2c --version 2>&1 | grep -i 'aria2 version' | awk '{print $3}')

rm -fr /tmp/_output
mkdir /tmp/_output

cd opt
echo
tar -Jcvf /tmp/_output/aria2-${_aria2_ver}-1_el9_amd64.tar.xz *
echo
sleep 1
cd /tmp/_output
openssl dgst -r -sha256 aria2-${_aria2_ver}-1_el9_amd64.tar.xz | sed 's|\*| |g' > aria2-${_aria2_ver}-1_el9_amd64.tar.xz.sha256

cd /tmp
rm -fr "${_tmp_dir}"
rm -fr /tmp/aria2

###############################################################################
echo
echo ' done'
exit
