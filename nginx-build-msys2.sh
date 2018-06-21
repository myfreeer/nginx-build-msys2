git clone https://github.com/nginx/nginx --depth=1
cd nginx
wget https://download.sourceforge.net/libpng/zlib-1.2.11.tar.gz
tar -xf zlib-1.2.11.tar.gz
wget https://ftp.pcre.org/pub/pcre/pcre-8.42.tar.bz2
tar -xf pcre-8.42.tar.bz2
auto/configure --with-pcre=pcre-8.42 --with-zlib=zlib-1.2.11 --prefix=.
make -j$(nproc)
strip -s objs/nginx.exe
