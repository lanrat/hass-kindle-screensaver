#!/bin/sh

# shellcheck disable=SC2034  # Unused variables allowed for include

## Defaults

KINDLE_NAME="Kindle"
INTERVAL=$((10*60))                       # (sec) - how often to update the script
IMAGE_URI="http://192.168.2.4:5000/2.png" # URL of image to fetch. Keep in mind that the Kindle 4 does not support SSL/TLS requests
CLEAR_SCREEN_BEFORE_RENDER=0              # If "1", then the screen is completely cleared before rendering the newly fetched image to avoid "shadows".
INTERVAL_ON_ERROR=30                      # In case of errors, the device waits this long until the next loop.
BATTERYALERT=15                           # if the battery level is equal to or below this threshold, a info will be displayed
BATTERYLOW=5                              # if the battery level is equal to or below this threshold, the "please charge" image will be shown and the device will sleep for a long time until it checks again (or boots up and starts the script again)
BATTERYSLEEP=3600                         # 1 hr sleep time when Battery Level is equal or below the "BATTERYLOW" threshold, see above.
ROUTERIP="192.168.2.1"                    # router gateway IP. The Kindle appears to sometimes forget the gateway's IP and we need to set this manually.
PINGHOST="$ROUTERIP"                      # which domain (or IP) to ping to check internet connectivity.
LOGGING=1                                 # if enabled, the script logs into a file
DELAY_BEFORE_SUSPEND=5                    # seconds to wait between drawing image and suspending. This gives you time to SSH into your device if it's inside the photo frame and stop the daemon
RESTART_POWERD_THRESHOLD=20               # restart powerd if battery percentage is below this value, if a power source is connected and the charging current is negative
DISPLAY_REFRESH_TIME=true                 # display time of last image refresh in lower left corner
DISPLAY_BATTERY_LEVEL=true                # display battery percentage on lower right corner
REFRESH_EVERY=5 # how often to completely refresh the screen (per screen refresh)

NAME=homeassistant
SCRIPTDIR="/mnt/us/extensions/homeassistant"
LOGFILE="$SCRIPTDIR/$NAME.log"

NET="wlan0"

LIMGBATT="$SCRIPTDIR/images/low_battery.png"
LIMGERR="$SCRIPTDIR/images/error.png"
LIMGERRWIFI="$SCRIPTDIR/images/no_wifi.png"

TMPFILE="$SCRIPTDIR/cover.temp.png"
SCREENSAVERFILE="$SCRIPTDIR/cover.png"

USE_RTC=1 # if 0, only sleep will be used (which is useful for debugging)
RTC=1     # use rtc1 by default

# timezone for date comment
#TZ="GMT+7" # for summer time
TZ="GMT+8" # for winter time

MAC_SUFFIX="$(cat /sys/class/net/$NET/address | cut -d: -f4-6)"

## Device Specific Overrides
case "$MAC_SUFFIX" in
   "af:95:92")
      KINDLE_NAME="Kindle4"
      IMAGE_URI="http://192.168.2.4:5000/2.png"
      ;;
   "52:f2:b3")
      KINDLE_NAME="KindleTouch"
      IMAGE_URI="http://192.168.2.4:5000/3.png"
      ;;
   *)
     KINDLE_NAME="Kindle_$MAC_SUFFIX"
     ;;
esac
