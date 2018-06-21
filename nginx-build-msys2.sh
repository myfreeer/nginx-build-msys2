#!/bin/bash

# init
machine_str="$(gcc -dumpmachine | cut -d'-' -f1)"

# dep versions
ZLIB="zlib-1.2.11"
PCRE="pcre-8.42"
OPENSSL="openssl-1.1.0h"

# download
git clone https://github.com/nginx/nginx --depth=1
cd nginx
wget -c "https://download.sourceforge.net/libpng/${ZLIB}.tar.gz"
tar -xf "${ZLIB}.tar.gz"
wget -c "https://ftp.pcre.org/pub/pcre/${PCRE}.tar.bz2"
tar -xf "${PCRE}.tar.bz2"
wget -c "https://www.openssl.org/source/${OPENSSL}.tar.gz"
tar -xf "${OPENSSL}.tar.gz"

# configure
configure_args=(
    --sbin-path=nginx.exe \
    --http-client-body-temp-path=temp/client_body \
    --http-proxy-temp-path=temp/proxy \
    --http-fastcgi-temp-path=temp/fastcgi \
    --http-scgi-temp-path=temp/scgi \
    --http-uwsgi-temp-path=temp/uwsgi \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_auth_request_module \
    --with-http_stub_status_module \
    --with-mail \
    --with-select_module \
    --with-stream \
    --with-pcre=${PCRE} \
    --with-pcre-jit \
    --with-zlib=${ZLIB} \
    --with-openssl=${OPENSSL} \
    --with-http_ssl_module \
    --with-mail_ssl_module \
    --with-stream_ssl_module \
    --with-http_v2_module \
    --prefix=
)

auto/configure ${configure_args[@]}

# build
make -j$(nproc)
strip -s objs/nginx.exe
version="$(objs/nginx.exe 2>&1 | cut -d'/' -f2)"
mv -f "objs/nginx.exe" "../nginx-${version}-${machine_str}.exe"

# re-configure with debugging log
configure_args+=(--with-debug)
auto/configure ${configure_args[@]}

# re-build with debugging log
make -j$(nproc)
version="$(objs/nginx.exe 2>&1 | cut -d'/' -f2)"
mv -f "objs/nginx.exe" "../nginx-${version}-${machine_str}-debug.exe"

cd ..