#!/bin/sh

usage () {
  echo "Usage: dvl-dep depfile file1 [file2 ...]"
  echo "It will output all files which should be extracted from the same"
  echo "package based on the dep file, and all external dependencies, prefixed"
  echo "with a '+' sign."
  exit 1
}

[ $# -ge 2 ] || usage

DEP=$1
shift

RES=/tmp/$$.resolved
PND=/tmp/$$.pending
UNR=/tmp/$$.unresolved

rm -f $UNR $RES $PND $PND- || exit 1
touch $UNR $RES $PND $PND- || exit 1
for i in "$@"; do
  echo "$i" >> $PND
done

while [ $(grep -c '^' $PND) -gt 0 ]; do
    read entry < $PND
    
    set -- $(grep "^[^ ]*$entry\([ ]\+\|\$\)" $DEP)
    name=$1
    if [ $# -gt 0 ]; then
	for i in "$@"; do
	    if grep -q "^[^ ]*$i\$" $RES || \
		grep -q "^[^ ]*$i\$" $PND || \
		grep -q "^[^ ]*$i\$" $UNR; then
		# resolved or pending entry.
		:
	    else
		# new pending entry to resolve
		echo "$i" >> $PND
	    fi
	done
	grep -q "^[^ ]*$name\$" $RES || echo "$name" >> $RES
    else
	echo "$entry" >> $UNR
    fi
    tail +2 $PND > $PND- && mv $PND- $PND
done

cat $RES
sed -e 's/^/+/' < $UNR
rm -f $UNR $RES $PND $PND-
