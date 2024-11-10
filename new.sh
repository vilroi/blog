#!/bin/sh

is_valid_content() {
	case "$1" in 
		"posts" | "notes" )
			return 1
			;;
		* )
			return 0
			;;
	esac
}

#is_valid_content () {
#	find content -type d -name "$1" 2>/dev/null 1>&2
#}

main() {
	if [ $# -ne 1 ]; then
		echo "usage: $0 [content-type]"
		echo "content-type:"
		printf "\tposts: new blog post\n"
		printf "\tnotes: new notes\n"
		exit 1
	fi

	what=$1
	if is_valid_content "$what"; then
		echo "Invalid content type: $what"
		exit 1
	fi

	path="content/$what/$(date +%Y%m%d%H%M%S).md"
	hugo new "$path"
	vim "$path"
}

main "$@"
