#!/usr/local/bin/bash

# zpool-spindown.sh
# spindown ada/da camcontrol disks for a zpool
# usage: zpool-spindown.sh poolname

ZPOOL="$1"

if [ -z "$ZPOOL" ] ; then
	echo "zpool name required"
	exit 2
fi

PATH=/usr/local/bin:/bin:/usr/bin:/usr/sbin:/usr/local/sbin:/bin:/sbin
export PATH

# Loop
while true ; do
# Cleanup any tmp file if present
if [ -f /tmp/zpool.iostat ] ; then
	rm -f /tmp/zpool.iostat
fi

# Get disks
gptid=`zpool status $ZPOOL | egrep "gptid" | awk '{print $1}' | tr '\n' ' '`
gptid=($gptid)
drives=()
drives_count=${#gptid[@]}
index=0
while [ "$index" -lt "$drives_count" ] ; do
	drives[$index]="$(glabel status | egrep "${gptid[$index]}" | awk '{print $3}' | cut -c 1-4)"
	let "index = $index + 1"
done


# Check if some disks spinning
# index=0
# while [ "$index" -lt "$drives_count" ] ; do
	# spundown=`smartctl -n standby -H /dev/${drives[$index]} | tail -1 | grep "STANDBY" | wc -l | awk '{print $NF}'`
	# if [ $spundown -eq 0 ] ; then
		# break
	# fi
	# let "index = $index + 1"
# done
# if [ "$index" -eq "$drives_count" ] ; then
	# echo "No disks spinning, wait for 10 minutes...."
	# sleep 10m
	# continue
# fi


# ZPool I/O activity check
zpool iostat $ZPOOL 300 2 | tail -1 > /tmp/zpool.iostat
reading=`cat /tmp/zpool.iostat | awk '{print $(NF-1)}' | awk -F\. '{print $1}' | sed -e 's/K//g' | sed -e 's/M//g'`
writing=`cat /tmp/zpool.iostat | awk '{print $NF}' | awk -F\. '{print $1}' | sed -e 's/K//g' | sed -e 's/M//g'`
rm -f /tmp/zpool.iostat
if [ $reading -gt 0 ] ; then
	echo "Pool shows IO activity..."
	continue
elif [ $writing -gt 0 ] ; then
	echo "Pool shows IO activity..."
	continue
fi

# Spin down
index=0
while [ "$index" -lt "$drives_count" ] ; do
	camcontrol standby ${drives[$index]}
	printf "Spindown Drive %s\n" ${drives[$index]}
	let "index = $index + 1"
done

done
