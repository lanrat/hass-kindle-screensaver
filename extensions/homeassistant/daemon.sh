#!/bin/sh
#set -o xtrace

DAEMON_PATH="/mnt/us/extensions/homeassistant"

DAEMON="./script.sh"
DAEMONOPTS=""

NAME=homeassistant
# shellcheck disable=SC2034  # Unused variables left for readability
DESC="Home Assistant daemon"
PIDFILE="$DAEMON_PATH/$NAME.pid"
SCRIPTNAME="/etc/init.d/$NAME"

case "$1" in
start)
    if [ -f $PIDFILE ]; then
        PID="$(cat $PIDFILE)"
        # shellcheck disable=SC2009 # pgrep does not work here
        if [ -n "$PID" ] && ps axf | grep -v grep | grep -q "$PID"; then
            echo "$SCRIPTNAME is already running with PID $PID"
            exit 1
        fi
    fi
	printf "%-50s\n" "Starting $NAME..."
    # shellcheck disable=SC2086 # want to allow splitting
	PID=$(cd "$DAEMON_PATH" && $DAEMON $DAEMONOPTS > /dev/null 2>&1 & echo $!)
	echo "Saving PID $PID to $PIDFILE"
    if [ -z "$PID" ]; then
        printf "%s\n" "Fail"
    else
        echo "$PID" > "$PIDFILE"
        printf "%s\n" "Ok"
        echo "0" > "$DAEMON_PATH/count.txt"
    fi
    exit

;;
status)
    printf "%-50s\n" "Checking $NAME..."
    if [ -f $PIDFILE ]; then
        PID="$(cat $PIDFILE)"
        echo "Checking on PID $PID"
        # shellcheck disable=SC2009 # pgrep does not work here
        if ! ps axf | grep -v grep | grep -q "$PID"; then
            printf "%s\n" "Process dead but pidfile exists"
        else
            echo "Running: $(cat $DAEMON_PATH/count.txt)"
        fi
    else
        printf "%s\n" "Service not running"
    fi
    exit
;;
stop)
    printf "%-50s\n" "Stopping $NAME"
    if [ -f $PIDFILE ]; then
        PID="$(cat $PIDFILE)"
        echo "Killing PID $PID"
        kill -HUP "$PID"
        ok=$?
        if [ $ok -eq 0 ]; then
            lipc-set-prop com.lab126.pillow disableEnablePillow enable 2>/dev/null
            "$DAEMON_PATH/bin/wmctrl" -r L:C_N:titleBar_ID:system -e '0,0,0,600,30' 2>/dev/null
            printf "%s\n" "Ok"
            rm -f "$PIDFILE"
        fi
    else
        printf "%s\n" "pidfile not found: $PIDFILE"
    fi
    # force killling children just in case
    # shellcheck disable=SC2046
    kill $(pgrep -f "$DAEMON")
    exit
;;

restart)
  	$0 stop
  	$0 start
;;

*)
    echo "Usage: $0 {status|start|stop|restart}"
    exit 1
esac
