#!/bin/bash

PKGDIRS=(${PKGDIRS[@]:-/data/projets/formilux/stable/pkg /nfs/projets/formilux/dev/pkg /data/projets/formilux/stable/custom/exceliance/pkg})

while read f p rest; do
  f1="${f#-}"
  if [ -z "$f" -o "$f1" == "$f" ]; then
    echo "$f $p"
  else
    f1=${f1#/}
    r="$(exactlst=;verlst=;largelst=; for dir in ${PKGDIRS[@]}; do \
           exactlst=$(echo ${exactlst[@]} $dir/$p/compiled/*.lst); \
           verlst=$(echo ${verlst[@]} $dir/${p%-flx*}*/compiled/*.lst); \
           largelst=$(echo ${largelst[@]} $dir/${p%-*-flx*}*/compiled/*.lst); \
	 done 2>/dev/null
	 grep -H " \(.*/\)\{0,1\}$f1\( .*\|\)\$" $exactlst $verlst $largelst 2>/dev/null | \
         sed -ne '1s,^\([^:]*/\)\([^:]*\)\(.lst:.\{74\}\)\([^ ]*\)\(.*\)$,\4 \2,p')"
    [ -n "$r" ] && echo "$r" || echo "$f $p"
  fi
done | sort -u
