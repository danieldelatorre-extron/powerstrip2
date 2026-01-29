#!/bin/bash
# Script to control an PDU4H or PDU8L.

username="${PDU_USERNAME:-admin}"
password="${PDU_PASSWORD:-extron}"
type="ac"

ip=""
port=""
state=""

usage()
{
    echo "Usage: powestrip2 [options] -i ip -p port state"
    echo "Arguments:"
    echo "    -i ip         IP address or hostname."
    echo "    -p port       AC or DC power port number."
    echo "    state         Use 0 for off and 1 for on."
    echo "Options:"
    echo "    -u username   Username, default is '${username}'."
    echo "    -P password   Password, default is '${password}'."
    echo "    -t type       Power type, default is '${type}'."
    exit 1
}

if ! command -v sshpass &> /dev/null
then
    echo "Error: sshpass is not installed. To install it, try 'sudo apt install sshpass'."
    exit 1
fi

while getopts "i:p:u:p:hP:t:" opt
do
    case $opt in
        i)
            ip=$OPTARG
            ;;
        p)
            port=$OPTARG
            ;;
        u)
            username=$OPTARG
            ;;
        P)
            password=$OPTARG
            ;;
        t)
            type=$OPTARG
            ;;
        h|*)
            usage
            ;;
    esac
done

shift $((OPTIND-1))

state="$1"

if [ -z "$ip" ]
then
    echo "Error: IP address is required."
    usage
elif [ -z "$port" ]
then
    echo "Error: Port number is required."
    usage
elif [ -z "$state" ]
then
    echo "Error: State (0 or 1) is required."
    usage
else
    cmd="w${port}*${state}pc\r"

    type_lower="${type,,}"
    if [ "$type_lower" == "dc" ]
    then
        cmd="wp${port}*${state}dcpp\r"
    fi

printf '%b' "$cmd" | timeout 3s \
sshpass -p "$password" ssh -tt -p 22023 \
  -o ConnectTimeout=3 \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "$username@$ip"
fi
