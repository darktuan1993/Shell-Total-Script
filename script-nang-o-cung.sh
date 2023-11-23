##### Variable List ######333
arrayMenu=("T?o phân vùng m?i" "Nâng dung l??ng ? c?ng" "Thoát")
mapfile -t vg_names < <(vgdisplay | awk '/VG Name/ {print $3}')
capacityNumber=""

# Danh sách menu
function list_menu() {
    for ((i = 0; i < ${#arrayMenu[@]}; i++)); do
        echo "                                 $((i + 1)). ${arrayMenu[$i]}                          "
    done
}
# L?y thông tin ? disk
function lay_thong_tin_disk() {
    clear
    echo " "
    echo "============================ Check thông tin ? ??a df -HT ==================================="
    df -hT
    echo " "
    echo "============================ Check thông tin ? ??a lsblk ============================"
    lsblk
}

# T?o phân vùng
function create_partition_disk() {
    nameDisk=$1
    capacityDisk=$2
    partitionNumber=$3

    echo "Tên disk: $nameDisk"
    echo "Kh?i l??ng: $capacityDisk"
    echo "Partition : $partitionNumber"

    if [ -n "$3" ]; then
        echo "ok"
        fdisk "/dev/$1" <<EOF
        n
        p
        $partitionNumber

        +${capacityDisk}G
        t

        8e
        w   
EOF
        echo "T?O PARTITION THÀNH CÔNG"
    else
        echo "ko ok l?m"
        fdisk "/dev/$1" <<EOF
        n
        p
        $partitionNumber

        +${capacityDisk}G
        t

        8e
        w   
EOF

        echo "T?O PARTITION THÀNH CÔNG"
    fi

}

# T?o volume group
function create_volume_group() {
    read -p "Nh?p tên volume-group mu?n t?o : " nameOfVolumeGroup
    # Check volume group
    # echo " Danh sách volume group:  ${vg_names[@]}  "
    for vg_name in "${vg_names[@]}"; do
        if [ "$vg_name" == "$nameOfVolumeGroup" ]; then
            found=true
            break
        fi
    done
    if [ "$found" == true ]; then
        echo "Tên $nameOfVolumeGroup ?ã ???c s? d?ng"
    else
        echo "Tên $nameOfVolumeGroup có th? s? d?ng"
        read -p "Nh?p tên phân vùng mu?n t?o (nh?p d?ng sdbx) : " partition_number
        vgcreate $nameOfVolumeGroup /dev/$partition_number
    fi
}

# ??ng ý t?o ? c?ng
function accept_create() {
    read -p "B?n có ??ng ý t?o ? c?ng không? (y/n): " choice
    case $choice in
    [yY])
        while true; do
            read -p "Nh?p s? phân vùng, ch? nh?p s? không c?n nh?p tên sdX, không nh?p gì là m?c ??nh theo th? t? (ví d?: $nameOFdisk 1, $nameOFdisk 2,..): " partitionNumber

              if ls /dev | grep -q $nameOFdisk$partitionNumber && [ -n "$partitionNumber" ]; then


                echo "?ã có ? c?ng này rùi"
            else

                # Check s?
                function is_number() {
                    [[ $1 =~ ^[0-9]+$ ]]
                }

                while true; do
                    read -p "Nh?p dung l??ng tính theo GB: " capacityNumber

                    if is_number "$capacityNumber"; then
                        break
                    else
                        echo "Vui lòng ch? nh?p s?."
                    fi
                done

                if [ -n "$partitionNumber" ]; then
                    # ??y config theo s? ???c nh?p
                    create_partition_disk $nameOFdisk $capacityNumber $partitionNumber
                    echo " "
                    echo "Danh Sách phân vùng lsblk m?i"
                    echo " "
                    lsblk
                    # create_volume_group
                else
                    # ??y m?c ??nh s? th? t? d?ng sdb1 sdb2 sdb3
                    create_partition_disk $nameOFdisk $capacityNumber $partitionNumber
                    echo " "
                    echo "Danh Sách phân vùng lsblk m?i"
                    echo " "
                    lsblk
                    # create_volume_group
                fi

            fi
        done
        ;;

    [nN])
        exit
        ;;
    esac
}

# MAIN FUNCTIONS
function tao_sdxY() {
    echo " "
    read -p "Nh?p tên ? ??a mu?n x? lý (? disk có d?ng sdX) : " nameOFdisk
    # Ki?m tra ký t? nh?p vào n?u > 3 thì báo nh?p sai ki?u tên ? c?ng
    if [ ${#nameOFdisk} -gt 3 ]; then
        echo "nh?p sai tên ? c?ng làm gì có ? c?ng nào tên là $nameOFdisk, t? thoát sau 3s "
        sleep 3
        exit
    else
        if ls /dev | grep -q $nameOFdisk; then
            # T?n t?i ? c?ng thì t?o ti?p t?c check dung l??ng
            mapfile -t size_free_space < <(parted /dev/$nameOFdisk unit s print free | awk '/Free Space/ {print $3}' | sed 's/s$//')

            array_length=${#size_free_space[@]}

            disk_space_sector_default="${size_free_space[0]}"
            disk_space_sector="${size_free_space[1]}"

            # echo "?? dài m?ng size_free_space ${#size_free_space[@]}"
            case $array_length in
            1)
                if [ "$disk_space_sector_default" -gt 5000 ]; then
                    echo "Dung l??ng còn, b?n có th? t?o ? c?ng"
                    accept_create
                else
                    echo "H?t dung l??ng"
                    exit
                fi
                ;;

            2 | *)

                if [ "$disk_space_sector" -gt 5000 ]; then
                    echo "Dung l??ng còn, b?n có th? t?o ? c?ng"
                    accept_create

                else
                    echo "H?t dung l??ng"
                    exit
                fi
                ;;
            esac

        else
            # Không t?n t?i
            echo "Không có ? c?ng nào là $nameOFdisk"
        fi
    fi

}

# MENU FUNCTION
echo "---------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------"
echo "----                                Nâng c?p ? c?ng                          ----"
echo "----                     Distribution Linux: Ubuntu/RHEL/CentOS              ----"
echo "----                                  **ver1.1**                           ----"
list_menu
echo "---------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------"
read -p "Vui lòng ch?n t? [1-${#arrayMenu[@]}]: " choice
case $choice in
1)
    clear
    lay_thong_tin_disk
    tao_sdxY
    ;;
2)
    clear
    exit
    ;;
*)
    clear
    exit
    ;;
esac
