#!/bin/bash

# cmd line switches
for i in "$@"
do
  case $i in
    -t=*|--tag=*)
      NGINX_TAG="${i#*=}"
      shift # past argument=value
    ;;
  esac
done

# create dir for docs
mkdir -p docs

# init
machine_str="$(gcc -dumpmachine | cut -d'-' -f1)"

# workaround git user name and email not set
GIT_USER_NAME="$(git config --global user.name)"
GIT_USER_EMAIL="$(git config --global user.email)"
if [[ "${GIT_USER_NAME}" = "" ]]; then
    git config --global user.name "Build Bot"
fi
if [[ "${GIT_USER_EMAIL}" = "" ]]; then
    git config --global user.email "nobody@example.com"
fi

# dep versions
ZLIB="$(curl -s 'https://zlib.net/' | grep -ioP 'zlib-(\d+\.)+\d+' | sort -ruV | head -1)"
ZLIB="${ZLIB:-zlib-1.2.13}"
echo "${ZLIB}"
PCRE="$(curl -s 'https://sourceforge.net/projects/pcre/rss?path=/pcre/' | grep -ioP 'pcre-(\d+\.)+\d+' |sort -ruV | head -1)"
PCRE="${PCRE:-pcre-8.45}"
echo "${PCRE}"
PCRE2="$(curl -s 'https://api.github.com/repos/PhilipHazel/pcre2/releases/latest' | grep -ioP 'pcre2-(\d+\.)+\d+' |sort -ruV | head -1)"
PCRE2="${PCRE2:-pcre2-10.42}"
echo "${PCRE2}"
OPENSSL="$(curl -s 'https://openssl-library.org/source/' | grep -ioP 'openssl-3\.0\.\d+' | sort -ruV | head -1)"
OPENSSL="${OPENSSL:-openssl-3.0.14}"
echo "${OPENSSL}"

# clone and patch nginx
if [[ -d nginx ]]; then
    cd nginx || exit 1
    git checkout master
    git branch patch -D
    if [[ "${NGINX_TAG}" == "" ]]; then
        git reset --hard origin || git reset --hard
        git pull
    else
        git reset --hard "${NGINX_TAG}" || git reset --hard
    fi
else
    if [[ "${NGINX_TAG}" == "" ]]; then
        git clone https://github.com/nginx/nginx.git --depth=1
        cd nginx || exit 1
    else
        git clone https://github.com/nginx/nginx.git --depth=1 --branch "${NGINX_TAG}"
        cd nginx || exit 1
        # You are in 'detached HEAD' state.
        git checkout -b master
    fi
fi

git checkout -b patch

# Since 1.23.4 utf16 encoded pathes are supported natively upstream
# detect function ngx_utf16_to_utf8 introduced since nginx 1.23.4
if [ "$(grep 'ngx_utf16_to_utf8' src/os/win32/ngx_files.c | wc -l)" -ge 2 ]; then
    rm -f ../nginx-0002-win32-force-utf-8-encoding-in-ngx_dir_t.patch
    rm -f ../nginx-0003-ngx_files-implement-some-functions-in-utf8-encoding.patch
    rm -f ../nginx-0004-ngx_files-implement-ngx_open_tempfile-in-utf8-encodi.patch
    rm -f ../nginx-0005-ngx_files-implement-ngx_open_glob-and-ngx_read_glob-.patch
    rm -f ../nginx-0006-ngx_files-implement-ngx_win32_rename_file-in-utf8-en.patch
fi

# apply remaining patches
git am -3 ../nginx-*.patch

set -e

# download deps
wget -c -nv "https://zlib.net/${ZLIB}.tar.xz" || \
  wget -c -nv "http://prdownloads.sourceforge.net/libpng/${ZLIB}.tar.xz"
tar -xf "${ZLIB}.tar.xz"
WITH_PCRE="${PCRE}"
if grep -q PCRE2_STATIC ./auto/lib/pcre/conf ; then
  echo using pcre2
  WITH_PCRE="${PCRE2}"
  wget -c -nv "https://github.com/PhilipHazel/pcre2/releases/download/${PCRE2}/${PCRE2}.tar.bz2"
  tar -xf "${PCRE2}.tar.bz2"
