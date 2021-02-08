#!/bin/bash

OPD=1

failed()
{
  sleep 2 # Wait for the kernel to stop whining
  echo "Hrm, that didn't work.  Calling for help."
#  sudo ipmitool chassis identify force
  echo "RAID Config failed: ${1}"
  while [ 1 ]; do sleep 10; done
  exit 1;
}

# First, look for the system disk so we avoid touching it.
SYSPART=`df | grep "/$" | cut -d" " -f1 | cut -d"/" -f3`
#SYSPART=`sudo pvs | grep "/dev/" | cut -f3 -d" " | sed -e 's/[0-9]*$//g'`
echo "System on $SYSPART"

# Remove the partition label symlinks
sudo rm /dev/disk/by-partlabel/osd-device*

echo "Making label on OSD devices"
j=0;
for DEV in nvme0n1 nvme1n1 nvme2n1 #for DEV in `ls -al /dev/nvme*n1 | cut -f3 -d"/" | tr '\n' ' '`
do
  sudo parted -s -a optimal /dev/$DEV mklabel gpt || failed "mklabel $DEV"
  for ((k=0; k < $OPD; k++ ))
  do
    if [[ ! $SYSPART =~ $DEV ]]
      then
        echo "Creating osd device $j journal label"
        
        sudo parted -s -a optimal /dev/$DEV mkpart osd-device-$j-data $(( 791 * $k ))G $(( 791 * $(($k)) + 1 ))G || failed "mkpart $j-data"
        sudo parted -s -a optimal /dev/$DEV mkpart osd-device-$j-wal $(( 791 * $(($k)) + 1))G $(( 791 * $(($k)) + 10 ))G || failed "mkpart $j-wal"
        sudo parted -s -a optimal /dev/$DEV mkpart osd-device-$j-db $(( 791 * $(($k)) + 10 ))G $(( 791 * $(($k)) + 40 ))G || failed "mkpart $j-db"
        sudo parted -s -a optimal /dev/$DEV mkpart osd-device-$j-block $(( 791 * $(($k)) + 40))G $(( 791 * $(($k)) + 791 ))G || failed "mkpart $j-block"

        let "j++"
    fi
  done
done

echo DONE
sleep 5
