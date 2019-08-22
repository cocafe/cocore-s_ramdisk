#!/system/bin/sh

# Spamming log may waste huge memory
LOG=/tmp/init-d.log

exec >> ${LOG} 2>&1

INITD_DIR=$1

if [ -z $1 ]; then
  echo "init.d: usage: <init.d dir>"
  exit
fi

if ! [ -d ${INITD_DIR} ]; then
  mkdir ${INITD_DIR}
  chown root.root ${INITD_DIR}
  chmod 0755 ${INITD_DIR}
  chcon u:object_r:system_file:s0 ${INITD_DIR}
fi

echo "init.d: start"

execute_recursive()
{
  for i in $1/*; do
    if [ -d $i ]; then
      execute_recursive $i
    elif [ -e $i ]; then
      if [ -x $i ]; then
        echo "init.d: exec" $i
        ./$i
      else
        echo "init.d: no execution permission on $i, skipped"
      fi
    fi
  done
}

if [ -d ${INITD_DIR} ]; then
  execute_recursive ${INITD_DIR}
else
  echo "init.d: /system/etc/init.d is not a directory"
fi
