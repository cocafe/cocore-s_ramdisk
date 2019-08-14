#!/sbin/busybox sh

# utility shortcuts
BB=/sbin/busybox
TC=/sbin/tc_unoffical

LOG=/tmp/post-boot.log
CONFIG=/data/cocore

exec >> ${LOG} 2>&1

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

if [ ! -d ${CONFIG} ]; then
  mkdir -p ${CONFIG}
fi

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
# Tombstones
#

/sbin/init.cocore.tombstones.sh

#
# Settings
#

# Exynos hotplug settings
# TODO: remove this crap in the future
echo 1 > /sys/power/cpuhotplug/min_online_cpu
echo 8 > /sys/power/cpuhotplug/max_online_cpu
echo 0 > /sys/power/cpuhotplug/enabled

# RCU threads: Set affinity to offload RCU workload
# !! This will impact cache and memory locality
# RCU_CPUMASK=01
# for i in `seq 0 7`; do
#   taskset -p ${RCU_CPUMASK} `pgrep "rcuop\/$i"`
#   taskset -p ${RCU_CPUMASK} `pgrep "rcuob\/$i"`
#   taskset -p ${RCU_CPUMASK} `pgrep "rcuos\/$i"`
# done

# CPUQuiet settings
# echo 4 > /sys/devices/system/cpu/cpuquiet/nr_min_cpus
# echo rqbalance > /sys/devices/system/cpu/cpuquiet/current_governor

# Touch Boost: cpu_boost
echo 0:1053000 > /sys/module/cpu_boost/parameters/input_boost_freq
echo 4:1066000 > /sys/module/cpu_boost/parameters/input_boost_freq
echo 200       > /sys/module/cpu_boost/parameters/input_boost_ms

# CPUFREQ Settings

CPUFREQ_LIT_MIN=0
CPUFREQ_LIT_MAX=0

CPUFREQ_BIG_MIN=0
CPUFREQ_BIT_MAX=0

CPUFREQ_GOV_LIT=ondemand
CPUFREQ_GOV_BIG=ondemand

CPUFREQ_POLICY_LIT=/sys/devices/system/cpu/cpufreq/policy0
CPUFREQ_POLICY_BIG=/sys/devices/system/cpu/cpufreq/policy4

if [ -f ${CONFIG}/cpufreq_lit_min ]; then
  CPUFREQ_LIT_MIN=`cat ${CONFIG}/cpufreq_lit_min`
fi

if [ -f ${CONFIG}/cpufreq_lit_max ]; then
  CPUFREQ_LIT_MAX=`cat ${CONFIG}/cpufreq_lit_max`
fi

if [ -f ${CONFIG}/cpufreq_big_min ]; then
  CPUFREQ_BIG_MIN=`cat ${CONFIG}/cpufreq_big_min`
fi

if [ -f ${CONFIG}/cpufreq_big_max ]; then
  CPUFREQ_BIG_MAX=`cat ${CONFIG}/cpufreq_big_max`
fi

if [ -f ${CONFIG}/cpufreq_gov_lit ]; then
  CPUFREQ_GOV_LIT=`cat ${CONFIG}/cpufreq_gov_lit`
fi

if [ -f ${CONFIG}/cpufreq_gov_big ]; then
  CPUFREQ_GOV_BIG=`cat ${CONFIG}/cpufreq_gov_big`
fi

echo "cpufreq: little: min: ${CPUFREQ_LIT_MIN} max: ${CPUFREQ_LIT_MAX} gov: ${CPUFREQ_GOV_LIT}"
echo "cpufreq: big:    min: ${CPUFREQ_BIG_MIN} max: ${CPUFREQ_BIG_MAX} gov: ${CPUFREQ_GOV_BIG}"

if [ ${CPUFREQ_LIT_MIN} -ne 0 ]; then
  echo ${CPUFREQ_LIT_MIN} > ${CPUFREQ_POLICY_LIT}/scaling_min_freq
fi

if [ ${CPUFREQ_LIT_MAX} -ne 0 ]; then
  echo ${CPUFREQ_LIT_MAX} > ${CPUFREQ_POLICY_LIT}/scaling_max_freq
fi

if [ ${CPUFREQ_BIG_MIN} -ne 0 ]; then
  echo ${CPUFREQ_BIG_MIN} > ${CPUFREQ_POLICY_BIG}/scaling_min_freq
