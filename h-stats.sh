#!/usr/bin/env bash

source $MINER_DIR/$CUSTOM_MINER/h-manifest.conf


stats_raw=`echo '{"command":"summary+devs"}' | nc -w $API_TIMEOUT localhost ${CUSTOM_API_PORT}`
if [[ $? -ne 0 || -z $stats_raw ]]; then
  echo -e "${YELLOW}Failed to read $miner from localhost:${CUSTOM_API_PORT}${NOCOLOR}"
else
  [[ -z $CUSTOM_ALGO ]] && CUSTOM_ALGO="lyra2z"

  khs=`echo $stats_raw | jq '."summary"."SUMMARY"[0]."KHS 30s"'`

  local t_temp=$(jq '.temp' <<< $gpu_stats)
  local t_fan=$(jq '.fan' <<< $gpu_stats)

  # [[ $cpu_indexes_array != '[]' ]] && #remove Internal Gpus
  # <>t_temp=$(jq -c "del(.$cpu_indexes_array)" <<< $t_temp) &&
  # <>t_fan=$(jq -c "del(.$cpu_indexes_array)" <<< $t_fan)

  local bus_ids=""
  local a_fans=""
  local a_temp=""

  #[[ `echo $stats_raw | jq -r .summary.SUMMARY[0].Elapsed` -lt 60 ]] && head -n 50 ${MINER_LOG_BASENAME}.log > ${MINER_LOG_BASENAME}_head.log
  [[ `wc -l ${CUSTOM_LOG_BASENAME}_head.log | awk '{print $1}'` -lt 150 ]] && head -n 150 ${CUSTOM_LOG_BASENAME}.log > ${CUSTOM_LOG_BASENAME}_head.log

  local ver=`echo $stats_raw | jq -r .summary.STATUS[0].Description | awk '{ printf $2 }'`

  dpkg --compare-versions "$ver" "lt" "0.3.8"
  if [ $? -eq "0" ]; then
    local bus_no=$(jq .devs.DEVS[]."GPU" <<< "$stats_raw")
    local all_bus_ids_array=(`echo "$gpu_detect_json" | jq -r '[ . | to_entries[] | select(.value) | .value.busid [0:2] ] | .[]'`)
    for ((i = 0; i < `echo $bus_no | awk "{ print NF }"`; i++)); do
      bus_id=`cat ${MINER_LOG_BASENAME}_head.log | grep "Successfully initialized GPU $i" | tail -1 | awk '{ printf $12"\n" }' | cut -d ':' -f 1`
      [[ $i -gt 9 ]] && bus_id=`cat ${MINER_LOG_BASENAME}_head.log | grep "Successfully initialized GPU$i" | tail -1 | awk '{ printf $11"\n" }' | cut -d ':' -f 1`
      bus_id=$(( 0x${bus_id} ))
      bus_ids+=${bus_id}" "
      for ((j = 0; j < ${#all_bus_ids_array[@]}; j++)); do
        if [[ "$(( 0x${all_bus_ids_array[$j]} ))" -eq "$bus_id" ]]; then
          a_fans+=$(jq .[$j] <<< $t_fan)" "
          a_temp+=$(jq .[$j] <<< $t_temp)" "
        fi
      done
    done
  else
    local bus_no=$(jq .devs.DEVS[]."GPU" <<< "$stats_raw")
    for ((i = 0; i < `echo $bus_no | awk "{ print NF }"`; i++)); do
      bus_id=`cat ${CUSTOM_LOG_BASENAME}_head.log | grep "Successfully initialized GPU $i" | tail -1 | awk '{ printf $12"\n" }' | cut -d ':' -f 1`
      [[ $i -gt 9 ]] && bus_id=`cat ${CUSTOM_LOG_BASENAME}_head.log | grep "Successfully initialized GPU$i" | tail -1 | awk '{ printf $11"\n" }' | cut -d ':' -f 1`
      bus_id=$(( 0x${bus_id} ))
      bus_ids+=${bus_id}" "
    done
    a_temp=$(jq '.devs.DEVS[].Temperature' <<< "$stats_raw")
    a_fans=$(jq '.devs.DEVS[]."Fan Percent"' <<< "$stats_raw")
  fi

  local ac=$(jq '."summary"."SUMMARY"[0]."Accepted"' <<< "$stats_raw")
  local rj=$(jq '."summary"."SUMMARY"[0]."Rejected"' <<< "$stats_raw")
  local iv=$(jq '."summary"."SUMMARY"[0]."Hardware Errors"' <<< "$stats_raw")
  local iv_bus=`echo $stats_raw | jq '.devs.DEVS[]."Hardware Errors"' | jq -cs '.' | sed  's/,/;/g' | tr -d [ | tr -d ]`



  stats=$(jq \
    --argjson fan "`echo ${a_fans[@]} | tr " " "\n" | jq -cs '.'`" \
    --argjson temp "`echo ${a_temp[@]} | tr " " "\n" | jq -cs '.'`" \
    --argjson bus_numbers "`echo ${bus_ids[@]} | tr " " "\n" | jq -cs '.'`" \
    --arg ac "$ac" --arg rj "$rj" --arg iv "$iv" --arg iv_bus "$iv_bus" --arg algo "$CUSTOM_ALGO" \
    --arg ver "$ver" \
    '{hs: [.devs.DEVS[]."KHS 30s"], $algo, $temp, $fan,
      uptime: .summary.SUMMARY[0].Elapsed, ar: [$ac, $rj, $iv, $iv_bus], $bus_numbers,
      $ver}' <<< "$stats_raw")
fi

#dual stats
stats_raw2=`echo '{"command":"summary2+devs2+pools2"}' | nc -w $API_TIMEOUT localhost ${CUSTOM_API_PORT}`
if [[ $? -eq 0 && -n $stats_raw2 && $(jq -r '."summary2"."STATUS"[0]."Msg"' <<< "$stats_raw2") == "Summary" ]]; then
  local ac2=$(jq '."summary2"."SUMMARY"[0]."Accepted"' <<< "$stats_raw2")
  local rj2=$(jq '."summary2"."SUMMARY"[0]."Rejected"' <<< "$stats_raw2")
  local iv2=$(jq '."summary2"."SUMMARY"[0]."Hardware Errors"' <<< "$stats_raw2")
  local iv_bus2=`echo $stats_raw2 | jq '.devs2.DEVS[]."Hardware Errors"' | jq -cs '.' | sed  's/,/;/g' | tr -d [ | tr -d ]`

  local algo2=$(jq -r '."pools2"."POOLS"[0]."Algorithm"' <<< "$stats_raw2")
  [[ -z $algo2 ]] && algo2="ton"

  local total_khs2=$(jq '."summary2"."SUMMARY"[0]."KHS 30s"' <<< "$stats_raw2")

  local stats2=$(jq \
    --arg ac2 "$ac2" --arg rj2 "$rj2" --arg iv2 "$iv2" --arg iv_bus2 "$iv_bus2" --arg algo2 "$algo2" \
    --arg total_khs2 "$total_khs2" \
    '{$total_khs2, hs2: [.devs2.DEVS[]."KHS 30s"], $algo2,
      ar2: [$ac2, $rj2, $iv2, $iv_bus2]}' <<< "$stats_raw2")

  stats=$(jq -s '.[0] * .[1]' <<< "$stats $stats2")
fi

[[ -z $khs ]] && khs=0
[[ -z $stats ]] && stats="null"
