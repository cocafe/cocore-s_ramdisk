#!/system/bin/sh

LOG=/tmp/post-boot.log

exec >> ${LOG} 2>&1

echo init.cocore_post-boot: start

if [ -e ${LOG} ]; then
  # Mark init log global readable
  chmod 0644 ${LOG}
fi

# Trim filesystems
/sbin/busybox fstrim -v /data
/sbin/busybox fstrim -v /cache
/sbin/busybox fstrim -v /system

# Mount /system writable
mount -o rw,remount /system

#
# Fixes
#

# Fix props: @tgpkernel
RESETPROP="/sbin/resetprop resetprop -v -n"

# Set KNOX to 0x0 on running /system
${RESETPROP} ro.boot.warranty_bit "0"
${RESETPROP} ro.warranty_bit "0"

# Fix Samsung Related Flags
${RESETPROP} ro.fmp_config "1"
${RESETPROP} ro.boot.fmp_config "1"

# Fix safetynet flags
${RESETPROP} ro.boot.veritymode "enforcing"
${RESETPROP} ro.boot.verifiedbootstate "green"
${RESETPROP} ro.boot.flash.locked "1"
${RESETPROP} ro.boot.ddrinfo "00000001"

#
# Settings
#

# Block Queue Scheduler
BLK_SCHED=cfq

for i in /sys/block/sd?/queue/scheduler; do
  echo ${BLK_SCHED} > $i
done

# CFQ Settings
if [ ${BLK_SCHED} = "cfq" ]; then
  for i in /sys/block/sd?/queue/iosched/target_latency; do
    # Let CFQ decide lowest latency by kernel HZ
    echo 0 > $i
  done
fi

# Symlink install /sbin/busybox for su shell
#/sbin/busybox --install -s /sbin

# TCP fastopen
echo 3 > /proc/sys/net/ipv4/tcp_fastopen
