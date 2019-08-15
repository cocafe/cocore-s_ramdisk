#!/sbin/busybox sh

BB=/sbin/busybox

TS_DIR=/data/cocore/tombstones
TS_FILE="last-kmsg_`date '+%Y-%m-%d-%H-%M-%S'`.log.xz"

LAST_KMSG=/proc/last_kmsg

# flag for "need to store last_kmsg" provided by sammy reset reason
NEED_STORE=/proc/store_lastkmsg

if [ ! -f ${LAST_KMSG} ]; then
  echo "tombstone: /proc/last_kmsg is not existed"
  exit
fi

LAST_CRASH=`cat ${NEED_STORE}`
if [ ${LAST_CRASH} -eq 0 ]; then
  echo "tombstone: reset reason looks fine"
fi

echo "tombstone: reset reason indicated a crash"

# make sure directory exists
if [ ! -e ${TS_DIR} ]; then
  ${BB} mkdir -p ${TS_DIR}
fi

# dump and compress last_kmsg
${BB} cat ${LAST_KMSG} | ${BB} xz -c > ${TS_DIR}/${TS_FILE}