fi

if [ ${CPUFREQ_BIG_MAX} -ne 0 ]; then
  echo ${CPUFREQ_BIG_MAX} > ${CPUFREQ_POLICY_BIG}/scaling_max_freq
fi

if [ ! -z ${CPUFREQ_GOV_LIT} ]; then
  echo ${CPUFREQ_GOV_LIT} > ${CPUFREQ_POLICY_LIT}/scaling_governor
fi

if [ ! -z ${CPUFREQ_GOV_BIG} ]; then
  echo ${CPUFREQ_GOV_BIG} > ${CPUFREQ_POLICY_BIG}/scaling_governor
fi

# selinux
if [ ! -f ${CONFIG}/selinux_enforcing ]; then
  echo "selinux permissive"

  echo 0 > /sys/fs/selinux/enforce
  chmod 640 /sys/fs/selinux/enforce
else
  echo "selinux enforcing"

  echo 1 > /sys/fs/selinux/enforce
  chmod 644 /sys/fs/selinux/enforce
fi

# zram
ZRAM_DEV=zram0
ZRAM_COMP=lz4
ZRAM_SIZE=$((2048 * 1024 * 1024))

if [ -f ${CONFIG}/zram_comp ]; then
  ZRAM_COMP=`cat ${CONFIG}/zram_comp`
fi

if [ -f ${CONFIG}/zram_size ]; then
  ZRAM_SIZE=`cat ${CONFIG}/zram_size`
fi

if [ -f ${CONFIG}/zram_enabled ]; then
  echo "zram enabled, size: ${ZRAM_SIZE} bytes, compressor: ${ZRAM_COMP}"

  echo ${ZRAM_COMP} > /sys/block/${ZRAM_DEV}/comp_algorithm
  echo ${ZRAM_SIZE} > /sys/block/${ZRAM_DEV}/disksize

  ${BB} mkswap /dev/block/${ZRAM_DEV}
  ${BB} swapon /dev/block/${ZRAM_DEV}
fi

# zswap
ZSWAP_DEV=vnswap0
ZSWAP_COMP=lz4
ZSWAP_SIZE=$((2048 * 1024 * 1024))

if [ -f ${CONFIG}/zswap_comp ]; then
  ZSWAP_COMP=`cat ${CONFIG}/zswap_comp`
fi

if [ -f ${CONFIG}/zswap_size ]; then
  ZSWAP_SIZE=`cat ${CONFIG}/zswap_size`
fi

if [ -f ${CONFIG}/zswap_enabled ]; then
  echo "zswap enabled, size ${ZSWAP_SIZE} bytes, compressor ${ZSWAP_COMP}"

  # zswap config
  echo ${ZSWAP_COMP} > /sys/module/zswap/parameters/compressor
  echo 1 > /sys/module/zswap/parameters/enabled

  # vnswap block device config
  echo ${ZSWAP_SIZE} > /sys/block/${ZSWAP_DEV}/disksize

  ${BB} mkswap /dev/block/${ZSWAP_DEV}
  ${BB} swapon /dev/block/${ZSWAP_DEV}
fi

# Block Queue Scheduler
BLK_SCHED=sio

if [ -f ${CONFIG}/blk_sched ]; then
  BLK_SCHED=`cat ${CONFIG}/blk_sched`
fi

echo "block scheduler: ${BLK_SCHED}"

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

# Network Stack
if [ -f ${CONFIG}/tcp_cong ]; then
  TCP_CONG=`cat ${CONFIG}/tcp_cong`
fi

if [ ! -z ${TCP_CONG} ]; then
  echo ${TCP_CONG} > /proc/sys/net/ipv4/tcp_congestion_control

  if [ ${TCP_CONG} = "bbr" ]; then
    ${TC} qdisc replace dev rmnet0 root fq
    ${TC} qdisc replace dev wlan0 root fq
  fi
fi

echo 3 > /proc/sys/net/ipv4/tcp_fastopen
echo 30 > /proc/sys/net/ipv4/tcp_fin_timeout

# Virtual Memory
echo 1 > /proc/sys/vm/vfs_cache_pressure
echo 90 > /proc/sys/vm/dirty_ratio

#
# init.d
#

/sbin/init.cocore.init-d.sh

