##### Variable List
arrayMenu=("Tạo phân vùng mơi" "Nâng dung lượng ổ cứng" "Thoát")
mapfile -t vg_names < <(vgdisplay | awk '/VG Name/ {print $3}')

# Danh sách menu
function list_menu() {
    for ((i = 0; i < ${#arrayMenu[@]}; i++)); do
        echo "                             $((i + 1)). ${arrayMenu[$i]}                          "
    done
}
# Lấy thông tin ổ disk
function lay_thong_tin_disk() {
    clear
    echo " "
    echo "============================ Check thông tin ổ đĩa df -HT ==================================="
    df -hT
    echo " "
    echo "============================ Check thông tin ổ đĩa lsblk ============================"
    lsblk
}

# Tạo phân vùng

function create_partition_disk() {
    fdisk "/dev/$1" <<EOF
    n
    p


    +2G
    t

    8e
    w
EOF
    echo "TẠO PARTITION THÀNH CÔNG"
}

# Tạo volume group
function create_volume_group() {
    read -p "Nhập tên volume-group muốn tạo : " nameOfVolumeGroup
    # Check volume group
    # echo " Danh sách volume group:  ${vg_names[@]}  "
    for vg_name in "${vg_names[@]}"; do
        if [ "$vg_name" == "$nameOfVolumeGroup" ]; then
            found=true
            break
        fi
    done
    if [ "$found" == true ]; then
        echo "Tên $nameOfVolumeGroup đã được sử dụng"
    else
        echo "Tên $nameOfVolumeGroup có thể sử dụng"
        read -p "Nhập tên phân vùng muốn tạo (nhập dạng sdbx) : " partition_number
        vgcreate $nameOfVolumeGroup /dev/$partition_number
    fi
}

# Main Function
function tao_sdxY() {
    echo " "
    read -p "Nhập tên ổ đĩa muốn xử lý (ổ disk có dạng sdX) : " nameOFdisk
    # Kiểm tra ký tự nhập vào nếu > 3 thì báo nhập sai kiểu tên ổ cứng
    if [ ${#nameOFdisk} -gt 3 ]; then
        echo "nhập sai tên ổ cứng làm gì có ổ cứng nào tên là $nameOFdisk, tự thoát sau 3s "
        sleep 3
        exit
    else
        if ls /dev | grep -q $nameOFdisk; then
            # Tồn tại ổ cứng thì tạo tiếp tục check dung lượng

            mapfile -t size_free_space < <(parted /dev/$nameOFdisk unit s print free | awk '/Free Space/ {print $3}' | sed 's/s$//')
            disk_space_sector_default= "${size_free_space[0]}"
            disk_space_sector="${size_free_space[1]}"
            echo "Sector còn là $disk_space_sector"

            if [ [ "$disk_space_sector" ] > 2000 || [ "$disk_space_sector_default" ] = 1985 ]; then
                echo "Dung lượng còn"
                # create_partition_disk $nameOFdisk
                echo " "
                echo " Danh Sách phân vùng lsblk mới"
                echo " "
                lsblk
                create_volume_group
            else
                echo "Hết dung lượng "
                exit
            fi

        else
            # Không tồn tại
            echo "Không có ổ cứng nào là $nameOFdisk"
        fi
    fi

}

echo "---------------------------------------------------------------------------------"
echo "----                                Nâng cấp ổ cứng                          ----"
echo "----                     Distribution Linux: Ubuntu/RHEL/CentOS              ----"
echo "----                                  ********                               ----"
list_menu
echo "---------------------------------------------------------------------------------"
read -p "Vui lòng chọn từ [1-${#menu[@]}]: " choice
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
