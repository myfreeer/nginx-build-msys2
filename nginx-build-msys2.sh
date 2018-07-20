#!/bin/bash

# init
machine_str="$(gcc -dumpmachine | cut -d'-' -f1)"

# workaround git user name and email not set
GIT_USER_NAME="$(git config --global user.name)"
GIT_USER_EMAIL="$(git config --global user.email)"
if [[ "${GIT_USER_NAME}" = "" ]]; then
    git config --global user.name "Build Bot"
fi
if [[ "${GIT_USER_EMAIL}" = "" ]]; then
    git config --global user.email "you@example.com"
fi

# dep versions
ZLIB="zlib-1.2.11"
PCRE="pcre-8.42"
OPENSSL="openssl-1.1.0h"

# clone and patch nginx
if [[ -d nginx ]]; then
    cd nginx
    git checkout master
    git reset --hard origin || git reset --hard
    git pull
else
    git clone https://github.com/nginx/nginx.git --depth=1 --config http.sslVerify=false
    cd nginx
fi
git checkout -b patch
git am -3 ../nginx-*.patch

# download deps
wget -c -nv "https://download.sourceforge.net/libpng/${ZLIB}.tar.gz"
tar -xf "${ZLIB}.tar.gz"
wget -c -nv "https://ftp.pcre.org/pub/pcre/${PCRE}.tar.bz2"
tar -xf "${PCRE}.tar.bz2"
wget -c -nv "https://www.openssl.org/source/${OPENSSL}.tar.gz"
tar -xf "${OPENSSL}.tar.gz"

# configure
configure_args=(
    --sbin-path=nginx.exe \
    --http-client-body-temp-path=temp/client_body \
    --http-proxy-temp-path=temp/proxy \
    --http-fastcgi-temp-path=temp/fastcgi \
    --http-scgi-temp-path=temp/scgi \
    --http-uwsgi-temp-path=temp/uwsgi \
    --with-select_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_stub_status_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_auth_request_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-mail \
    --with-stream \
    --with-pcre=${PCRE} \
    --with-pcre-jit \
    --with-zlib=${ZLIB} \
    --with-openssl=${OPENSSL} \
    --with-http_ssl_module \
    --with-mail_ssl_module \
    --with-stream_ssl_module \
    --with-cc-opt='-O2 -pipe -Wall' \
    --with-ld-opt='-Wl,--gc-sections,--build-id=none' \
    --prefix=
)

auto/configure ${configure_args[@]}

# build
make -j$(nproc)
strip -s objs/nginx.exe
version="$(cat src/core/nginx.h | grep NGINX_VERSION | grep -ioP '((\d+\.)+\d)')"
mv -f "objs/nginx.exe" "../nginx-${version}-${machine_str}.exe"

# re-configure with debugging log
configure_args+=(--with-debug)
auto/configure ${configure_args[@]}

# re-build with debugging log
make -j$(nproc)
mv -f "objs/nginx.exe" "../nginx-${version}-${machine_str}-debug.exe"

# clean up
git checkout master
git branch patch -D
cd ..
