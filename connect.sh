#!/usr/bin/env bash
set -eu
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [ "$#" -ne 2 ]; then
    echo "usage: $0 [kindle_IP] [update | ssh | start | stop | restart | status | copy-ssh-key]"
    exit 1
fi

IP="$1"
COMMAND="$2"

cd "$SCRIPT_DIR"

ssh_options="-o ConnectTimeout=1 -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa"

i=0
until ssh $ssh_options "root@$IP" hostname 2>/dev/null
do
    # only print every 5th itneration....
    ((i % 60 == 0)) && echo -ne "\n[$(date)] waiting"
    echo -n "."
    ((i=i+1))
    sleep 0.5
done
echo ""

if [ "$COMMAND" == "update" ]; then
    echo "Running update for $IP"
    rsync -e "ssh $ssh_options" -rhP extensions/homeassistant/ "root@$IP:/mnt/us/extensions/homeassistant/"
    rsync -e "ssh $ssh_options" -rhP kite/ "root@$IP:/mnt/us/kite"
elif [ "$COMMAND" == "ssh" ]; then
    ssh $ssh_options "root@$IP"
elif [ "$COMMAND" == "status" ]; then
    ssh $ssh_options "root@$IP" /mnt/us/extensions/homeassistant/daemon.sh status
elif [ "$COMMAND" == "start" ]; then
    ssh $ssh_options "root@$IP" /mnt/us/extensions/homeassistant/daemon.sh start
elif [ "$COMMAND" == "stop" ]; then
    ssh $ssh_options "root@$IP" /mnt/us/extensions/homeassistant/daemon.sh stop
elif [ "$COMMAND" == "restart" ]; then
    ssh $ssh_options "root@$IP" /mnt/us/extensions/homeassistant/daemon.sh restart
elif [ "$COMMAND" == "copy-ssh-key" ]; then
    echo "copying $HOME/.ssh/id_rsa.pub to /mnt/us/usbnet/etc/authorized_keys"
    cat "$HOME/.ssh/id_rsa.pub" | ssh $ssh_options "root@$IP" "cat - >> /mnt/us/usbnet/etc/authorized_keys"
else
  echo "unknown command: $COMMAND"
  exit 2
fi
