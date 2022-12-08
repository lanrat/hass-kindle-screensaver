#!/bin/bash

kill_kindle() {
    /etc/init.d/framework stop >/dev/null 2>&1
    /sbin/stop framework  >/dev/null 2>&1
    /etc/init.d/cmd stop >/dev/null 2>&1
    /sbin/stop cmd  >/dev/null 2>&1
    /etc/init.d/phd stop >/dev/null 2>&1
    /sbin/stop phd  >/dev/null 2>&1
    /etc/init.d/volumd stop >/dev/null 2>&1
    /sbin/stop volumd  >/dev/null 2>&1
    /etc/init.d/tmd stop >/dev/null 2>&1
    /sbin/stop tmd  >/dev/null 2>&1
    /etc/init.d/webreaderd stop >/dev/null 2>&1
    /sbin/stop webreaderd  >/dev/null 2>&1
    killall lipc-wait-event >/dev/null 2>&1
}

customize_kindle() {
    mkdir -p /mnt/us/update.bin.tmp.partial # prevent from Amazon updates
    touch /mnt/us/WIFI_NO_NET_PROBE         # do not perform a WLAN test
}

wait_wlan() {
    return "$(lipc-get-prop com.lab126.wifid cmState | grep -c CONNECTED)"
}

wait_ping() {
    CONNECTED=0
    /bin/ping -c 1 "$PINGHOST" >/dev/null && CONNECTED=1
    return $CONNECTED
}

logger() {
    MSG=$1

    # do nothing if logging is not enabled
    if [ "x1" != "x$LOGGING" ]; then
        return
    fi

    # if no logfile is specified, set a default
    if [ -z "$LOGFILE" ]; then
        LOGFILE=stdout
    fi

    echo "$(TZ=$TZ date)": "$MSG" >> $LOGFILE
}


hideStatusBar() {
    #logger "hiding the status bar"
    "$SCRIPTDIR/bin/wmctrl" -r L:C_N:titleBar_ID:system -e '0,0,0,600,1' 2>/dev/null
    lipc-set-prop com.lab126.pillow disableEnablePillow disable 2>/dev/null
}

hideStatusBarLoop() {
    while true
    do
        hideStatusBar
        sleep 5
    done
}