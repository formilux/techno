#!/bin/bash

#
# install-boot - prepare a block device for booting - version 0.0.2 - 2007-07-22
# This file is part of the Formilux project : http://formilux.ant-computing.com/
#
# Copyright (C) 2001-2007 Benoit Dolez & Willy Tarreau
#       mailto: benoit@ant-computing.com,willy@ant-computing.com
#
# This program is licenced under GPLv2 ( http://www.gnu.org/licenses/gpl.txt )

#### update PATH to include this script's directory
MYNAME="${0##*/}"
MYDIR="${0%/*}"
[ "${PATH#$MYDIR:}" == "$PATH" ] && export PATH="$MYDIR:$PATH"

#### source defaults file if it exists
FLXDEFAULTS="${FLXDEFAULTS-$HOME/.flxdefaults}"
if [ -r "$FLXDEFAULTS" ]; then
  . "$FLXDEFAULTS"
fi

CMDLINE="$*"

# usage: displays script usage and returns no error.
function usage {
  echo "install-boot - prepare a block device for booting - version 0.0.2 - 2007-07-22"
  echo "Usage: ${myname##*/} -d <mbr_dev> -m <mnt_pnt> -g1 <grub_dir1> -g2 <grub_dir2>"
  echo "       -b <bstrp_dir> [ -t <targ_dev> ] [ -u ] [ -v ]"
  echo
  echo " - <mbr_dev> is the name of the block device as seen from the installer's OS."
  echo " - <mnt_pnt> is the directory where the /boot partition is currently mounted."
  echo " - <grub_dir1> is the directory where the *stage* grub files can be found."
  echo "   It usually is something like /usr/share/grub/i386-pc."
  echo " - <grub_dir2> is the directory where grub-mbr-default can be found. It usually"
  echo "   is /sbin."
  echo " - <bstrp_dir> is the directory holding the 'firmware.img' file to be loaded."
  echo " - <targ_dev> is the optional block device name as seen on the target machine."
  echo "   It may differ from the installer's name for instance when installing a flash"
  echo "   from a different machine via an USB adapter. It defaults to <mbr_dev>."
  echo " - -u unmounts bstrap_dir after use."
  echo " - -v enables makes the program more verbose."
  echo
}

function die {
  echo
  echo "### ${MYNAME}: $@" >&2
  echo "Cmdline was $CMDLINE" >&2
  echo
  exit 1
}

verbose() {
  echo "$@" >&2
  "$@"
}

silent() {
  local ret
  if [ $VERBOSE != 1 ]; then
    "$@" >/dev/null 2>&1
    ret=$?
  else
    echo -n "$@ ... " >&2
    "$@" >/dev/null 2>&1 ; ret=$?
    echo "returns $ret." >&2
  fi
  return $ret
}

# Presents a list of available firmwares and prompts the user to choose one
# Result is in $REPLY
select_fw_from_dir() {
    REPLY="$1/firmware.img"
    [ -e "$REPLY" ] || die "FATAL: $1 does not contain any firmware image"
}

# Presents a list of available cfg templates and prompts the user to choose one
# Result is in $REPLY
select_tmpl_from_dir() {
    REPLY="$1/menu.tmpl"
    [ -e "$REPLY" ] || die "FATAL: $1 does not contain any configuration template"
}

### main entry point

shopt -s nullglob dotglob
set -o pipefail
umask 022

myname="$0"
PRINTUSAGE=0
VERBOSE=0
UNMOUNT=0

unset MBR_DEV MNT_PNT GRUB_DIR1 GRUB_DIR2 BSTRP_DIR TARG_DEV


### parsing
[ $# -gt 0 ] || PRINTUSAGE=1

while [ $# -gt 0 ] ; do
  case "$1" in 
    -d) # -d mbr_dev
      [ -n "$2" -a -e "$2" ] || die "FATAL: device $2 does not exist."
      MBR_DEV="$2"
      shift;
      ;; 

    -m) # -m mnt_pnt
      [ -n "$2" -a -d "$2/." ] || die "FATAL: argument '$2' point to something not a valid directory. Aborting."
      MNT_PNT="$2"
      shift;
      ;; 

    -g1) # -g1 grub_dir1
      [ -n "$2" -a -e "$2/stage1" ] || die "FATAL: $2 does not contain grub's stage1 file"
      GRUB_DIR1="$2"
      shift;
      ;; 

    -g2) # -g2 grub_dir2
      [ -n "$2" -a -e "$2/grub-mbr-default" ] || die "FATAL: $2 does not contain the grub-mbr-default file"
      GRUB_DIR2="$2"
      shift;
      ;; 

    -b) # -f bstrp_dir
      [ -n "$2" -a -d "$2/." ] || die "FATAL: argument '$2' point to something not a valid directory. Aborting."
      BSTRP_DIR="$2"
      shift;
      ;; 

    -t) # -t targ_dev
      TARG_DEV="$2"
      shift;
      ;; 

    -u) # -u = unmount
      UNMOUNT=1
      ;;

    -v) # -v = verbose
      VERBOSE=1
      ;;

    -h) # displays help
      PRINTUSAGE=1
      shift
      ;;
  esac
  shift
