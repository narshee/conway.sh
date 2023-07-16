#!/bin/sh
#Conway's Game of Life in POSIX Shell

trap 'exit_program' INT QUIT TERM

setup_terminal() {
	printf '\033[1;1H'
	# hide cursor
	printf '\033[?25l'
	# clear screen
	printf '\033[2J'
}

exit_program() {
	# show cursor
	printf '\033[?25h'

	exit
}

rand() {
	# rand 3
	# "$1" must be (2^d)-1, so all digits are 1 in binary
	# give random number from 0 to "$1"
	# this is actually quite good & fast. didn't think it could be elegant
	# I think the distribution is skewed towards smaller numbers,
	# because the number of bytes read is by definition on avarage 255
	# as the char 'newline' is 1 in 2^8

	# /dev/random is not posix
	read -r x </dev/random

	# ${#x} # number of bytes read from /dev/random
	echo "$((${#x} & $1))"
}

fill_cells() {
	# fill cells randomly

	cells=''

	# area * 2 because for every cell, we have a space for later seperation when using set
	while [ "${#cells}" -lt "$((length * length * 2))" ]; do
		rand_var="$(rand "$rand_range")"

		n=0
		while [ "$((1 << n))" -le "$rand_range" ]; do
			if [ "$(((rand_var & (1 << n)) >> n))" -eq 1 ]; then
				cells="$cells"' '"$living"
			else
				cells="$cells"' '"$dead"
			fi
			n="$((n + 1))"
		done
	done

	echo "$cells"
}

print() {
	# print "$@"

	# go to terminal beginning
	printf '\033[1;1H'

	echo "Generations: $generation"

	n=1
	for i; do
		printf '%s' "$i"

		if [ "$n" -eq "$length" ]; then
			printf '\n'
			n=1
			continue
		fi

		n="$((n + 1))"
	done
}

get_start_i() {
	# set starting position of i
	# we check for bounds
	# when we are in the first line the element 1 up and 1 left is out of bounds
	if [ "$line" -eq 1 ]; then
		# when we are in the first element of the first line, to the left is oob
		if [ "$((n - 1))" -le 1 ]; then
			start_i=1
		else
			start_i="$((n - 1))"
		fi
	# we are not in the first line
	else
		# when we are in the first element of a line, to the left is oob
		if [ "$n" -eq "$socl" ]; then
			start_i="$((socl - length))"
		else
			start_i="$((n - length - 1))"
		fi
	fi
}

get_end_i() {
	# set ending position of i
	# we check for bounds
	# when we are in the last line the element 1 down and 1 right is oob
	if [ "$line" -eq "$length" ]; then
		# when we are in the last element of the last line, to the right is oob
		if [ "$((n + 1))" -ge "$((length * length))" ]; then
			end_i="$((length * length))"
		else
			end_i="$((n + 1))"
		fi
	# we are not in the last line
	else
		# when we are in the last element of a line, to the right is oob
		if [ "$n" -eq "$eocl" ]; then
			end_i="$((eocl + length))"
		else
			end_i="$((n + length + 1))"
		fi
	fi
}

get_line_edges() {
	# sets eocl, socl & line

	# end of current line #multiple of length
	eocl="$length"
	while [ "$eocl" -lt "$n" ]; do
		eocl="$((eocl + length))"
		line="$((line + 1))"
	done

	# start of current line
	socl="$((eocl - length + 1))"
}

