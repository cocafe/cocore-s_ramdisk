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
${BB} fstrim -v /data
${BB} fstrim -v /cache
${BB} fstrim -v /system

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
# if [ ! -f /data/zram_disable ]; then
#   echo ${ZRAM_SIZE} > /sys/block/${ZRAM_DEV}/disksize
#   ${BB} mkswap /dev/block/${ZRAM_DEV}
#   ${BB} swapon /dev/block/${ZRAM_DEV}
# fi

# zswap
ZSWAP_DEV=vnswap0
ZSWAP_COMP=lz4
ZSWAP_SIZE=$((2048 * 1024 * 1024))
if [ ! -f /data/zswap_disable ]; then
  # zswap config
  echo ${ZSWAP_COMP} > /sys/module/zswap/parameters/compressor
  echo 1 > /sys/module/zswap/parameters/enabled

  # vnswap block device config
  echo ${ZSWAP_SIZE} > /sys/block/${ZSWAP_DEV}/disksize
  ${BB} mkswap /dev/block/${ZSWAP_DEV}
  ${BB} swapon /dev/block/${ZSWAP_DEV}
fi

# Block Queue Scheduler
BLK_SCHED=cfq

for i in /sys/block/sd?/queue/scheduler; do
  echo ${BLK_SCHED} > $i
done

for i in /sys/block/mmcblk?/queue/scheduler; do
  echo ${BLK_SCHED} > $i
done

# CFQ Settings
if [ ${BLK_SCHED} = "cfq" ]; then
  for i in /sys/block/sd?/queue/iosched; do
    # Let CFQ decide lowest latency by kernel HZ
    echo 0 > $i/target_latency
    echo 0 > $i/target_latency_us
  done

  for i in /sys/block/mmcblk?/queue/iosched; do
    # Let CFQ decide lowest latency by kernel HZ
    echo 0 > $i/target_latency
    echo 0 > $i/target_latency_us
  done
fi

# Symlink install /sbin/busybox for su shell
#/sbin/busybox --install -s /sbin

# TCP fastopen
echo 3 > /proc/sys/net/ipv4/tcp_fastopen
echo 30 > /proc/sys/net/ipv4/tcp_fin_timeout

#
# init.d
#

/sbin/init.cocore.init-d.sh
