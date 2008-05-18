#!/bin/sh

if [ $# -lt 1 ]; then
  echo "Usage: ${0##*/} config-2.6* [...]"
  exit 1
fi

if [ -z "${0##*/*}" ]; then
  DIR="${0%/*}"
else
  DIR="$PWD"
fi

for i in "$@"; do
  echo "Building kernel for config $i"
  "$DIR/build-kernel-list" "$i"
  if [ -s include/config/kernel.release ]; then
    ver=$(cat include/config/kernel.release)
  else
    ver=$(grep KERNELVERSION include/linux/autoconf.h|cut -f2 -d'"')
  fi
  major="${ver%%.*}" ; ver="${ver#$major.}"
  minor="${ver%%.*}" ; ver="${ver#$minor.}"
  sub="${ver%%-*}"   ; sub="${sub%%[^0-9]*}"
  extra="${ver#$sub}"

  EXTRAVERSION=$extra bash "$DIR/make-self-mod.sh"

  "$DIR/build-kernel-list" -i "$i"
done

