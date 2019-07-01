#!/sbin/busybox sh

BB=/sbin/busybox
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

# Fix personalist.xml: @tgpkernel
if [ ! -f /data/system/users/0/personalist.xml ]; then
  touch /data/system/users/0/personalist.xml
  chmod 600 /data/system/users/0/personalist.xml
  chown system:system /data/system/users/0/personalist.xml
fi

#
# Settings
#

# selinux
if [ ! -f /data/selinux_enforcing ]; then
  echo 0 > /sys/fs/selinux/enforce
  chmod 640 /sys/fs/selinux/enforce
else
  echo 1 > /sys/fs/selinux/enforce
  chmod 644 /sys/fs/selinux/enforce
fi

# zram
ZRAM_DEV=zram0
ZRAM_SIZE=$((2048 * 1024 * 1024))
if [ ! -f /data/zram_disable ]; then
  echo ${ZRAM_SIZE} > /sys/block/${ZRAM_DEV}/disksize
  ${BB} mkswap /dev/block/${ZRAM_DEV}
  ${BB} swapon -a /dev/block/${ZRAM_DEV}
fi

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

#
# init.d
#

/sbin/init.cocore.init-d.sh
