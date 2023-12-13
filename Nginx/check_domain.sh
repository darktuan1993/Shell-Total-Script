array=("hihi.local" "abc.local")

for is in ${array[@]}  ; do
    echo "=========================================================" >> check.txt
    echo $is >> check.txt
    curl -I  $is >> check.txt
done 