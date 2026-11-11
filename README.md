# nginx-build-msys2

nginx build scripts on msys2 mingw with dependencies and custom patches

## Badges

[![Build status](https://ci.appveyor.com/api/projects/status/cjd77mirpuc5leht?svg=true)](https://ci.appveyor.com/project/myfreeer/nginx-build-msys2)

## Features

* native x86-64 (x64, amd64) build for windows.
* nginx can execute in directory or path containing non-ascii characters. (Not needed since [1.23.4](https://github.com/nginx/nginx/commits/release-1.23.4/src/os/win32))
* read file names in directory as utf8 encoding (affecting autoindex module). (Not needed since [1.23.4](https://github.com/nginx/nginx/commits/release-1.23.4/src/os/win32))

## Windows worker stderr

This fork adds `nginx-0008-win32-inherit-std-handles.patch` on top of upstream.

On Windows, nginx starts worker processes with
`CreateProcess(..., FALSE, CREATE_NO_WINDOW, ...)`. Workers therefore have no
console and do not inherit the master's standard handles. Patch 0007 makes
`access_log stderr` valid, but in the default master+worker mode the worker's
logs still do not reach the console or a parent process.

Patch 0008 marks the master's stdin/stdout/stderr as inheritable and passes
them to the worker with `STARTF_USESTDHANDLES`. This keeps the normal
master+worker model while letting a console, supervisor, or service capture
both access and error logs.

Keep `daemon off;` so the master stays attached, but **do not** use
`master_process off;` — the patch removes the need for the single-process
workaround.

Test after building:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass `
  -File .\test\test-stderr.ps1 `
  -Exe .\nginx-1.31.8-x86_64.exe
```

The test starts nginx with `master_process on`, verifies that the worker's
access log appears on the captured stderr, then checks `reload` and `quit`.

Patch 0007 is from
[myfreeer/nginx-build-msys2](https://github.com/myfreeer/nginx-build-msys2);
patch 0008 is original to this fork and is distributed under the same
BSD-2-Clause license.

## [Releases](https://github.com/myfreeer/nginx-build-msys2/releases)

* `nginx-*-i686.exe`: 32-bit nginx
* `nginx-*-i686-debug.exe`: 32-bit nginx with debugging log and symbols
* `nginx-*-x86_64.exe`: 64-bit nginx
* `nginx-*-x86_64-debug.exe`: 64-bit nginx with debugging log and symbols
