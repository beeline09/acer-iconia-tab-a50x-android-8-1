#!/system/bin/sh
# PICASSO: early static splash (see /system/etc/init/picasso-splash.rc).
BL=/sys/class/backlight/pwm-backlight
FB=/sys/class/graphics/fb0
echo "picasso-splash: before br=$(cat $BL/brightness) bl_power=$(cat $BL/bl_power) pan=$(cat $FB/pan) state=$(cat $FB/state)" > /dev/kmsg
cat /system/media/splash.raw > /dev/graphics/fb0
echo 0 > $FB/blank
echo 0,0 > $FB/pan
[ "$(cat $BL/brightness)" = "0" ] && echo 102 > $BL/brightness
echo 0 > $BL/bl_power
echo "picasso-splash: after br=$(cat $BL/brightness) bl_power=$(cat $BL/bl_power) pan=$(cat $FB/pan)" > /dev/kmsg
