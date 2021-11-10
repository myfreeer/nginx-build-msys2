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
ZLIB="${ZLIB:-zlib-1.2.11}"
echo "${ZLIB}"
PCRE="$(curl -s 'https://sourceforge.net/projects/pcre/rss?path=/pcre/' | grep -ioP 'pcre-(\d+\.)+\d+' |sort -ruV | head -1)"
PCRE="${PCRE:-pcre-8.45}"
echo "${PCRE}"
OPENSSL="$(curl -s 'https://www.openssl.org/source/' | grep -ioP 'openssl-1\.(\d+\.)+[a-z\d]+' | sort -ruV | head -1)"
OPENSSL="${OPENSSL:-openssl-1.1.1l}"
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
git am -3 ../nginx-*.patch

# download deps
wget -c -nv "https://zlib.net/${ZLIB}.tar.xz" || \
  wget -c -nv "http://prdownloads.sourceforge.net/libpng/${ZLIB}.tar.xz"
tar -xf "${ZLIB}.tar.xz"
wget -c -nv "https://download.sourceforge.net/project/pcre/pcre/$(echo $PCRE | sed 's/pcre-//')/${PCRE}.tar.bz2"
tar -xf "${PCRE}.tar.bz2"
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
cp -f docs/text/LICENSE ../docs/
cp -f docs/text/README ../docs/
cp -pf "${OPENSSL}/LICENSE" '../docs/OpenSSL.LICENSE'
cp -pf "${PCRE}/LICENCE" '../docs/PCRE.LICENCE'
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
    "--with-pcre=${PCRE}" \
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
    --with-stream_ssl_module
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
