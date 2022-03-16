#!/bin/bash

source /hive/miners/custom/teamredminer-c/h-manifest.conf

#save last messages about hanging cards
if [[ -e $CUSTOM_LOG_BASENAME.log ]]; then
   tail -n 50 $CUSTOM_LOG_BASENAME.log > ${CUSTOM_LOG_BASENAME}_reboot.log
    lastmsg=`tac ${CUSTOM_LOG_BASENAME}_reboot.log | grep -m1 -E "DEAD|shutdown timed out" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g"`

    [[ $lastmsg =~ (19|20)[0-9]{2}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}\][[:space:]](.*)([\(][0-9abcdef]{2}:) ]]

    lastmsg=${BASH_REMATCH[2]}

    [[ -z $lastmsg ]] && lastmsg='reboot'
fi

if [[ -e ${CUSTOM_LOG_BASENAME}_reboot.log ]]; then
  echo -e "=== Last 50 lines of ${CUSTOM_LOG_BASENAME}.log ===\n`tail -n 50 ${CUSTOM_LOG_BASENAME}_reboot.log`" | /hive/bin/message danger "${CUSTOM_NAME}: $lastmsg" payload
else
  /hive/bin/message danger "${CUSTOM_NAME}: reboot"
fi

#need nohup or the sreboot will stop miner and this process also in it
nohup bash -c 'sreboot' > /tmp/nohup.log 2>&1 &

exit 0
