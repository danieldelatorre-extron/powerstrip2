#!/bin/bash
# Script to control an PDU4H or PDU8L.

username="${PDU_USERNAME:-admin}"
password="${PDU_PASSWORD:-extron}"
type="ac"

ip=""
port=""
state=""
sleep_toggle=2

usage()
{
    echo "Usage: powestrip2 [options] -i ip -p port state"
    echo "Arguments:"
    echo "    -i ip         IP address or hostname."
    echo "    -p port       AC or DC power port number."
    echo "    state         Valid values are: 0, 1, and toggle."
    echo "Options:"
    echo "    -u username   Username, default is '${username}'."
    echo "    -P password   Password, default is '${password}'."
    echo "    -t type       Power type, default is '${type}'."
    echo "    -s sleep      Sleep in between toggle, default is ${sleep_toggle}s."
    exit 1
}

if ! command -v sshpass &> /dev/null
then
    echo "Error: sshpass is not installed. To install it, try 'sudo apt install sshpass'."
    exit 1
fi

while getopts "i:p:u:p:hP:t:s:" opt
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
        s)
            sleep_toggle=$OPTARG
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

set_power()
{
    local val=$1
    cmd="w${port}*${val}pc\r"

    type_lower="${type,,}"
    if [ "$type_lower" == "dc" ]
    then
        cmd="wp${port}*${val}dcpp\r"
    fi

    # Allow greeting to finish printing, send the command, then send ctl+c.
    {
        sleep 1.7
        printf '%b' "${cmd}"
        sleep 0.5
        printf '\003'
    } | timeout --signal=INT 4s sshpass -p "$password" ssh -tt -p 22023 \
            -o ConnectionAttempts=2 \
            -o ConnectTimeout=1 \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            "$username@$ip"
}

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
    if ! ping "$ip" -c 1 -W 1 > /dev/null 2>&1
    then
        echo "Error: Host $ip is unreachable."
        exit 1
    fi

    case "${state:0:1}" in
        0|1)
            set_power "$state"
            ;;
        t|T)
            set_power 0
            sleep "$sleep_toggle"
            set_power 1
            ;;
        *)
            echo "invalid state"
            usage
            ;;
    esac
    
    exit 0
fi
