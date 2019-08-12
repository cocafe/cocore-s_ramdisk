#!/sbin/busybox sh

BB=/sbin/busybox

# busybox date timezone is wrong
TS_DIR=/data/cocore/tombstones
TS_FILE="last-kmsg_`/system/bin/date '+%Y-%m-%d-%H-%M-%S'`.log.xz"

LAST_KMSG=/proc/last_kmsg

# a cold boot should contain this in first few lines
COLD_BOOT="Samsung S-Boot"

# a normal reboot should contain this line
NORMAL_REBOOT="exynos_reboot: Exynos SoC reset right now"

if [ ! -f ${LAST_KMSG} ]; then
  echo "tombstone: /proc/last_kmsg is not existed"
  exit
fi

${BB} head -n 2 ${LAST_KMSG} | greq -q ${COLD_BOOD} > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "tombstone: cold boot, no last_kmsg"
  exit
fi

${BB} grep -q ${NORMAL_REBOOT} ${LAST_KMSG} > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "tombstone: no exception found"
  exit
fi

if [ ! -e ${TS_DIR} ]; then
  ${BB} mkdir -p ${TS_DIR}
fi

${BB} cat ${LAST_KMSG} | ${BB} xz -c > ${TS_DIR}/${TS_FILE}

