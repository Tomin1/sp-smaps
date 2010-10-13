#!/bin/sh

usage ()
{
	name=${0##*/}
	echo
	echo "$name <SMAPS mapping pattern> <SMAPS field pattern> <SMAPS snapshot file>"
	echo
	echo "Shows size-sorted totals for given mappings for all the processes"
	echo "in the given SMAPS snapshot file."
	echo
	echo "SMAPS mapping pattern can have anything from the mapping line that comes"
	echo "_after_ the given mapping's address range; access rights, file name etc."
	echo "Characters that are special for regular expressions '[].+*', need to"
	echo "be quoted with '\\' if they are supposed to be matched literally!"
	echo
	echo "SMAPS field pattern needs to start with one of the SMAPS field names:"
	echo "  Size, Rss, Pss, Shared_Clean, Shared_Dirty,"
	echo "  Private_Clean, Private_Dirty, Referenced, Swap."
	echo
	echo "Examples:"
	echo "- what processes use most RAM:"
	echo "  $name '.*' Pss smaps.cap"
	echo "- what processes are most on swap:"
	echo "  $name '.*' Swap smaps.cap"
	echo "- what processes have largest heaps:"
	echo "  $name '\[heap\]' Size smaps.cap"
	echo "- which processes' executable code sections are writable:"
	echo "  $name ' rwxp ' Size smaps.cap"
	echo "- total of given sized anonymous allocs (unnamed mappings) in processes:"
	echo "  $name ' 0 \$' 'Size: *2044 ' smaps.cap"
	echo
	echo "ERROR: $1!"
	echo
	exit 1
}

if [ $# -ne 3 ]; then
	usage "wrong number of arguments"
fi
if [ -z "$(echo ""$2""|grep -e '^Size' -e '^Rss' -e '^Pss' -e '^Shared_Clean' -e '^Shared_Dirty' -e '^Private_Clean' -e '^Private_Dirty' -e '^Referenced' -e '^Swap')" ]; then
	usage "unknown SMAPS field used in '$2'"
fi
if [ \! -f "$3" ]; then
	usage "file '$3' doesn't exist"
fi

mapping=$(echo "$1"|sed 's%/%\\/%g')	# quote awk pattern delimiters
field="${2%%:*}"			# SMAPS field used for checking
line="$2"				# full SMAPS field line to match
file="$3"

heading="Size:\t\tPID:\tName:\n"

echo "finding process totals for field '$field' matching line '$line'"
echo "in '$mapping' mappings from file '$file'..."
echo
printf $heading

awk '
function mapping_usage () {
	if (size) {
		printf("%5d kB\t%5d\t%s\n", size, pid, name);
		size = 0;
	}
}
/^#Name/ {
	mapping_usage();
	name = $2;
	next;
}
/^#Pid/ {
	mapping_usage();
	pid = $2;
	next;
}
# hex address range, stuff, mapping name
/^[0-9a-f]+-[0-9a-f]+.*'"$mapping"'/ {
	mapping = 1;
	map = $6;
	next;
}
/^'"$line"'/ {
	if (mapping > 0) {
		mapping = 0;
		size += $2;
	}
	next;
}
/^'"$field"'/ {
	mapping = 0;
	next;
}
END {
	mapping_usage();
}
' "$file"|sort -n
printf $heading
