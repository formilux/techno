#!/bin/bash

# git-import-all-packages.sh - Import packages - version 0.0.4 - 2008-05-12
#
# Copyright (C) 2001-2008 Benoit Dolez & Willy Tarreau
#       mailto: benoit@ant-computing.com,willy@ant-computing.com
#
# This program is licenced under GPLv2 ( http://www.gnu.org/licenses/gpl.txt )
# -
# This tool scans a directory full of old and new formilux packages, and
# sorts them in chronological order, then applies them by groups on top of
# each other in a local directory, then versions them using GIT (or any other
# versionning system). The original directory must be passed in the PKGDIR
# variable.
#
# The local directory must contain a "package map" (pkgmap) which may be first
# built by setting BUILDMAP to 1 before running this script. The automatic
# version however, only manages to assign canonical names, it must be refined
# by hand. The absolute path to the pkgmap file may be passed in the PKGMAP
# variable.
#
# Last, the script is now able to create individual trees (one per canonical
# name). For this, set the INDIVIDUAL variable to 1.
#
# No package will be committed unless the FORCE variable is set.
# Typical usage :
#
#    $ FORCE=1 PKGDIR=/pool/pkg time ./merge-all-packages.sh allpkg '*'
#
# To output a list of packages sorted by date, simply set JUSTSORT to 1.
# Nothing else will be performed.
#
# In case of errors, setting DEBUG to 1 will help.
#
# Caveats: does not support empty files (eg: "RELEASED") which are simply
# ignored.

PKGDIR=${PKGDIR:-/data/projets/formilux/0.1/formilux-0.1.current/pool/pkg}
PKGMAP=${PKGMAP:-$PWD/pkgmap}
TMP=.tmp
COMMITTER="build@formilux"

QUIET=${QUIET-}
DEBUG=${DEBUG-}
FORCE=${FORCE-}
BUILDMAP=${BUILDMAP-}
JUSTSORT=${JUSTSORT-}
INDIVIDUAL=${INDIVIDUAL-}

LS="ls -1dvN --color=never"


# apply the patch passed on stdin, and commit it.
apply() {
    local pkg="$1"
    patch -d $DEST/. -p1
    find $DEST | xargs git-add
    git-commit -a -m "merged ${pkg##*/}"
}

# removes left digits from the first argument, return the result in $REPLY.
strip_digits() {
    local c n
    c="$1"
    n="${c#[0-9]}"
    while [ -n "$n" -a "$n" != "$c" ]; do
	c="$n"
	n="${c#[0-9]}"
    done
    REPLY="$n"
}

