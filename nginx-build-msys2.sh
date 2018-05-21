git clone https://github.com/nginx/nginx --depth=1
cd nginx
wget https://download.sourceforge.net/libpng/zlib-1.2.11.tar.gz
tar -xf zlib-1.2.11.tar.gz
auto/configure --without-http_rewrite_module --with-zlib=zlib-1.2.11 --prefix=.
make -j$(nproc)
strip -s objs/nginx.exe
