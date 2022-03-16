#!/usr/bin/env bash

export GPU_MAX_ALLOC_PERCENT=100
export GPU_SINGLE_ALLOC_PERCENT=100
export GPU_MAX_HEAP_SIZE=100
export GPU_USE_SYNC_OBJECTS=1


cd `dirname $0`

source h-manifest.conf


[[ `ps aux | grep "./teamredminer-c" | grep -v grep | grep -v bash | wc -l` != 0 ]] &&
  echo -e "${RED}$CUSTOM_NAME miner is already running${NOCOLOR}" &&
  exit 1

[[ -f ${CUSTOM_LOG_BASENAME}_head.log ]] && rm "${CUSTOM_LOG_BASENAME}_head.log"


[[ -z $CUSTOM_LOG_BASENAME ]] && echo -e "${RED}No CUSTOM_LOG_BASENAME is set${NOCOLOR}" && exit 1
[[ -z $CUSTOM_CONFIG_FILENAME ]] && echo -e "${RED}No CUSTOM_CONFIG_FILENAME is set${NOCOLOR}" && exit 1
[[ ! -f $CUSTOM_CONFIG_FILENAME ]] && echo -e "${RED}Custom config ${YELLOW}$CUSTOM_CONFIG_FILENAME${RED} is not found${NOCOLOR}" && exit 1
CUSTOM_LOG_BASEDIR=`dirname "${CUSTOM_LOG_BASENAME}"`
[[ ! -d $CUSTOM_LOG_BASEDIR ]] && mkdir -p $CUSTOM_LOG_BASEDIR


WATCHDOG=""
[[ -e watchdog.sh ]] && WATCHDOG="--watchdog_script"
./teamredminer-c ${WATCHDOG} $(< $CUSTOM_NAME.conf) --api_listen=127.0.0.1:${CUSTOM_API_PORT}   2>&1 | tee --append ${CUSTOM_LOG_BASENAME}.log
