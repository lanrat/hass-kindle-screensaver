#!/bin/bash
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

# load config
if [ -e "config.sh" ]; then
    # shellcheck source=./config.sh
    . ./config.sh
else
    logger "Could not find config.sh in $(pwd)"
    echo "Could not find config.sh in $(pwd)"
    exit
fi

# load utils
if [ -e "utils.sh" ]; then
    # shellcheck source=./utils.sh
    . ./utils.sh
else
    logger "Could not find utils.sh in $(pwd)"
    echo "Could not find utils.sh in $(pwd)"
    exit
fi

kill_kindle
customize_kindle

# do not background any processess, they will not be stopped with the service
#hideStatusBarLoop &

GLOBAL_ERROR_COUNT=0

logger "starting service with PID $$"

while true; do
    echo "Starting new loop on PID $$"
    logger "START NEW LOOP on PID $$"

    logger "Set CPU scaling governer to powersave"
    echo powersave >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

    logger "Set prevent screen saver to true"
    lipc-set-prop com.lab126.powerd preventScreenSaver 1

    logger "Checking battery level"

    CHARGING_FILE="$(kdb get system/driver/charger/SYS_CHARGING_FILE)"
    IS_CHARGING=$(cat "$CHARGING_FILE")
    CHECKBATTERY=$(gasgauge-info -s | sed 's/.$//')
    CHECKCHARGECURRENT=$(gasgauge-info -l | sed 's/mA//g')
    
	logger "Battery: isCharging=$IS_CHARGING percentage=$CHECKBATTERY% current=${CHECKCHARGECURRENT}mA" 

    if [ "$IS_CHARGING" -eq 1 ] && [ "$CHECKBATTERY" -le "$RESTART_POWERD_THRESHOLD" ] && [ "$CHECKCHARGECURRENT" -le 0 ]; then
        logger "Restarting powerd"
        if [ -f /etc/init.d/powerd ]; then
            /etc/init.d/powerd restart
        fi
        if [ -f /usr/bin/powerd ]; then
            /usr/bin/powerd restart
        fi
    fi
    
    if [ "$IS_CHARGING" -ne 1 ] && [ "$CHECKBATTERY" -le "$BATTERYLOW" ]; then
        logger "Battery below $BATTERYLOW"
        "$SCRIPTDIR/bin/fbink" --quiet --flash -g w=-1,file="$LIMGBATT"
        # waiting time when charging until battery level is higher than "BATTERYLOW" otherwise it will fall into sleep again
        if [ "$USE_RTC" -eq 1 ]; then
            "$SCRIPTDIR/bin/rtcwake" -d "rtc$RTC" -s "$BATTERYSLEEP" -m mem
        else
            sleep "$BATTERYSLEEP"
        fi
    else
        logger "Remaining battery $CHECKBATTERY"
    fi

    ### activate wifi
    logger "Enabling and checking wifi"
    lipc-set-prop com.lab126.wifid enable 1

    logger "Check wifi connection"
    WLANNOTCONNECTED=0
    WLANCOUNTER=0
    PINGNOTWORKING=0
    PINGCOUNTER=0
    ERROR_SUSPEND=0

    ### wait for wifi
    while wait_wlan; do
        if [ ${WLANCOUNTER} -gt 5 ]; then
            logger "Trying Wifi reconnect"
            /usr/bin/wpa_cli -i "$NET" reconnect
        fi
        if [ ${WLANCOUNTER} -gt 30 ]; then
            logger "No known wifi found"
            logger "DEBUG ifconfig $(ifconfig "$NET")"
            logger "DEBUG cmState $(lipc-get-prop com.lab126.wifid cmState)"
            logger "DEBUG signalStrength $(lipc-get-prop com.lab126.wifid signalStrength)"
            "$SCRIPTDIR/bin/fbink" --quiet --flash -g w=-1,file="$LIMGERRWIFI"
            WLANNOTCONNECTED=1
            ERROR_SUSPEND=1 #short sleeptime will be activated
            break 1
        fi
        WLANCOUNTER=$((WLANCOUNTER+1))
        logger "Waiting for wifi $WLANCOUNTER"
        sleep $WLANCOUNTER
    done

    if [ ${WLANNOTCONNECTED} -eq 0 ]; then
        logger "Connected to wifi"

        ### lost standard gateway if wifi is not available
        GATEWAY=$(ip route | grep default | grep "$NET" | awk '{print $3}')
        logger "Found default gateway $GATEWAY"
        if [ -z "$GATEWAY" ]; then
            route add default gw "$ROUTERIP"
            logger "Default gateway lost after sleep"
            logger "Setting default gateway to $ROUTERIP"
        fi

        logger "waiting for ping"

        ### wait for working ping
        while wait_ping; do
            if [ ${PINGCOUNTER} -gt 5 ]; then
                logger "Trying Wifi reconnect"
                /usr/bin/wpa_cli -i "$NET" reconnect
            fi
            if [ ${PINGCOUNTER} -gt 10 ]; then
                logger "Ping not working"
                logger "DEBUG ifconfig $(ifconfig "$NET")"
                CMSTATE=$(lipc-get-prop com.lab126.wifid cmState)
                logger "DEBUG cmState $CMSTATE"
                logger "DEBUG signalStrength $(lipc-get-prop com.lab126.wifid signalStrength)"
                "$SCRIPTDIR/bin/fbink" --quiet --flash -g w=-1,file="$LIMGERRWIFI"
                
                PINGNOTWORKING=1
                ERROR_SUSPEND=1 #short sleeptime will be activated
                break 1
            fi
            PINGCOUNTER=$((PINGCOUNTER+1))
            logger "Waiting for working ping ${PINGCOUNTER}"
            logger "Trying to set route gateway to ${ROUTERIP}"
            route add default gw "$ROUTERIP"
            sleep "$PINGCOUNTER"
        done

        if [ ${PINGNOTWORKING} -eq 0 ]; then
            logger "Ping worked successfully"

            iwconfig=/sbin/iwconfig
            if [ -f /usr/sbin/iwconfig ]; then
                iwconfig=/usr/sbin/iwconfig
            fi

            # get data to send
            IP="$(ip addr show "$NET" | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')"
            MAC_ADDRESS="$(cat "/sys/class/net/$NET/address")"
            SN="$(cat /proc/usid)"
            BOOTTIME="$(stat -c %Z /)"
            WIFISIGNAL="$($iwconfig "$NET" | grep level | cut -d: -f3 | cut -d' ' -f1)"
            COUNT="$(cat "$SCRIPTDIR/count.txt")"
            BATTERYLEVEL="$(/usr/bin/powerd_test -s | awk -F: '/Battery Level/ {print substr($2, 0, length($2)-1) - 0}')"
            CHARGING=false
            if /usr/bin/powerd_test -s | awk -F: '/Charging/ {print substr($2,2,length($2))}' | grep -qi 'yes'; then
                CHARGING=true
            fi

            logger "Downloading and drawing image"
            curl --insecure \
                --retry 3 \
                --silent \
                --location \
                --output "$TMPFILE" \
                --header "X-HASS-Name: $KINDLE_NAME" \
                --header "X-HASS-IP: $IP" \
                --header "X-HASS-Mac_Address: $MAC_ADDRESS" \
                --header "X-HASS-Serial_Number: $SN" \
                --header "X-HASS-Boot_Time: $BOOTTIME" \
                --header "X-HASS-WiFi_Signal: $WIFISIGNAL" \
                --header "X-HASS-Count: $COUNT" \
                --header "X-HASS-Battery_Level: $BATTERYLEVEL" \
                --header "X-HASS-Charging: $CHARGING" \
                "$IMAGE_URI"
            DOWNLOADRESULT=$?
            logger "Download result $DOWNLOADRESULT"

            if [ $DOWNLOADRESULT -eq 0 ]; then
                mv "$TMPFILE" "$SCREENSAVERFILE"
                logger "Screen saver image file updated"
                # check refresh counter
                logger "update count $c"
                # this blocks, not sure why....
                if [ $((c % REFRESH_EVERY)) -eq 0 ]; then
                    logger "refreshing screen"
                    "$SCRIPTDIR/bin/fbink" --quiet -hk
                fi

                if [ "$CLEAR_SCREEN_BEFORE_RENDER" -eq 1 ]; then
                    logger "clearing screen"
                    eips -c
                    sleep 1
                fi
                logger "rendering screen"
                "$SCRIPTDIR/bin/fbink" --quiet --flash -g w=-1,file="$SCREENSAVERFILE"
                if [ "$DISPLAY_REFRESH_TIME" = true ] ; then
                    # display update time
                    "$SCRIPTDIR/bin/fbink" --quiet --flash --size 1 -y -1 "$(TZ=$TZ date -R +'%H:%M')"
                fi
                if [ "$DISPLAY_BATTERY_LEVEL" = true ] ; then
                    # display battery %
                    bat="${BATTERYLEVEL}%"
                    batLen="$(echo -n "$bat" | wc -c)"
                    "$SCRIPTDIR/bin/fbink" --quiet --flash --size 1 -y -1 -x -"$batLen" "$bat"
                fi
                logger "updating counter"
                c=$((c+1))
                echo "$c" > "$SCRIPTDIR/count.txt"
                logger "counter set to: $(cat "$SCRIPTDIR/count.txt")"
                
            else
                logger "Error updating screensaver"
                if [ "$CLEAR_SCREEN_BEFORE_RENDER" -eq 1 ]; then
                    eips -c
                    sleep 1
                fi
                "$SCRIPTDIR/bin/fbink" --quiet --flash -g w=-1,file="$LIMGERR"
                ERROR_SUSPEND=1       #short sleep time will be activated
            fi

            rm -f "$TMPFILE"
            logger "Removed temporary files"

            if [ ${CHARGING} != true ] && [ "$CHECKBATTERY" -le "$BATTERYALERT" ]; then
                "$SCRIPTDIR/bin/fbink" --quiet --flash --centered --row -3 --size 4 "Battery at $CHECKBATTERY%, please charge"
            fi
        fi
    fi

    sleep "$DELAY_BEFORE_SUSPEND"

    logger "Calculate next timer and going to sleep"

    if [ ${ERROR_SUSPEND} -eq 1 ]; then
        GLOBAL_ERROR_COUNT=$((GLOBAL_ERROR_COUNT+1))
        TODAY=$(date +%s)
        WAKEUPTIME=$((TODAY + INTERVAL_ON_ERROR - DELAY_BEFORE_SUSPEND))
        logger "An error has occurred, will try again on $WAKEUPTIME"

        if [ ${GLOBAL_ERROR_COUNT} -ge 10 ]; then
            logger "REBOOT BECAUSE OF 10 ERRORS"
            reboot
        fi

        if [ "$USE_RTC" -eq 1 ]; then
            "$SCRIPTDIR/bin/rtcwake" -d "rtc$RTC" -s "$INTERVAL_ON_ERROR" -m mem
        else
            sleep "$INTERVAL_ON_ERROR"
        fi
    else
        GLOBAL_ERROR_COUNT=0
        TODAY="$(date +%s)"
        WAKEUPTIME=$((TODAY + INTERVAL_ON_ERROR - DELAY_BEFORE_SUSPEND))
        logger "SUCCESS, will update again on $WAKEUPTIME"

        logger "sleeping for $INTERVAL sec"
        if [ "$USE_RTC" -eq 1 ]; then
            "$SCRIPTDIR/bin/rtcwake" -d "rtc$RTC" -s "$INTERVAL" -m mem
        else    
            sleep "$INTERVAL"
        fi
    fi

done

logger "error: unexpected loop exit!"