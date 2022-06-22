#!/usr/bin/env bash

if [ "$#" -ne 2 ]; then
    echo "usage: $0 [kindle_IP] [update | ssh | start | copy-ssh-key]"
    exit 1
fi

IP="$1"
COMMAND="$2"

i=0
until ssh -o ConnectTimeout=1 root@$IP /mnt/us/extensions/homeassistant/daemon.sh stop 2>/dev/null
do
    # only print every 5th itneration....
    ((i % 60 == 0)) && echo -ne "\n[$(date)] waiting"
    echo -n "."
    ((i=i+1))
    sleep 0.5
done
echo ""

if [ $COMMAND == "update" ]; then
    echo "Running update for $IP"
    rsync -rhP extensions/homeassistant/ root@$IP:/mnt/us/extensions/homeassistant/
    rsync -rhP kite/ root@$IP:/mnt/us/kite
    ssh -o ConnectTimeout=1 root@$IP /mnt/us/extensions/homeassistant/daemon.sh start
elif [ $COMMAND == "ssh" ]; then
    ssh -o ConnectTimeout=1 root@$IP
elif [ $COMMAND == "start" ]; then
    ssh -o ConnectTimeout=1 root@$IP /mnt/us/extensions/homeassistant/daemon.sh start
elif [ $COMMAND == "copy-ssh-key" ]; then
    cat "$HOME/.ssh/id_rsa.pub" | ssh -o ConnectTimeout=1 root@$IP "cat - >> /mnt/us/usbnet/etc/authorized_keys"
else
  echo "unknown command: $COMMAND"
  exit 2
fi
