# nginx-build-msys2

nginx build scripts on msys2 mingw with dependencies and custom patches

## Badges

[![Build status](https://ci.appveyor.com/api/projects/status/cjd77mirpuc5leht?svg=true)](https://ci.appveyor.com/project/myfreeer/nginx-build-msys2)

## Features

* native x86-64 (x64, amd64) build for windows.
* nginx can execute in directory or path containing non-ascii characters. (Not needed since [1.23.4](https://github.com/nginx/nginx/commits/release-1.23.4/src/os/win32))
* read file names in directory as utf8 encoding (affecting autoindex module). (Not needed since [1.23.4](https://github.com/nginx/nginx/commits/release-1.23.4/src/os/win32))

## [Releases](https://github.com/myfreeer/nginx-build-msys2/releases)

* `nginx-*-i686.exe`: 32-bit nginx
* `nginx-*-i686-debug.exe`: 32-bit nginx with debugging log and symbols
* `nginx-*-x86_64.exe`: 64-bit nginx
* `nginx-*-x86_64-debug.exe`: 64-bit nginx with debugging log and symbols
