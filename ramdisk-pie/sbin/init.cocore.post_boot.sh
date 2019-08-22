#!/sbin/bash

# utility shortcuts
BB=/sbin/busybox
TC=/sbin/tc_linux

LOG=/tmp/post-boot.log
CONFIG=/data/cocore

#
# Helpers
#

# @1: arguments to file, if need, wrap with quotas
# @2: file
write()
{
  local args=$1
  local file=$2

  echo "write: ${file}: ${args}"
  echo ${args} > ${file}
}

#
# Misc
#

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

# Symlink install /sbin/busybox for su shell
#/sbin/busybox --install -s /sbin

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
# Configs
#

# Config directory
if [ ! -d ${CONFIG} ]; then
  mkdir -p ${CONFIG}
fi

# Config variables
CPUFREQ_LIT_MIN=0
CPUFREQ_LIT_MAX=0
CPUFREQ_BIG_MIN=0
CPUFREQ_BIT_MAX=0
CPUFREQ_GOV_LIT=ondemand
CPUFREQ_GOV_BIG=ondemand

CPUBOOST_ENABLED=1
CPUBOOST_FREQ_LIT=1053000
CPUBOOST_FREQ_BIG=1066000
CPUBOOST_MS=200

SELNX_ENFORCE=0

ZRAM_DEV=zram0
ZRAM_COMP=lz4
ZRAM_SIZE=$((2048 * 1024 * 1024))
ZRAM_ENABLED=0

ZSWAP_DEV=vnswap0
ZSWAP_COMP=lz4
ZSWAP_SIZE=$((2048 * 1024 * 1024))
ZSWAP_ENABLED=0

BLK_SCHED=sio

#TCP_CONG=cubic
#NET_SCHED=pfifo_fast

NET_TUNE=1
VM_TUNE=1
SCHED_TUNE=1

# CPUFreq

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

# CPUBoost

if [ -f ${CONFIG}/cpuboost_enabled ]; then
  CPUBOOST_ENABLED=`cat ${CONFIG}/cpuboost_enabled`
fi

if [ -f ${CONFIG}/cpuboost_freq_lit ]; then
  CPUBOOST_FREQ_LIT=`cat ${CONFIG}/cpuboost_freq_lit`
fi

if [ -f ${CONFIG}/cpuboost_freq_big ]; then
  CPUBOOST_FREQ_BIG=`cat ${CONFIG}/cpuboost_freq_big`
fi

if [ -f ${CONFIG}/cpuboost_ms ]; then
  CPUBOOST_MS=`cat ${CONFIG}/cpuboost_ms`
fi

# selinux

if [ -f ${CONFIG}/selinux_enforcing ]; then
  SELNX_ENFORCE=`cat ${CONFIG}/selinux_enforcing`
fi

# zram

if [ -f ${CONFIG}/zram_comp ]; then
  ZRAM_COMP=`cat ${CONFIG}/zram_comp`
fi

if [ -f ${CONFIG}/zram_size ]; then
  ZRAM_SIZE=`cat ${CONFIG}/zram_size`
fi

if [ -f ${CONFIG}/zram_enabled ]; then
  ZRAM_ENABLED=1
fi

# zswap

if [ -f ${CONFIG}/zswap_comp ]; then
  ZSWAP_COMP=`cat ${CONFIG}/zswap_comp`
fi

if [ -f ${CONFIG}/zswap_size ]; then
  ZSWAP_SIZE=`cat ${CONFIG}/zswap_size`
fi

if [ -f ${CONFIG}/zswap_enabled ]; then
  ZSWAP_ENABLED=1
fi

# blk sched

if [ -f ${CONFIG}/blk_sched ]; then
  BLK_SCHED=`cat ${CONFIG}/blk_sched`
fi

# tcp

if [ -f ${CONFIG}/tcp_cong ]; then
  TCP_CONG=`cat ${CONFIG}/tcp_cong`
fi

# net sched
if [ -f ${CONFIG}/net_sched ]; then
  NET_SCHED=`cat ${CONFIG}/net_sched`
fi

# tune switches

if [ -f ${CONFIG}/net_tune ]; then
  NET_TUNE=`cat ${CONFIG}/net_tune`
fi

if [ -f ${CONFIG}/vm_tune ]; then
  VM_TUNE=`cat ${CONFIG}/vm_tune`
