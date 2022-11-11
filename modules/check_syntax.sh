check_number(){
    # Check if parameter $1 is a number and positive
	local REGEX='^[0-9]+$'
	if ! [[ $1 =~ $REGEX ]]; then
		echo "Error: \"$1\" is not a number." >&2
		exit 1
	elif [ "$1" -lt 1 ]; then
		echo "Error: \"$1\" must be greather then 0." >&2
		exit 1
	fi
}

check_ipcidr(){
    if [ "$1" = "" ]; then
		return dhcp
	fi
	
	local IPCIDR='(((25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?))(\/([8-9]|[1-2][0-9]|3[0-2]))([^0-9.]|$)'
	if [[ "$1" =~ $IPCIDR ]]; then
		true
		# echo "$1 validated."
		# return $1
	else
		echo "Error: $1 is not a valid IP address. Use 'A.B.C.D/CIDR'."
        exit 1
	fi

}

check_ip(){
    local IP='^(0*(1?[0-9]{1,2}|2([0-4][0-9]|5[0-5]))\.){3}'
    local IP+='0*(1?[0-9]{1,2}|2([‌​0-4][0-9]|5[0-5]))$'
    if [[ "$1" =~ $IP ]]; then
        true
	# echo "$1 validated."
    else
		echo "Error: $1 is nota valid IP address. Use 'A.B.C.D'. for $2"
        exit 1
    fi
}