done

[ -n "$MBR_DEV" -a -n "$MNT_PNT" -a -n "$GRUB_DIR1" -a -n "$GRUB_DIR2" -a -n "$BSTRP_DIR" ] || PRINTUSAGE=1

if [ $PRINTUSAGE -gt 0 ]; then
  usage
  echo
  exit 1
fi

[ -n "$TARG_DEV" ] || TARG_DEV="$MBR_DEV"


### real start

TMPDIR="/tmp/.tmpgrub"
rm -rf "$TMPDIR" && mkdir "$TMPDIR" || die "FATAL: cannot make temp dir $TMPDIR"

select_fw_from_dir "$BSTRP_DIR" ; FWFILE="$REPLY"
select_tmpl_from_dir "$BSTRP_DIR" ; TMPL="$REPLY"

# boot partition number on the device, starting at 1
BNUM=1

# flash partition number on the device, starting at 1
FNUM=2

# try to compose boot partition name (grub's format)
GBNAME="(hd0,$[BNUM-1])"
GFNAME="(hd0,$[FNUM-1])"

# try to compose flash partition name : we hope to at least know the device
FNAME="${TARG_DEV}${FNUM}"
[ -e "${FNAME}" ] || FNAME="${TARG_DEV}p${FNUM}"
[ -e "${FNAME}" ] || die "FATAL: cannot find partition #$FNUM for device $FNAME"

umask 077
verbose mkdir -p "${MNT_PNT}/boot" ${MNT_PNT}/boot/{grub,firmware,defaults} || \
  die "FATAL: error during mkdir -p ${MNT_PNT}/boot[/*]"

verbose rm -f ${MNT_PNT}/boot/grub/{stage1,e2fs_stage1_5,stage2,menu.lst}
verbose rm -f ${MNT_PNT}/boot/firmware/* ${MNT_PNT}/boot/defaults/* 

verbose cp "$GRUB_DIR1/"{stage1,e2fs_stage1_5,stage2} "${MNT_PNT}/boot/grub/" || \
  die "FATAL: error while copying grub files"
verbose cp "$GRUB_DIR2/grub-mbr-default" "${MNT_PNT}/boot/defaults/" || \
  die "FATAL: error while copying default files"

verbose cp "$FWFILE" "${MNT_PNT}/boot/firmware/firmware.img" || \
  die "FATAL: error while copying firmware file"
verbose sed -e "s|%FLASH%|${FNAME}|g" \
            -e "s|%BNUM%|${GBNAME}|g" \
            -e "s|%FNUM%|${GFNAME}|g" < "$TMPL" \
  >"${MNT_PNT}/boot/grub/menu.lst" || \
  die "FATAL: error while generating grub config"

silent chown -R root:root ${MNT_PNT}/boot
silent chmod 700 ${MNT_PNT}/boot/{.,defaults,firmware,grub}
silent chmod 500 ${MNT_PNT}/boot/defaults/grub-mbr-default
silent chmod 400 ${MNT_PNT}/boot/firmware/firmware.img
silent chmod 400 ${MNT_PNT}/boot/grub/*stage*
silent chmod 600 ${MNT_PNT}/boot/grub/menu.lst


# do this in order to prevent grub from guessing useless devices from the BIOS.
echo "(hd0) $MBR_DEV" > "$TMPDIR/dev.map"
echo "Running grub now..."
verbose grub --batch --no-floppy --boot-drive=0x80 --device-map "$TMPDIR/dev.map" <<EOF
  root (hd0,$[BNUM-1])
  setup (hd0)
  quit
EOF
# rem: on peut aussi forcer à déplacer l'install: setup --prefix=/quelque/part (hd0)
# par défaut, setup essaie /boot/grub puis /grub

ret=$?

echo
if [ $ret -eq 0 ]; then
    if [ $UNMOUNT -ne 0 ]; then
      umount $MNT_PNT
    else
      echo "Done ! Do not forget to umount $MNT_PNT !"
    fi
    exit 0
else
    echo "FATAL: GRUB installation failed ! Check $MNT_PNT !"
    exit 1
fi
echo