else
  wget -c -nv "https://download.sourceforge.net/project/pcre/pcre/$(echo $PCRE | sed 's/pcre-//')/${PCRE}.tar.bz2"
  tar -xf "${PCRE}.tar.bz2"
fi
echo using pcre "${WITH_PCRE}"
wget -c -nv "https://www.openssl.org/source/${OPENSSL}.tar.gz"
tar -xf "${OPENSSL}.tar.gz"

# dirty workaround for openssl-1.1.1d
if [ "${OPENSSL}" = "openssl-1.1.1d" ]; then
   sed -i 's/return return 0;/return 0;/' openssl-1.1.1d/crypto/threads_none.c
fi

# make changes
make -f docs/GNUmakefile changes
mv -f tmp/*/CHANGES* ../docs/

# copy docs and licenses
cp -f docs/text/LICENSE ../docs/ || cp -f LICENSE ../docs/
cp -f docs/text/README ../docs/ || cp -f README.md ../docs/ || cp -f README ../docs/
if [[ -d docs/html ]]; then
    mkdir -p ../html
    cp -f docs/html/* ../html/
fi
cp -pf "${OPENSSL}/LICENSE.txt" '../docs/OpenSSL.LICENSE'
cp -pf "${WITH_PCRE}/LICENCE" '../docs/PCRE.LICENCE'
sed -ne '/^ (C) 1995-20/,/^  jloup@gzip\.org/p' "${ZLIB}/README" > '../docs/zlib.LICENSE'
touch -r "${ZLIB}/README" '../docs/zlib.LICENSE'

# configure
configure_args=(
    --sbin-path=nginx.exe \
    --http-client-body-temp-path=temp/client_body \
    --http-proxy-temp-path=temp/proxy \
    --http-fastcgi-temp-path=temp/fastcgi \
    --http-scgi-temp-path=temp/scgi \
    --http-uwsgi-temp-path=temp/uwsgi \
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
    --with-stream_realip_module \
    "--with-pcre=${WITH_PCRE}" \
    --with-pcre-jit \
    "--with-zlib=${ZLIB}" \
    --with-ld-opt="-Wl,--gc-sections,--build-id=none" \
    --prefix=
)

# no-ssl build
echo "${configure_args[@]}"
auto/configure "${configure_args[@]}" \
    --with-cc-opt='-DFD_SETSIZE=1024 -s -O2 -fno-strict-aliasing -pipe'

# build
make "-j$(nproc)"
strip -s objs/nginx.exe
version="$(cat src/core/nginx.h | grep NGINX_VERSION | grep -ioP '((\d+\.)+\d+)')"
mv -f "objs/nginx.exe" "../nginx-slim-${version}-${machine_str}.exe"

# re-configure with ssl
configure_args+=(
    --with-http_v2_module \
    "--with-openssl=${OPENSSL}" \
    --with-http_ssl_module \
    --with-mail_ssl_module \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module
)
echo "${configure_args[@]}"
auto/configure "${configure_args[@]}" \
    --with-cc-opt='-DFD_SETSIZE=1024 -s -O2 -fno-strict-aliasing -pipe' \
    --with-openssl-opt='no-tests -D_WIN32_WINNT=0x0501'

# build
make "-j$(nproc)"
strip -s objs/nginx.exe
version="$(cat src/core/nginx.h | grep NGINX_VERSION | grep -ioP '((\d+\.)+\d+)')"
mv -f "objs/nginx.exe" "../nginx-${version}-${machine_str}.exe"

# re-configure with debugging log
configure_args+=(--with-debug)
auto/configure "${configure_args[@]}"  \
    --with-cc-opt='-DFD_SETSIZE=1024 -O2 -fno-strict-aliasing -pipe' \
    --with-openssl-opt='no-tests -D_WIN32_WINNT=0x0501'

# re-build with debugging log
make "-j$(nproc)"
mv -f "objs/nginx.exe" "../nginx-${version}-${machine_str}-debug.exe"

# clean up
git checkout master
git branch patch -D
cd ..
