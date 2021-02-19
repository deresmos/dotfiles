#!/bin/sh

files () {
    find -L "$(dirname "$target")" \
        -maxdepth 1 \
        -type f \
        -iregex '.*\.\(jpe?g\|png\|gif\|bmp\)$' \
        -print0
}

target=$1
dir_target=$(dirname "$target")
count="$(files | grep -zn -m1 "$target" | cut -d: -f1)"

# exec
sxiv -n "$count" "$dir_target"
