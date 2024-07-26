#!/bin/bash

USERID="-4281048618"
TOKEN="7277813430:AAG-1nPYcwnkW0EBgzdtHQrdaynS9901clM"
TIMEOUT="10"

URL="https://api.telegram.org/bot$TOKEN/sendMessage"
DATE_EXEC="$(date "+%d-%m-%Y %H:%M")"
HOST_NAME=`hostnamectl | grep "Static hostname" | awk -F ": " '{print $2}'`

# IP=$(echo $SSH_CLIENT | awk '{print $1}')
# PORT=$(echo $SSH_CLIENT | awk '{print $3}')
HOSTNAME=$(hostname -f)
IPSERVER=$(hostname -I | awk '{print $1}')
# IPADDR=$(echo $SSH_CONNECTION | awk '{print $3}')

WHO=$(who -u | awk '{print $NF}')

TEXT=$(echo -e "==== CẢNH BÁO ĐĂNG NHẬP ====\n
Tài Khoản Login: ${USER} \n
Tên máy chủ: ${HOSTNAME} \n
IP  máy chủ: ${IPSERVER} \n
Kết nối từ IP: ${WHO} \n
Thời gian: $DATE_EXEC")


if [[ ${USER} != 'root' ]]; then
    curl -s -X POST --max-time $TIMEOUT $URL -d "chat_id=$USERID" -d text="$TEXT" > /dev/null
fi