# called with a package name in $1, it will return the canonical package name in $REPLY.
# Exceptions must be taken care of because some versions of formilux ship with multiple
# versions of a given package. Eg: bash, bison, autoconf, ...
get_canonical_name() {
    local x
    x=${1##*/}; x=${x%-flx[0-9]*}; x=${x%%[._v-][0-9]*};
    x=${x%-}; x=${x%-ss[0-9]*};
    REPLY=$x
}

# Called with a package name in $1, it will return the closest package name
# in ${REPLY[0]} and the closest branch in ${REPLY[1)}.
# Exceptions are taken care of because some versions of formilux
# ship with multiple branches of a given package. Eg: bash, bison, autoconf...
# This function relies on a map file $PKGMAP consisting in four columns :
#  - the canonical name as computed by get_canonical_name
#  - a matching rule for package versions, using wildcards (path expansion)
#  - a new name for the package (most often the canonical name)
#  - the branch name (which normally includes the new names)
# The first match is returned, so it's important that the $PKGMAP file is
# sorted reversed.
# When no branch name is found, the canonical name is returned in the first
# field and the second is left blank.
#
get_package_branch() {
    local pkg="${1##*/}"
    local canon

    get_canonical_name "$pkg" ; canon=$REPLY
    REPLY=( $(grep -w "^$canon" "${PKGMAP}" |
	while read c r n d rest; do
	    if [ -z "${pkg##$r*}" ]; then
		echo "$n $d"
		exit 0
	    fi
	done))
    [ -z "${REPLY[*]}" ] && REPLY=( "$canon" "" )
}

# sort all dates and output the result on stdout.
sort_packages_by_date() {
    local i=0
    while [ $i -lt ${#dates[@]} ]; do
	echo "${dates[$i]}"
	(( i++ ))
    done | sort
}

# Retrieve latest changelog from a package. ChangeLog must exist.
# The output is sent to stdout. FIXME: This is limited to the last changelog
# entry, which is not the same as the changelog from the last version.
# usage: $0 <package_path>
get_package_changelog() {
    local p="$1"
    sed -ne '/^[0-9]/,/^[0-9]/{p;b};q' "$p/ChangeLog" | sed -ne '/^[^0-9]/s/\t/    /p'
}

# generate a git patch header from information provided on the command line.
# The action is used to generate the subject message. It can be "merged" or
# "updated $pkg to" for instance.
# Usage: $0 <action> <date> <time> <user> <package_path> <date_source>
generate_git_patch_header() {
    local a="$1" d="$2" t="$3" u="$4" p="$5" s="$6"
    echo "From: $u"
    echo "Date: $(date -d "$d $t")"
    echo "Subject: $a ${p##*/}"
    echo
}

# apply a generated patch. Does nothing (cat) unless FORCE is set.
# If a directory is passed in argument, then enter that directory
# and apply the patch with -p2 instead of -p1.
apply_generated_patch() {
    if [ -n "${FORCE}" ]; then
	if [ -n "$1" ]; then
	    tee /tmp/log3 |(cd "$1" && git-am -k -3 -p3 --whitespace=nowarn)
	else
	    git-am -k -3 --whitespace=nowarn
        fi
    else
	echo "###################################################################"
	echo "For safety reasons, this patch will only be merged if FORCE is set."
	echo "Would apply the following patch to this directory: $PWD."
	echo "###################################################################"
	cat
    fi
}

# reads one date and one package per line:
#  $0 <date>, <time>, <user>, <package_abs_path>, <date_source>
merge_all_packages() {
    local a d t u p s rest
    local b c f v

    if [ -n "$JUSTSORT" ]; then
	cat
	return 0
    fi

    [ -n "$QUIET" ] || echo "Merging packages..." >&2

    mkdir -p "$TMP" || exit 1
    rm -rf "$TMP/a" "$TMP/b" "$TMP/n" "$TMP/temp"
    mkdir -p $TMP/a/$DEST $TMP/b/$DEST
    mkdir -p $TMP/n/$DEST $TMP/temp

    while read d t u p s rest; do
	[ -n "$DEBUG" ] && echo "Processing $d $t $u $p $s" >&2

	if [ -z "$INDIVIDUAL" ]; then
	    get_package_branch $p; c=${REPLY[1]}; c=${c:-REPLY[0]}

	    if [ -d "$DEST/$c/." -a -s "$DEST/$c/Version" ]; then
		a="Updated package '$c' to"
	    else
		a="Created package '$c' as"
		mkdir -p "$DEST/$c"
	    fi
	else
	    # individual packages: we have one directory per canonical name.
	    # We create one GIT branch per package branch. Unnamed branches
	    # are first guessed by extracting the first two numbers from the
	    # name, or called "flx0" if no name could be guessed. Named
	    # branches are called "<name>-flx0".
	    # That way, the "master" branch is never used. We assume that
	    # each newly created branch derives from last changed branch,
	    # which more or less matches the real workflow.

	    get_package_branch "$p"; c=${REPLY[0]}; b=${REPLY[1]}

	    # get the exact package version for the tag (x.x.x-flx0.x)
	    v=${p##*/}
	    v=${v#$c};
	    # remove any leading '-', '_', '.'
	    v=${v#[-_.]};v=${v#[-_.]};v=${v#[-_.]};

	    # if we find no branch, try to extract the 2 leftmost numbers and
	    # one dot from the exact version and create a branch from it.
	    if [ -n "$b" ]; then
		b=${b#$c}; b=${b#-};
	    else
		b=${v%-flx0.*}
		strip_digits "$b"; suf="${REPLY#[._-]}"
		strip_digits "$suf"; suf="$REPLY"
		b=${b%$suf}
	    fi
	    # remove any leading '-', '_' or '.'
	    b=${b#[-_.]};b=${b#[-_.]};b=${b#[-_.]};
	    # add "flx0".
	    b=${b:+${b}-}; b=${b}flx0
	    
	    if [ -n "$DEBUG" ]; then
		echo "Package ${p##*/} => canonical name '$c' (first guess '${REPLY[1]}')"
		echo "        branch '$b' / tag '$v'"
	    fi

	    if [ -d "$DEST/$c/." -a -s "$DEST/$c/.git" ]; then
	        a="Updated package '$c' to"
	    else
	        a="Created package '$c' as"
		if [ -n "${FORCE}" ]; then
		    mkdir -p "$DEST/$c"
		    # create a new git tree there with an initial commit.
		    ( cd "$DEST/$c"
		      git-init-db &&
		      tree=$(git-write-tree) &&
		      commit=$(echo 'Initial commit' | git-commit-tree $tree) &&
		      git-update-ref HEAD $commit 
		    )
		fi
	    fi

	    # now, we have the directory ($c) and the branch ($b).
	    # we have to checkout branch $b into that directory, and
	    # fork it in case of error.
	    if [ -n "${FORCE}" ]; then
		( cd "$DEST/$c"
		  git checkout "$b" 2>/dev/null || git checkout -b "$b"
		)
	    fi
	fi

	ln -s $ABS_DEST/$c $TMP/a/$DEST/$c
	ln -s ${p} $TMP/b/$DEST/$c
	ln -s $ABS_TMP/temp $TMP/n/$DEST/$c

	# try hard to recompose changelog from previous one if it exists
	# it will be located under $TMP/n/$DEST/$c.
	if [ -s ${p}/ChangeLog ]; then
	    if [ -s ${ABS_DEST}/${c}/Version ] &&
		[ -e ${PKGDIR}/$(<${ABS_DEST}/${c}/Version)/ChangeLog ]; then
		# we have a previous and a new changelog, let's produce cumulative
		# changes in the "changes" file.
		diff ${PKGDIR}/$(<${ABS_DEST}/${c}/Version)/ChangeLog ${p} |
		    sed -ne 's/^> \(.*\)/\1/p' > $TMP/temp/ChangeLog
	    else
		# it is the first changelog, let's take it fully
		cat ${p}/ChangeLog > $TMP/temp/ChangeLog 2>/dev/null
	    fi
	    # append what we have already queued in this package
	    cat ${ABS_DEST}/${c}/ChangeLog >> $TMP/temp/ChangeLog 2>/dev/null
	else
	    # no changelog, let's build one ourselves.
	    printf "$d $t  $u\n\n\t* released ${p##*/}\n\n" > $TMP/temp/ChangeLog
	    # append what we have already queued in this package
	    cat ${ABS_DEST}/${c}/ChangeLog >> $TMP/temp/ChangeLog 2>/dev/null
	fi

	(
	    generate_git_patch_header "$a" "$d" "$t" "$u" "$p" "$s"

	    cd $TMP

	    # output the latest changelog in the commit message: concatenate all
	    # the commit lines, remove the dates, and replace the tabs with
	    # spaces. Next, dump everything and stop at the second 'released'
	    # entry.
	    [ -e a/$DEST/$c/ChangeLog ] && f=a/$DEST/$c/ChangeLog || f=/dev/null
	    diff -N $f n/$DEST/$c/ChangeLog |
		sed -ne 's/^> \(.*\)/\1/p' |
		sed -ne '/^[^0-9]/s/\t/    /p' |
		sed -ne '1{p;b};/\* released .*-flx0\./q;p'

	    #if [ "$s" = "CHANGELOG" ]; then
	    #	get_package_changelog "$p"
	    #	echo
	    #fi

	    # diff previous changelog with the new crafted one.
	    diff -urN $f n/$DEST/$c/ChangeLog

	    # diff the old and new tree
	    diff -urN --exclude=".*" --exclude="compiled" --exclude="ChangeLog" a b

	    # generate at least one line of diff containing the latest version.
	    echo "--- a/$DEST/$c/Version"
	    echo "+++ b/$DEST/$c/Version"

	    if [ -e "a/$DEST/$c/Version" ]; then
		echo "@@ -1 +1 @@"
		echo "-$(<a/$DEST/$c/Version)"
	    else
		echo "@@ -0,0 +1 @@"
	    fi
	    echo "+${p##*/}"

	    # FIXME: rebuild changelogs.
	    # If no changelog exists in the package, either re-generate one or
	    # update a previously created one. If one exists in the new package
	    # but not the old one, we concat it to the one in the dir. If none
	    # exists, we concat a fake one (date+released "xxx") ito the on in
	    # the dir. If both exist, we must diff between old package (found
	    # in Version) and new one.
	) | apply_generated_patch "${INDIVIDUAL:+$DEST/$c}"

	if [ $? != 0 ]; then
	    (
		echo
		echo "FATAL! An error occured while applying the patch."
		echo "Leaving the directories untouched. The package was :"
		echo "${p##*/}"
		echo
	    ) >&2
	    exit 4
	fi

	# apply the tag if we had one.
	if [ -n "$INDIVIDUAL" -a -n "${FORCE}" -a -n "$v" ]; then
	    ( cd "$DEST/$c" && git-tag "v${v}" )
	fi

	rm -f $TMP/a/$DEST/$c $TMP/b/$DEST/$c $TMP/n/$DEST/$c
    done
}


##################################################################
###########  script main entry point  ############################
##################################################################

#
# We must sort the packages by release date.
# - When available, the first line of the ChangeLog will be used.
# - When available, the date of the RELEASE file will be used.
# - When available, the date of the compiled directory will be used.
#
# To convert the name of a package to a canonical name :
#    x=${REPLY##*/}; x=${x%-flx[0-9]*}; x=${x%%[._v-][0-9]*};
#    x=${x%-}; x=${x%-ss[0-9]*}; echo $x


if [ $# -ne 2 ]; then
  echo "Usage: ${0##*/} <directory> <globbing expression>"
  echo "Will merge all packages matching the expression into the directory,"
  echo "one at a time. It relies on a file called 'pkgmap' in the current"
  echo "directory, as well as some environment variables. Please read the"
  echo "script for more information."
  echo "IMPORTANT! the directory is relative to the root of the project and"
  echo "MUST NOT begin with a '/'."
  echo
  echo "Eg: ${0##*/} ppp ppp-2.4*"
  exit 1
fi

DEST="$1"
GLOB="$2"

if [ ! -d "$DEST/." ]; then
  echo "Fatal: '$DEST' is not a valid directory".
  exit 2
fi

if [ -z "${DEST##/*}" ]; then
  echo "Fatal: \$2 ('$DEST') MUST NOT be an absolute directory".
  exit 2
fi

DEST="${DEST%/}"
ABS_DEST="${PWD}/${DEST}"
ABS_TMP="${TMP}"
[ -n "${ABS_TMP##/*}" ] && ABS_TMP="${PWD}/${ABS_TMP}"
[ -n "${PKGDIR##/*}" ]  && PKGDIR="${PWD}/${PKGDIR}"

# Note: starting from now, PKGDIR, ABS_TMP and ABS_DEST are absolute paths.


# build package list
[ -n "$QUIET" ] || echo "Building packages list..." >&2
list=( $($LS $PKGDIR/$GLOB) )

# dates in format "<date> <time> <user> <package> <date_source> [<garbage>]"
dates=( )

[ -n "$DEBUG" ] && echo "List of packages found : ${list[@]}" >&2

# build a default map of (canonical_name, package_pattern, new_name, branch, full package)
# for hand-refining.
if [ -n "$BUILDMAP" ]; then
    for pkg in ${list[@]}; do
	get_canonical_name $pkg
	full=${pkg##*/}
	branch=${full#$REPLY}
	branch=${branch#-}
	branch=${branch%-flx0.*}
	branch=${branch:-BRANCH}
	echo $REPLY $REPLY $REPLY $branch $full
    done | sort -r
    exit 0
fi

for pkg in ${list[@]}; do
    if [ -d "$pkg/." ]; then
	[ -n "$QUIET" ] || echo "Evaluating $pkg" >&2
    else
	[ -n "$QUIET" ] || echo "Skipping $pkg (not a directory)" >&2
	continue
    fi

    date=""
    if [ -e "$pkg/ChangeLog" ]; then
	set -- $(grep -h -m 1 -F '/' $pkg/ChangeLog 2>/dev/null)
	[ -n "$2" ] && date="$1 $2 $3 $pkg CHANGELOG"
    fi

    if [ -z "$date" -a -e "$pkg/RELEASED" ]; then
	set -- $(find $pkg/RELEASED -maxdepth 0 -printf "%TY/%Tm/%Td %TH:%TM\n" 2>/dev/null)
	[ -n "$2" ] && date="$1 $2 ${COMMITTER} $pkg RELEASED"
    fi
    
    if [ -z "$date" -a -e "$pkg/compiled" ]; then
	set -- $(find $pkg/compiled -maxdepth 0 -printf "%TY/%Tm/%Td %TH:%TM\n" 2>/dev/null)
	[ -n "$2" ] && date="$1 $2 ${COMMITTER} $pkg COMPILED"
    fi

    if [ -z "$date" ]; then
	echo "Found no way to get the date for package $pkg! Aborting !" >&2
	exit 3
    fi
    dates[${#dates[@]}]=$date
done

[ -n "$QUIET" ] || echo "Sorting packages..." >&2

sort_packages_by_date | merge_all_packages
