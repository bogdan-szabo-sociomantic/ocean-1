#!/bin/sh

# Defaults
rev_file=src/main/Version.d
lib_dir=../
author="`id -un`"
dmd="`dmd | head -1`"

# Command used to get the date (we use day resolution to avoid unnecesary
# rebuilds)
date_cmd="date +%Y-%m-%d"

print_usage()
{
	echo "\
Generates a Version.d file.

Usage: $0 [OPTIONS] [GC] [LIB1] [LIB2] ...

Options:

-o FILE		Where to write the output (Version.d) file (default: $rev_file)
-L DIR		Directory where to find the libraries (default: $lib_dir)
-a AUTHOR	Author of the build (default: detected, currently $author)
-t TEMPLATE	Template file to use (default: [DIR]/ocean/script/Version.d.tpl)
-d DATE		Build date string (default: output of '$date_cmd')
-h		Shows this help and exit

GC is the garbage collector used to compile the program (should be either 'cdgc'
or 'basic').

LIB1 ... are the name of the libraries this program depends on (to get the
libraries versions).

NOTE: All these options are replace in the template using sed s// command and
      this script doesn't get care of quoting, so if you use any 'special'
      character (like '/') you need to quote it yourself.
"
}

# Parse arguments
while getopts o:L:a:t:d:h flag
do
    case $flag in
        o)  rev_file="$OPTARG";;
        L)  lib_dir="$OPTARG";;
        a)  author="$OPTARG";;
	t)  template="$OPTARG";;
	d)  date="$OPTARG";;
        h)  print_usage ; exit 0;;
        \?) echo >&2; print_usage >&2; exit 1;;
    esac
done
shift `expr $OPTIND - 1`

# Fill missing options
test -z "$template" && template="$lib_dir/ocean/script/appVersion.d.tpl"
test -z "$date" && date="`$date_cmd`"

get_rev()
{
	# Check which type of repository we are using
	if svn info $1 > /dev/null 2>&1
	then
		echo -n r
		svnversion $1
	elif git --git-dir $1/.git svn info > /dev/null 2>&1
	then
		echo -n r
		git --git-dir $1/.git svn info | grep '^Revision: ' | cut -b11-
	elif git --git-dir $1/.git describe --dirty --tags --always > /dev/null 2>&1
	then
		git --git-dir $1/.git describe --tags --always --dirty='!'
	else
		echo "Unknown version control system at $1" >&2
		echo "For now only svn, git and git-svn are supported" >&2
		exit 2
	fi
}

tmp=`mktemp mkversion.XXXXXXXXXX`

trap "rm -f '$tmp'; exit 1" INT TERM QUIT

# Generate the file (in a temporary) based on a template
cp "$template" "$tmp"
module=`echo "$rev_file" | sed -e 's|/|.|g' -e 's|.d||g'`
gc="$1"; shift
sed -i "$tmp" \
	-e "s/@MODULE@/$module/" \
	-e "s/@GC@/$gc/" \
	-e "s/@REVISION@/`get_rev $(git rev-parse --show-toplevel)`/" \
	-e "s/@DATE@/$date/" \
	-e "s/@AUTHOR@/$author/" \
    -e "s/@DMD@/$dmd/"

# Generate the libraries info
libs=''
for lib in "$@"
do
    libs="${libs}    Version.libraries[\"$lib\"] = \"`get_rev $lib_dir/$lib`\";\\n"
done
sed -i "s/@LIBRARIES@/$libs/" "$tmp"

# Check if anything has changed
if [ -e "$rev_file" ]
then
	sum1=`md5sum "$tmp" | cut -d' ' -f1`
	sum2=`md5sum "$rev_file" | cut -d' ' -f1`
	if [ $sum1 = $sum2 ]
	then
		rm "$tmp"
		exit 0
	fi
fi
mv "$tmp" "$rev_file"
