#!/bin/bash
cp -rf nginx/conf .
cp -rf nginx/docs/html .
rm -rf temp
mkdir -p temp
7z a -mx9 nginx-bin.7z nginx-*.exe conf html temp