fi

if [ -f ${CONFIG}/sched_tune ]; then
  SCHED_TUNE=`cat ${CONFIG}/sched_tune`
fi

#
# Settings
#

# Exynos hotplug settings
# TODO: remove this crap in the future
write 1 /sys/power/cpuhotplug/min_online_cpu
write 8 /sys/power/cpuhotplug/max_online_cpu
write 0 /sys/power/cpuhotplug/enabled

# RCU threads: Set affinity to offload RCU workload
# !! This will impact cache and memory locality
# RCU_CPUMASK=01
# for i in `seq 0 7`; do
#   taskset -p ${RCU_CPUMASK} `pgrep "rcuop\/$i"`
#   taskset -p ${RCU_CPUMASK} `pgrep "rcuob\/$i"`
#   taskset -p ${RCU_CPUMASK} `pgrep "rcuos\/$i"`
# done

# CPUQuiet settings
# write 4 /sys/devices/system/cpu/cpuquiet/nr_min_cpus
# write rqbalance /sys/devices/system/cpu/cpuquiet/current_governor

# Touch Boost: cpu_boost
if [ ${CPUBOOST_ENABLED} -eq 1 ]; then
  write 0:${CPUBOOST_FREQ_LIT} /sys/module/cpu_boost/parameters/input_boost_freq
  write 4:${CPUBOOST_FREQ_BIG} /sys/module/cpu_boost/parameters/input_boost_freq
  write ${CPUBOOST_MS} /sys/module/cpu_boost/parameters/input_boost_ms
fi

# CPUFREQ Settings
CPUFREQ_POLICY_LIT=/sys/devices/system/cpu/cpufreq/policy0
CPUFREQ_POLICY_BIG=/sys/devices/system/cpu/cpufreq/policy4

echo "cpufreq: little: min: ${CPUFREQ_LIT_MIN} max: ${CPUFREQ_LIT_MAX} gov: ${CPUFREQ_GOV_LIT}"
echo "cpufreq: big:    min: ${CPUFREQ_BIG_MIN} max: ${CPUFREQ_BIG_MAX} gov: ${CPUFREQ_GOV_BIG}"

if [ ${CPUFREQ_LIT_MIN} -ne 0 ]; then
  write ${CPUFREQ_LIT_MIN} ${CPUFREQ_POLICY_LIT}/scaling_min_freq
fi

if [ ${CPUFREQ_LIT_MAX} -ne 0 ]; then
  write ${CPUFREQ_LIT_MAX} ${CPUFREQ_POLICY_LIT}/scaling_max_freq
fi

if [ ${CPUFREQ_BIG_MIN} -ne 0 ]; then
  write ${CPUFREQ_BIG_MIN} ${CPUFREQ_POLICY_BIG}/scaling_min_freq
fi

if [ ${CPUFREQ_BIG_MAX} -ne 0 ]; then
  write ${CPUFREQ_BIG_MAX} ${CPUFREQ_POLICY_BIG}/scaling_max_freq
fi

if [ ! -z ${CPUFREQ_GOV_LIT} ]; then
  write ${CPUFREQ_GOV_LIT} ${CPUFREQ_POLICY_LIT}/scaling_governor
fi

if [ ! -z ${CPUFREQ_GOV_BIG} ]; then
  write ${CPUFREQ_GOV_BIG} ${CPUFREQ_POLICY_BIG}/scaling_governor
fi

# selinux
if [ ${SELNX_ENFORCE} -eq 0 ]; then
  echo "selinux permissive"

  write 0 /sys/fs/selinux/enforce
  chmod 640 /sys/fs/selinux/enforce
else
  echo "selinux enforcing"

  write 1 /sys/fs/selinux/enforce
  chmod 644 /sys/fs/selinux/enforce
fi

# zram
if [ ${ZRAM_ENABLED} -eq 1 ]; then
  echo "zram enabled, size: ${ZRAM_SIZE} bytes, compressor: ${ZRAM_COMP}"

  write ${ZRAM_COMP} /sys/block/${ZRAM_DEV}/comp_algorithm
  write ${ZRAM_SIZE} /sys/block/${ZRAM_DEV}/disksize

  ${BB} mkswap /dev/block/${ZRAM_DEV}
  ${BB} swapon /dev/block/${ZRAM_DEV}