count_neighbours() {
	# check 3x3 (at max) cells around current cell. current cell is also counted

	alive=0

	i="$start_i"
	while [ "$i" -le "$end_i" ]; do

		# count alive neighbour cells, this includes own cell
		if eval [ $\{$i} = "$living" ]; then
			alive="$((alive + 1))"
		fi

		#TODO: comment this
		# bounds check
		# in first and last line
		if [ "$line" -eq 1 ] || [ "$line" -eq "$length" ]; then

			if [ "$((i + 1))" -gt "$((end_i - length))" ] && [ "$((i + 1))" -le "$((start_i + length))" ]; then
				# go to one cell under starting point
				i="$((start_i + length))"
			else
				i="$((i + 1))"
			fi
		# not in the first or last line
		else

			if [ "$((i + 1))" -gt "$((end_i - length - length))" ] && [ "$((i + 1))" -le "$((start_i + length))" ]; then
				# go to cell under starting point
				i="$((start_i + length))"

			elif [ "$((i + 1))" -gt "$((end_i - length))" ] && [ "$((i + 1))" -le "$((start_i + length + length))" ]; then
				# go to two cells under starting point
				i="$((start_i + length + length))"
			else
				i="$((i + 1))"
			fi

		fi
	done

	# subtract own cell if it is alive
	if eval [ $\{$n} = "$living" ]; then
		alive="$((alive - 1))"
	fi

	echo "$alive"
}

help() {
	printf 'Usage: %s %s\n' "$0" '[options...]
 -h, --help           Print this
 -l, --length <int>   Set play area length. default: 20
 -r, --rand <int>     Set rand_range.       default: 3

length^2 = size of the square play area, aka number of cells.
must be multiple of number of bits of rand_range.
length >= number of bits of rand_range.
rand_range must be (2^d)-1, so all digits are 1 in binary.

Exit with Ctrl-C'
}

handle_options() {
	while [ "$#" -gt 0 ]; do
		case "$1" in
			-h | --help)
				help
				exit
				;;
			-l | --length)
				shift
				length="$1"
				;;
			-r | --rand)
				shift
				rand_range="$1"
				;;
			*) ;;
		esac
		shift
	done
}

check_dev_random() {
	# if /dev/random not readable
	if [ ! -r '/dev/random' ]; then
		printf '%s\n' '/dev/random is not readable. It can be replaced with another rng file'
		exit 1
	fi
}

main() {

	check_dev_random
	handle_options "$@"

	# length^2 = size of the square play area, aka number of cells
	# must be multiple of number of bits of rand_range
	# length >= number of bits of rand_range
	# rand_range must be (2^d)-1, so all digits are 1 in binary
	length=20
	rand_range=3
	# BUG: '#' and ' ' break
	living='X'
	dead='_'

	eval set -- "$(fill_cells)"

	# set seed here if you want
	# also set length and rand_range
	# set -- 1 1 1 1 1 0 0 1 1 0 0 0 1 0 1 1

	generation=0
	setup_terminal
	print "$@"

	generation=1
	# main loop
	while :; do
		#	# manual mode
		#	while read -r input; do
		#		# user input
		#		case "$input" in
		#			q) exit_program;;
		#			r)
		#				generation=0
		#				setup_terminal
		#				eval set -- "$(fill_cells)"
		#				print "$@"
		#				continue
		#				;;
		#			*) ;;
		#		esac

		cells=''
		n=1
		#check each cell
		while [ "$n" -le "$((length * length))" ]; do
			# which line we are in atm
			line=1
			get_line_edges

			get_start_i
			get_end_i

			# determine cell status for next generation
			case "$(count_neighbours "$@")" in
				2) cells="$cells"' '"\${$n}" ;;  # will stay the same
				3) cells="$cells"' '"$living" ;; # will be alive; reproduction
				*) cells="$cells"' '"$dead" ;;   # will be dead; underpopulation or overpopulation
			esac
   
			n="$((n + 1))"
		done

		# Prepare and re-parsing with eval.
		# Remove leading space and add leading & trailing double quotes.
		# Example without the double quotes:
		# x='1 2'; eval y="$x"
		# gets parsed as
		# y=1 2
		eval cells='"'"${cells# }"'"'

		# check if they are identically
		# "$@" does not work
		if [ "$cells" = "$*" ]; then
			echo still
			exit_program
		fi

		eval set -- "$cells"
		print "$@"

		generation="$((generation + 1))"
	done

}

main "$@"
