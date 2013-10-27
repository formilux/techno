#!/bin/sh
#/opt/schily/bin/cdrecord dev=0,0,0  speed=8 -eject -data -isosize -dao -v "$@"
# en ATAPI pur :
# cdrecord dev=ATAPI:0,1,0 speed=8 -eject -data -isosize -dao -v "$@"

# en IDE-SCSI :
cdrecord dev=0,0,0 speed=8 -eject -data -isosize -dao -v "$@"
