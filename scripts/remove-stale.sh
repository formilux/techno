#!/bin/bash

# this awful script is used to extract from a .prf all entries which have shown
# an error after an flxrescan.

grep -v $(echo `grep '^#' /tmp/file.prf.log|cut -f3 -d' '`|tr ' ' '|'|sed -e 's/|/\\|/g') file.prf
