#!/bin/bash

export RUN_PATH=`dirname $0`

((

if [ "$EUID" -ne 0 ]; then
  echo "[!] Please run as root or use sudo!"
  exit 1
fi

echo "[*] Cleaning terraform state files..."

find $RUN_PATH -type f -name '*.tfstate*' -exec rm -f {} \;
STATUS=`echo $?`
if [ "$STATUS" != 0 ]; then
  echo "[!] ERROR: Cleaning terraform state files failed!"
  exit 1
fi

echo "[*] Cleaning terraform state finished!"

) 2>&1) | tee $RUN_PATH/log.out
