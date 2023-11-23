#!/bin/bash

USERID="-898458642"
TOKEN="6623410843:AAFXWQcnUEqQviOLo_YtxKqNoM5xw8Snoic"
TIMEOUT="10"

URL="https://api.telegram.org/bot$TOKEN/sendMessage"
DATE_EXEC="$(date "+%d-%m-%Y %H:%M")"
HOST_NAME=$(hostnamectl | grep "Static hostname" | awk -F ": " '{print $2}')

IP=$(echo $SSH_CLIENT | awk '{print $1}')
PORT=$(echo $SSH_CLIENT | awk '{print $3}')
HOSTNAME=$(hostname -f)
IPADDR=$(echo $SSH_CONNECTION | awk '{print $3}')

# TEXT=$(echo -e "SSH Login\nUser: ${USER} \nISOFH_host": "$HOST_NAME"_"$IPADDR \nFrom $IP \nDate $DATE_EXEC")

TEXT="SSH Login
User: ${USER}
ISOFH_host: ${HOST_NAME}_${IPADDR}
From $IP
Date $DATE_EXEC"

if [[ ${USER} != 'ucmea' ]]; then
    curl -s -X POST --max-time $TIMEOUT $URL -d "chat_id=$USERID" -d "text=<b>$TEXT</b>" -d "parse_mode=HTML" >/dev/null

fi
