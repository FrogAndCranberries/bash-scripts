#!/bin/bash

##################################
# Variables
##################################

user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
server_path=/etc/openvpn/client/surfshark/
location=uk-lon
config_suffix_udp=.prod.surfshark.com_udp.ovpn
config_suffix_tcp=.prod.surfshark.com_tcp.ovpn
pid_path=/tmp/openvpn-surfshark-michal.pid
log_path=$user_home/.local/log/surfshark-vpn.log

##################################
# Help
##################################

Help(){
# Display usage
cat << EOF
Manages a Surfshark OpenVPN connection daemon from config files in /etc/openvpn/client/surfshark. Default server to connect to is London (uk-lon).
Server locations are in format [2 letter country code]-[3 letter city code], e.g. (uk-lon).

Usage: surfvpn [-h|-s|-f|-k|-l|-a|-i|-t]
Options:
-h			Display this Help
-s			Start a vpn connection to the default server
-f			Connect to the Fastest vpn server (pick one from current country)
-k			Kill existing vpn connection
-l "server location"	Connect to a server in custom Location, possibly modifying existing connection
-a			Display all Available server locations
-i			Display Info on current vpn connection
-t			Use TCP instead of UDP (default)

EOF
}

##################################
# Functions
##################################

Print_locations(){
# Print all available server countries and cities
find $server_path -maxdepth 1 -type f | awk -F/ '{print $NF}' | awk -F. '$4 == "com_udp" {print $1}' | column -t
}

Kill_connection(){
if [[ -f $pid_path ]] && kill $(cat $pid_path) 2>$log_path ; then
	rm -f $pid_path
	echo "VPN connection closed."
else
	echo "VPN connection was not running."
fi
}

Display_connection_info(){
if [[ -f $pid_path ]]; then
	pid=$(cat $pid_path)
	if kill -0 $pid 2>/dev/null ; then
		server=$(pgrep -a openvpn 2>/dev/null |  grep $pid | awk -F'surfshark/|\\.prod' '{print $2}')
		echo "VPN connected to server $server."
	else
		rm $pid_path
		echo "No managed VPN connection is active, a stray PID file was removed."
	fi

	if pgrep openvpn 2>/dev/null | grep -v $pid ; then
		echo "Another VPN connection not managed by the script is active:"
		pgrep -a openvpn
	fi
else
	if pgrep openvpn 2>/dev/null ; then
		echo "Another VPN connection not managed by the script is active:"
		pgrep -a openvpn
	else
		echo "No active VPN connections."
	fi

fi
}

Check_sudo(){
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (e.g., via sudo)"
  exit 1
fi
}

##################################
# Check sudo and get options
##################################

Check_sudo

while getopts ":hsfkail:t" option; do
	case $option in
		h) # Display help
			Help
			exit ;;
		s) # Connect to the default server
			start_connection_flag=true ;;
		f) # Connect to the fastest server
			echo "Fastest server search not implemented yet."
			exit ;;
		k) # Kill existing connection
			kill_connection_flag=true ;;
		a) # Display all available server locations
			Print_locations
			exit ;;
		i) # Display information about current connection
			Display_connection_info
			exit ;;
		l) # Set custom location
			location=$OPTARG
			start_connection_flag=true ;;
		t) # Use TCP instead of UDP
			tcp=true ;;
		\?) # Invalid option
			echo "Invalid option: -$OPTARG"
			echo "Display usage with $0 -h"
			exit ;;
		:) # Missing argument
			echo "Missing argument for option: -$OPTARG"
			echo "Display usage with $0 -h"
			exit ;;
	esac
done

if [[ $start_connection_flag == true && $kill_connection_flag == true ]]; then
	echo "Cannot use both -s and -k flags to start and kill a connection at the same time."
	echo "Use $0 -h to display usage."
	exit 
fi

if [[ $start_connection_flag == true ]]; then
	
	if [[ $tcp == true ]]; then
		config_path=$server_path$location$config_suffix_tcp
	else 
		config_path=$server_path$location$config_suffix_udp
	fi

	if [[ ! -f $config_path ]]; then
		echo "Invalid server location $location, config file $config_path does not exist."
		exit
	fi

	if [[ -f $pid_path ]]; then
		PID=$(cat $pid_path)
		Kill_connection
		for i in {1..10}; do
			if kill -0 $PID 2>/dev/null; then
				sleep 0.3
			else break
			fi
		done
	fi
	if pgrep -x openvpn >/dev/null ; then
		echo "Another OpenVPN connection is active, aborting."
		exit 1
	fi

	if openvpn --config $config_path --auth-user-pass /etc/openvpn/surfshark-login.txt --daemon --writepid $pid_path &>$log_path ; then
		echo "A new surfshark VPN connection to server $location was started."
	else
		echo "Error when opening VPN connection - check script logs in $log_path."
	fi

	
fi

if [[ $kill_connection_flag == true ]]; then
	Kill_connection
fi

exit 0
