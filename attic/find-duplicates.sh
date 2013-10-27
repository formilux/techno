#!/bin/bash
shopt -s nullglob dotglob
for i in *tgz *[0-9]; do j=${i%%-[0-9]*}; k=$(echo ${j}-[0-9]*gz ${j}-[0-9]*[0-9]); if [ ! -e "$k" ]; then echo $j : $k; fi; done|sort -u