fi

# zswap
if [ ${ZSWAP_ENABLED} -eq 1 ]; then
  echo "zswap enabled, size ${ZSWAP_SIZE} bytes, compressor ${ZSWAP_COMP}"

  # zswap config
  write ${ZSWAP_COMP} /sys/module/zswap/parameters/compressor
  write 1 /sys/module/zswap/parameters/enabled

  # vnswap block device config
  write ${ZSWAP_SIZE} /sys/block/${ZSWAP_DEV}/disksize

  ${BB} mkswap /dev/block/${ZSWAP_DEV}
  ${BB} swapon /dev/block/${ZSWAP_DEV}
fi

# Block Queue Scheduler
if [ ! -z ${BLK_SCHED} ]; then
  echo "block scheduler: ${BLK_SCHED}"

  for i in /sys/block/{sd?,mmcblk?}/queue/scheduler; do
    write ${BLK_SCHED} $i
  done

  # CFQ Settings
  if [ ${BLK_SCHED} = "cfq" ]; then
    for i in /sys/block/{sd?,mmcblk?}/queue/iosched; do
      # Let CFQ decide lowest latency by kernel HZ
      write 0 $i/target_latency
      write 0 $i/target_latency_us
    done
  fi
fi

# Network Stack
if [ ! -z ${TCP_CONG} ]; then
  echo "tcp congestion: ${TCP_CONG}"

  write ${TCP_CONG} /proc/sys/net/ipv4/tcp_congestion_control

  # config for tcp congestions that require special packet sched
  if [ ${TCP_CONG} = "bbr" ]; then
    NET_SCHED=fq
  fi
fi

if [ ! -z ${NET_SCHED} ]; then
  echo "net packet sched: ${NET_SCHED}"

  write ${NET_SCHED} /proc/sys/net/core/default_qdisc

  # rmnet0 has some other default settings: mq
  ${TC} qdisc replace dev rmnet0 root ${NET_SCHED}
  ${TC} qdisc replace dev wlan0 root ${NET_SCHED}
fi

if [ ${NET_TUNE} -eq 1 ]; then
  write 1 /proc/sys/net/ipv4/tcp_fastopen
  write 7 /proc/sys/net/ipv4/tcp_recovery
  write 30 /proc/sys/net/ipv4/tcp_fin_timeout
fi

# Virtual Memory
if [ ${VM_TUNE} -eq 1 ]; then
  write 1 /proc/sys/vm/vfs_cache_pressure
  write 90 /proc/sys/vm/dirty_ratio
fi

# Process Scheduler
# tunable                       modified  default
# sched_cfs_bandwidth_slice_us: 3000      5000
# sched_cfs_boost:              0         0
# sched_child_runs_first:       0         0
# sched_cstate_aware:           1         1
# sched_initial_task_util:      0         0
# sched_latency_ns:             3000000   10000000
# sched_migration_cost_ns:      250000    500000
# sched_min_granularity_ns:     300000    3000000
# sched_nr_migrate:             32        32
# sched_rr_timeslice_ms:        7         25
# sched_rt_period_us:           1000000   1000000
# sched_rt_runtime_us:          950000    950000
# sched_schedstats:             0         1
# sched_shares_window_ns:       10000000  10000000
# sched_sync_hint_enable:       1         1
# sched_time_avg_ms:            1000      1000
# sched_tunable_scaling:        1         0
# sched_wakeup_granularity_ns:  500000    2000000

if [ ${SCHED_TUNE} -eq 1 ]; then
  # write 3000000  /proc/sys/kernel/sched_latency_ns
  # write 250000   /proc/sys/kernel/sched_migration_cost_ns
  # write 300000   /proc/sys/kernel/sched_min_granularity_ns
  # write 500000   /proc/sys/kernel/sched_wakeup_granularity_ns
  # write 3000     /proc/sys/kernel/sched_cfs_bandwidth_slice_us
  write 0          /proc/sys/kernel/sched_schedstats
  # write 10000000 /proc/sys/kernel/sched_shares_window_ns
  # write 1        /proc/sys/kernel/sched_sync_hint_enable
  # write 1000     /proc/sys/kernel/sched_time_avg_ms
  write 1          /proc/sys/kernel/sched_tunable_scaling
fi

#
# init.d
#

/sbin/init.cocore.init-d.sh

