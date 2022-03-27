# Notes

## Update

```sh
./connect.sh $KINDLE_IP update
```

## fix for timezone
https://wiki.mobileread.com/wiki/Kindle_Touch_Hacking#Setting_the_time_zone


## enable ping

https://www.mobileread.com/forums/showthread.php?t=135707

```
iptables -A INPUT -i wlan0 -p icmp -j ACCEPT
```


## passwords

* https://www.sven.de/kindle/?#
* https://www.hardanswers.net/amazon-kindle-root-password


## loggin in with keys

create `/mnt/us/usbnet/etc/authorized_keys` with keys
