#!/bin/sh
# Defaults
rev_file=src/Version.d
author="`id -un`"
get_rev=`dirname $0`/git-rev-desc

if which dmd1 > /dev/null
then
    dmd="`dmd1 | head -1`"
else
    dmd="`dmd | head -1`"
fi

# Command used to get the date (we use day resolution to avoid unnecesary
# rebuilds)
date_cmd="date +%Y-%m-%d"

print_usage()
{
    echo "\
Generates a Version.d file.

Usage: $0 [OPTIONS] [GC] [TEMPLATE] [LIB1] [LIB2] ...

Options:

-o FILE      Where to write the output (Version.d) file (default: $rev_file)
-a AUTHOR    Author of the build (default: detected, currently $author)
-d DATE      Build date string (default: output of '$date_cmd')
-m MODULE    Module name to use in the module declaration (default: built from -o)
-v           Be more verbose (print a message if the file was updated)
-h           Shows this help and exit

GC is the garbage collector used to compile the program (should be either 'cdgc'
or 'basic').

TEMPLATE is template file to use

LIB1 ... are the name of the libraries this program depends on (to get the
libraries versions).

NOTE: All these options are replace in the template using sed s// command and
      this script doesn't get care of quoting, so if you use any 'special'
      character (like '/') you need to quote it yourself.
"
}

# Parse arguments
verbose=0
module=
while getopts o:L:a:t:d:m:vh flag
do
    case $flag in
        o)  rev_file="$OPTARG";;
        a)  author="$OPTARG";;
        d)  date="$OPTARG";;
        m)  module="$OPTARG";;
        v)  verbose=1;;
        h)  print_usage ; exit 0;;
        \?) echo >&2; print_usage >&2; exit 2;;
    esac
done
shift `expr $OPTIND - 1`

gc="$1"; shift
template="$1"; shift

# Default
test -z "$date" && date="`$date_cmd`"

tmp=`mktemp mkversion.XXXXXXXXXX`

trap "rm -f '$tmp'; exit 1" INT TERM QUIT

# Generate the file (in a temporary) based on a template
cp "$template" "$tmp"
module=${module:-`echo "$rev_file" | sed -e 's|/|.|g' -e 's|.d||g'`}

sed -i "$tmp" \
    -e "s/@MODULE@/$module/" \
    -e "s/@GC@/$gc/" \
    -e "s/@REVISION@/`$get_rev .`/" \
    -e "s/@DATE@/$date/" \
    -e "s/@AUTHOR@/$author/" \
    -e "s/@DMD@/$dmd/"

# Generate the libraries info
libs=''
for lib in "$@"
do
    lib_base=`basename $lib`
    libs="${libs}    Version.libraries[\"$lib_base\"] = \"`$get_rev $lib`\";\\n"
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
if test "$verbose" -gt 0
then
    echo "$rev_file updated"
fi

# vim: set et sw=4 sts=4 :

