#!/bin/bash

# This script optimizes images (JPEGs/PNGs) in a directory
# and commits them.

if [ -z "$1" -o "$1" = "-h" ]; then
	echo Usage: $0 dirname filter pathprefix
	echo Goes through all JPEG/PNG image files in the directory \"dirname\"
	echo ignoring the filenames matching the extended regexp \"filter\", and
	echo optimizes them using optipng and jpegoptim '(present in PATH)'
	echo "pathprefix" specifies the prefix, if any, to be stripped from file
	echo listing in commit message
	echo Example: $0 /home/user/images/ \".svn\" /home/user
	exit 0
fi

DIRNAME="$1"
FILTER="$2"
PREFIX="$3"
FILELIST=$(mktemp)
REPORT=$(mktemp)
IMAGES_OPTIMIZED=$(mktemp)
echo 0 > $IMAGES_OPTIMIZED

if [ -n "$PREFIX" ]; then
	PREFIX=${PREFIX//\//\\\/}
fi

optimize() {
	tool="$1"
	file="$2"
	oldsize=$(stat -c %s "$file")
	if [ $( $tool "$file" >/dev/null 2>/dev/null; echo $? ) -eq 0 ]; then
		newsize=$(stat -c %s "$file")
		if [ -n "$PREFIX" ]; then
			eval file=\${file/$PREFIX}
		fi
		if [ $newsize -lt $oldsize ]; then
			printf "%s:%9s:%9s\n" "$file" $oldsize $newsize
			echo 1 > $IMAGES_OPTIMIZED
		fi
	else
		echo Failed to process: $file 1>&2
		exit 1
	fi
}

formatReport() {
	if [ -n "$PREFIX" ]; then
		eval RDIR="\[\${DIRNAME/$PREFIX}\]\ "
	fi
	cat <<EOF
[Automated] ${RDIR}Image Optimization

EOF
	printf "||%-100s||%6s||%6s||%5s||\n" "Path" "Old" "New" "%age"
	perl -e 'my ($old,$new)=0;while(<>) { chomp($_); my(@v) = split(/:/,$_); $old+=$v[1]; $new+=$v[2]; printf("||%-100s||%6d||%6d||%5.2f%%||\n", $v[0], $v[1], $v[2], (($v[1]-$v[2])/$v[1])*100.0); } unless($old == 0) { printf("||%-100s||%6d||%6d||%5.2f%%||\n", "Total", $old, $new, (($old-$new)/$old)*100.0); }'
}

find $DIRNAME -type f |egrep -v "$FILTER" |egrep -i '[.](jpg|jpeg|png)$' >$FILELIST

cat $FILELIST |while read filename; do
	case $filename in
		*.png)	optimize optipng   "$filename" ;;
		*.PNG)	optimize optipng   "$filename" ;;
		*.jpg)	optimize jpegoptim "$filename" ;;
		*.jpeg)	optimize jpegoptim "$filename" ;;
		*.JPEG)	optimize jpegoptim "$filename" ;;
		*.JPG)	optimize jpegoptim "$filename" ;;
		*)	echo Unknown filetype: $filename   ;;
	esac
done|formatReport >$REPORT

if [ $( cat "$IMAGES_OPTIMIZED" ) -gt 0 ]; then
	echo $REPORT
else
	rm -f $REPORT
fi

rm -f $FILELIST
rm -f $IMAGES_OPTIMIZED

exit 0
