#!/bin/sh

debug_echo() {
  if [ "$DEBUG" = "t" ]; then
    echo "$@"
  fi
}

if [ "${DB_PATH}" = "" ]; then
  debug_echo "DB_PATH environment variable is not set or empty. Exiting script."
  exit 1
fi

if [ "${DB_NAME}" = "" ]; then
  debug_echo "DB_NAME environment variable is not set or empty. Exiting script."
  exit 1
fi

if [ "${REPLICA_PATH}" = "" ]; then
  debug_echo "REPLICA_PATH environment variable is not set or empty. Exiting script."
  exit 1
fi

last_execution_time=$(date +%s) # 스크립트 시작 시간 기록

while true; do
  current_time=$(date +%s)
  time_diff=$((current_time - last_execution_time)) # 경과 시간 계산

  GENERATIONS_OUTPUT=$(litestream generations "${DB_PATH}/${DB_NAME}")
  result=$(echo "$GENERATIONS_OUTPUT" | awk 'NR>1 {if ($3 ~ /^-/) {found=1}} END {print found ? "true" : "false"}')

  if [ "$result" = "true" ] || [ "$time_diff" -ge "$EXECUTION_INTERVAL" ]; then
    if [ "$time_diff" -ge "$EXECUTION_INTERVAL" ]; then
      debug_echo "Execution interval reached. Starting process regardless of data state."
    else
      debug_echo "Negative lag detected. Restore Start."
    fi
    
    debug_echo "$GENERATIONS_OUTPUT"
    rm -Rf "${SOURCE_TEMP_PATH}"
    mkdir -p "${SOURCE_TEMP_PATH}" 
    litestream restore -o "${SOURCE_TEMP_PATH}/${DB_NAME}" "${REPLICA_PATH}"
    sqlite3 "${SOURCE_TEMP_PATH}/${DB_NAME}" 'PRAGMA wal_checkpoint(TRUNCATE);'
    
    ln -sfn "${SOURCE_TEMP_PATH}" "${DB_PATH}"

    cp -fRp "${SOURCE_TEMP_PATH}" "${SOURCE_PATH}"
    ln -sfn "${SOURCE_PATH}" "${DB_PATH}"

    rm -Rf "${SOURCE_TEMP_PATH}"
    debug_echo "Restore done."

    last_execution_time=$(date +%s) # 실행 후 시작 시간 리셋
  else
    debug_echo "All generations are up-to-date. No action is performed."
  fi
  sleep $CHECK_INTERVAL
done
