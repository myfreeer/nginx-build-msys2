set cmdLine="cd \"$APPVEYOR_BUILD_FOLDER\" && exec ./nginx-build-msys2.sh"
if "%APPVEYOR_REPO_TAG%" == "true" set cmdLine="cd \"$APPVEYOR_BUILD_FOLDER\" && exec ./nginx-build-msys2.sh --tag=release-$APPVEYOR_REPO_TAG_NAME"

set MSYSTEM=MINGW64
C:\msys64\usr\bin\bash -lc %cmdLine%
set MSYSTEM=MINGW32
C:\msys64\usr\bin\bash -lc %cmdLine%

C:\msys64\usr\bin\bash -lc "cd \"$APPVEYOR_BUILD_FOLDER\" && exec ./nginx-package-msys2.sh"