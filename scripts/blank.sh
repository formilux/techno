#!/bin/sh
#/opt/schily/bin/cdrecord dev=0,0,0 speed=8 blank=fast -v
# en ATAPI :
#cdrecord dev=ATAPI:0,1,0 speed=8 blank=fast -v
# en IDE-SCSI :
cdrecord dev=0,0,0 speed=8 blank=fast -v

