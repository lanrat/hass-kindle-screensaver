# Notes

## Update

```sh
./connect.sh $KINDLE_IP update
```

In order to use `connect.sh` ensure that `USE_WIFI` and`USE_WIFI_SSHD_ONLY` are set to true in `/mnt/us/usbnet/etc/config`.


## fix for timezone

https://wiki.mobileread.com/wiki/Kindle_Touch_Hacking#Setting_the_time_zone


## enable ping

Add the following to `/mnt/us/usbnet/etc/config`

```
iptables -A INPUT -i wlan0 -p icmp -j ACCEPT
```


## passwords

* https://www.sven.de/kindle/
* https://www.hardanswers.net/amazon-kindle-root-password


## loggin in with keys

```sh
./connect.sh $KINDLE_IP copy-ssh-key
```

Or create `/mnt/us/usbnet/etc/authorized_keys` with keys.


## Other binaries for Kindles

arm bins on kindles
* https://www.mobileread.com/forums/showthread.php?t=240616

defunct
* https://wiki.mobileread.com/wiki/Optware
* https://www.mobileread.com/forums/showthread.php?t=118472
