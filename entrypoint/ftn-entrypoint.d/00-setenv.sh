#!/bin/sh

if [ -z "$OS_TIMEZONE" ] || [ ! -f "/usr/share/zoneinfo/$OS_TIMEZONE" ]; then
	OS_TIMEZONE=UTC
fi

echo "$OS_TIMEZONE" > /etc/timezone
ln -sf "/usr/share/zoneinfo/$OS_TIMEZONE" /etc/localtime

/usr/sbin/validlocale "$OS_LANG" > /dev/null 2>&1
if [ $? -ne 0 ]; then
	OS_LANG=C.UTF-8
fi

echo "LANG=$OS_LANG" > /etc/locale.conf
