#!/bin/sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$DIR/.build"
swiftc -O "$DIR/axdump.swift" -o "$DIR/.build/axdump"
swiftc -O "$DIR/imagediff.swift" -o "$DIR/.build/imagediff"
swiftc -O "$DIR/pixscan.swift" -o "$DIR/.build/pixscan"
echo "built $DIR/.build/axdump $DIR/.build/imagediff $DIR/.build/pixscan"
