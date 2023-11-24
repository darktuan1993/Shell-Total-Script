variable=$(pvdisplay /dev/sdb1 | awk '/VG Name/ {print $3}')
echo $variable
