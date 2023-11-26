# ---------------------------------- VARIABLE & EFFECT ----------------------------------
arrayMenu=("Khởi tạo partition + VG + LV mới + Mount" "Khởi tạo chương trình nâng cấp dung lượng" "Check log quá trình tạo ổ cứng" "Thoát")
mapfile -t vg_names < <(vgdisplay | awk '/VG Name/ {print $3}')
capacityNumber=""

function echo_space(){
    echo " "
}
function echo_dongke(){
    echo "----------------------------------------"
}
function echo_dongke_dai(){
    echo "------------------------------------------------------------------------------"
}
function exit_va_clear(){
    exit
    sleep 1
    clear
}
# ---------------------------------- END VARIABLE ----------------------------------


# ---------------------------------- Menu Content ----------------------------------
# Danh sách menu
function list_menu() {
    for ((i = 0; i < ${#arrayMenu[@]}; i++)); do
        echo "----                  $((i + 1)). ${arrayMenu[$i]}          "
    done
}
# Lấy thông tin disk
function lay_thong_tin_disk() {
    clear
    echo " "
    echo "============================ CHECK THÔNG TIN DISK <df -HT> ==================================="
    df -hT
    echo "----------------------------------------------------------------------------------------------"
    echo " "
    echo "============================ CHECK THÔNG TIN PARTITION <lsblk> ==============================="
    lsblk
    echo "----------------------------------------------------------------------------------------------"
}

# ---------------------------------- Điều kiện Cơ bản -------------------------------------
# Điều kiện check ký tự
function checkCharater {
    echo "[WARNING] Nhập sai điều kiện input, không có thông về dữ liệu $1"
}
function checkCharaterPhysicalVolume {
    echo "[WARNING] Nhập sai điều kiện input, không có thông về volume group cuar partition $1"
}
# Điều kiện chỉ được nhập số
function is_number() {
    [[ $1 =~ ^[0-9]+$ ]]
}


# ---------------------------------- TẠO CÁC THÀNH PHẦN -------------------------------------

# Tạo Partition trong fdisk
function create_partition_disk() {
    nameDisk=$1
    capacityDisk=$2
    partitionNumber=$3
    
    echo "Tên disk: $nameDisk"
    echo "Dung lượng: $capacityDisk"
    echo "Partition : $partitionNumber"
    # Nếu nhập số của phân vùng dạng sdb1,sdb2
    if [ -n "$3" ]; then
        echo_dongke
        echo "ĐANG TRONG QUÁ TRÌNH TẠO Ổ CỨNG"
        echo_dongke
        fdisk "/dev/$1" <<EOF
        n
        p
        $partitionNumber

        +${capacityDisk}G
        t

        8e
        w
EOF
        echo "HỆ THỐNG TỰ ĐỘNG TẠO PHYSICAL VOLUME THEO THÔNG SỐ ĐÃ KHAI BÁO"
        pvcreate /dev/$nameDisk$partitionNumber
        echo "TẠO PARTITION $nameDisk$partitionNumber THÀNH CÔNG"
    else
        # NHẤN ENTER LUÔN
        echo_dongke
        echo "ĐANG TRONG QUÁ TRÌNH TẠO Ổ CỨNG"
        echo_dongke
        fdisk "/dev/$1" <<EOF
        n
        p
        $partitionNumber

        +${capacityDisk}G
        t

        8e
        w
EOF
        echo_dongke
        echo "TẠO PARTITION THÀNH CÔNG"
        echo_dongke
    fi
    
}
# Tạo PHYSICAL Volume LV
function create_physical_volume {
    while true; do
        read -p "Vui lòng nhập partition vừa tạo vào để tạo physical_volume : " partition_name
        if [ ${#partition_name} -lt 4 ]; then
            checkCharaterPhysicalVolume $partition_name
        else
            # Kiểm tra xem có ổ đĩa đó không
            if ls /dev | grep -q $partition_name && [ -n "$partition_name" ]; then
                # Cần kiểm tra partition đã tạo volume hay chưa
                mapfile -t pv_names < <(pvdisplay /dev/$partition_name | awk '/PV Name/ {print $3}')
                for pv_name in "${pv_names[@]}"; do
                    if [ "/dev/$pv_name" == "/dev/$partition_name" ]; then
                        partition_check=true
                    else
                        partition_check=false
                    fi
                done
                
                if [ "$partition_check" == true ]; then
                    echo "Partition $partition_name chưa tạo physical volume"
                    break
                else
                    # Chuyển tiếp quá trình tạo volume group
                    pvcreate /dev/$partition_name
                    echo "Physical Volume đã được tạo:" $partition_name
                    break
                fi
                
            else
                echo "không có partition nào tên $partition_name"
            fi
            
            
        fi
    done
}

# Tạo VOLUME Volume LV
function create_volume_group() {
    echo_space
    
    while true; do
        read -p "Nhập tên volume group muốn tạo : " nameOfVolumeGroup
        # Check volume group
        found=false
        for vg_name in "${vg_names[@]}"; do
            if [ "$vg_name" == "$nameOfVolumeGroup" ]; then
                found=true
            fi
        done
        
        if [ "$found" == true ]; then
            echo "[WARNING] Tên $nameOfVolumeGroup đã được sử dụng rồi !"
        else
            echo_space
            echo "Tên '"$nameOfVolumeGroup"' có thể sử dụng"
            echo_space
            read -p "Đại hiệp có chắc muốn tạo volume group (VG) trên disk $nameOFdisk (y/n) : " choice
            echo_space
            case $choice in
                [yY])
                    echo_space
                    while true; do
                        read -p "Đại hiệp hãy xem lại danh sách lsblk mới nhất và điền phân vùng disk muốn tạo tạo volume group (viết dưới dạng sdx1,sdX2,..) " diskPartition
                        if [ ${#diskPartition} -lt 4 ]; then
                            checkCharater $diskPartition
                        else
                            # Kiểm tra ổ cứng
                            if ls /dev | grep -q $diskPartition; then
                                # Nếu tồn tại diskpartition thì tạo volume group check thêm điều kiện disk đã tạo volume group nào chưa
                                # Check tiếp disk đã tạo volume group hay chưa
                                vg_exist=$(pvdisplay /dev/$diskPartition | awk '/VG Name/ {print $3}')
                                echo $vg_exist
                                if [ -z "$vg_exist" ]; then
                                    echo "[INFO] Partition này chưa tạo volume group tạo nhé"
                                    echo_dongke
                                    vgcreate $nameOfVolumeGroup /dev/$diskPartition
                                    echo_dongke
                                    break 2  # Ngắt cả hai vòng lặp
                                else
                                    echo_space
                                    echo_dongke
                                    echo "[WARNING] Partition $diskPartition này đã tạo volume group (VG) $vg_exist rồi vui lòng chọn disk khác nhé"
                                    echo_dongke
                                    echo_space
                                fi
                            else
                                echo_space
                                echo_dongke
                                echo "[ERROR] không có ổ $diskPartition, hoặc ổ này đã đc tạo volume group rồi, hoặc không đúng định dạng"
                                echo_dongke
                                echo_space
                            fi
                        fi
                    done
                ;;
                
                [nN])
                    echo "Thoát"
                ;;
            esac
        fi
    done
}

# Tạo LOGICAL Volume LV
function create_logical_volume {
    #!/bin/bash
    
    while true; do
        read -p "Nhập tên logical volume muốn tạo: " nameOfLogicalVolume
        lvAndvg="${nameOfVolumeGroup}-${nameOfLogicalVolume}"
        
        if ls /dev/mapper | grep -q $lvAndvg; then
            echo_dongke
            echo "[WARNING] Logical volume '$lvAndvg' đã tồn tại. Vui lòng nhập tên khác!"
            echo_dongke
        else
            while true; do
                read -p "Người Đại hiệp muốn cấp cho logical volume bao nhiêu Phần trăm dung lượng nào? :" capacity_lv
                if [[ "$capacity_lv" =~ ^[0-9]+$ ]] && [ -n "$capacity_lv" ] && [ ${#capacity_lv} -lt 4 ]; then
                    if [ "$capacity_lv" -le 100 ]; then
                        echo "Dung lượng cấp phát: $capacity_lv%"
                        echo $nameOfVolumeGroup
                        lvcreate -l $capacity_lv%FREE $nameOfVolumeGroup --name $nameOfLogicalVolume
                        
                        while true; do
                            read -p "Lựa chọn kiểu định dạng filesystems cho $nameOfVolumeGroup-$nameOfLogicalVolume (ext4 hay xfs): " file_systems
                            file_system_name=$(echo "$file_systems" | tr '[:upper:]' '[:lower:]')
                            
                            case $file_system_name in
                                ext4)
                                    echo "Đã chọn kiểu định dạng: $file_system_name"
                                    mkfs.ext4 /dev/$nameOfVolumeGroup/$nameOfLogicalVolume
                                    echo "[SUCCESS] Logical volume đã được tạo và định dạng thành công $file_system_name."
                                    echo_space
                                    echo "Để mount thư mục vào Đại hiệp sử dụng lệnh sau nhé"
                                    echo_space
                                    echo_dongke_dai
                                    echo "mount /dev/$nameOfVolumeGroup/$nameOfLogicalVolume /path/<thư mục cần mount>"
                                    echo_dongke_dai
                                    break 3
                                ;;
                                xfs)
                                    echo "Đã chọn kiểu định dạng: $file_system_name"
                                    mkfs.xfs /dev/$nameOfVolumeGroup/$nameOfLogicalVolume
                                    echo "[SUCCESS] Logical volume đã được tạo và định dạng thành công $file_system_name."
                                    echo_space
                                    echo "Để mount thư mục vào Đại hiệp sử dụng lệnh sau nhé"
                                    echo_space
                                    echo_dongke_dai
                                    echo "mount /dev/$nameOfVolumeGroup/$nameOfLogicalVolume /path/<thư mục cần mount>"
                                    echo_dongke_dai
                                    break 3
                                ;;
                                *)
                                    echo "Lựa chọn không hợp lệ. Vui lòng chọn lại."
                                ;;
                            esac
                        done
                    else
                        echo "Vui lòng nhập số nhỏ hơn hoặc bằng 100."
                    fi
                else
                    echo "Vui lòng nhập số!"
                fi
            done
            echo_dongke
            echo_space
            echo "......Đang trong quá trình tạo Logical Volume......"
            echo_space
            echo_dongke
            break
        fi
    done
    
}

# Add Phân Vùng đã có
function addCapacity {
    echo "Sau khi đã tạo partition xong, Khởi tạo chương trình nâng cấp dung lượng"
}


# ---------------------------------- CHECK -------------------------------------

# Check điều kiện tạo ổ cứng và tạo ổ cứng
function conditionCreateDisk {
    while true; do
        read -p "Nhập số của phân vùng $nameOFdisk (chỉ cần nhập số), NÊN Enter ko nhập gì thì mặc định theo thứ tự (ví dụ: $nameOFdisk 1, $nameOFdisk 2,..): " partitionNumber
        
        if is_number "$partitionNumber" || [ -z "$partitionNumber" ]; then
            if ls /dev | grep -q $nameOFdisk$partitionNumber && [ -n "$partitionNumber" ]; then
                echo_space
                echo_dongke_dai
                echo "[ERROR]-Có ổ cứng này rồi người Đại hiệp ơi"
                echo_dongke_dai
                echo_space
            else
                while true; do
                    echo_dongke
                    read -p "Nhập dung lượng theo GB: " capacityNumber
                    echo_dongke
                    if is_number "$capacityNumber"; then
                        break
                    else
                        echo "Nhập số thôi người Đại hiệp?"
                    fi
                done
                
                if [ -n "$partitionNumber" ]; then
                    # Đẩy config theo số phân vùng được nhập vào fdisk
                    create_partition_disk $nameOFdisk $capacityNumber $partitionNumber
                    echo_dongke
                    echo " "
                    echo "LIST LSLBK MỚI , VUI LÒNG KIỂM TRA LẠI NHÉ: "
                    echo " "
                    lsblk
                    echo "----------- DONE -----------  "
                    echo_dongke
                    if [ "$choice_option" = 2 ]; then
                        # Sau khi đã tạo partition xong, Khởi tạo chương trình nâng cấp dung lượng
                        # echo "Sau khi đã tạo partition xong, Khởi tạo chương trình nâng cấp dung lượng"
                        create_physical_volume
                        addCapacity
                        break 3
                    else
                        # Khởi tạo partition + VG + LV mới + Mount
                        # echo " Khởi tạo partition + VG + LV mới + Mount"
                        create_volume_group
                        echo_dongke
                        create_logical_volume
                        exit_va_clear
                    fi
                else
                    # Nếu không nhập gì $partitionNumber là rỗng, Mặc định sẽ theo thứ tự là sdb1 sdb2 sdb3
                    create_partition_disk $nameOFdisk $capacityNumber $partitionNumber
                    echo_dongke
                    echo " "
                    echo "LIST LSLBK MỚI , VUI LÒNG KIỂM TRA LẠI NHÉ: "
                    echo " "
                    lsblk
                    echo "----------- DONE -----------  "
                    echo_dongke
                    # Nhập thông tin để tạo physical volume
                    if [ "$choice_option" = 2 ]; then
                        # Sau khi đã tạo partition xong, Khởi tạo chương trình nâng cấp dung lượng
                        # echo "Sau khi đã tạo partition xong, Khởi tạo chương trình nâng cấp dung lượng"
                        create_physical_volume
                        addCapacity
                        break 3
                    else
                        # Khởi tạo partition + VG + LV mới + Mount
                        # echo " Khởi tạo partition + VG + LV mới + Mount"
                        create_physical_volume
                        create_volume_group
                        echo_dongke
                        create_logical_volume
                        exit_va_clear
                    fi
                fi
                
            fi
        else
            echo "[WARNING] Nhập số thôi người Đại hiệp"
        fi
    done
}



# Đồng ý tạo ổ cứng
function accept_create() {
    read -p "Đại hiệp có đồng ý tạo ổ đĩa mới không? (y/n): " choice
    case $choice in
        [yY])
            conditionCreateDisk
        ;;
        
        [nN])
            exit_va_clear
        ;;
    esac
}
# ---------------------------------- Main Function -------------------------------------
# MAIN FUNCTIONS
function tao_sdxY() {
    echo " "
    read -p "Nhập tên ổ đĩa muốn tạo (nhập dạng sdx) : " nameOFdisk
    # Kiểm tra ký tự nhập
    if [ ${#nameOFdisk} -lt 3 ]; then
        checkCharater $nameOFdisk
        exit
    else
        if ls /dev | grep -q $nameOFdisk && [ ${#nameOFdisk} = 3 ]; then
            # Nếu tồn tại ổ cứng thì check tiếp dung lượng
            mapfile -t size_free_space < <(parted /dev/$nameOFdisk unit s print free | awk '/Free Space/ {print $3}' | sed 's/s$//')
            clear
            lay_thong_tin_disk
            echo_space
            array_length=${#size_free_space[@]}
            # echo $array_length
            if [ "$array_length" = 0 ]; then
                echo_dongke
                echo "[INFO] Có thể tạo phân vùng trên ổ cứng này !"
                echo_dongke
                accept_create
            else
                disk_space_sector_default="${size_free_space[0]}"
                disk_space_sector="${size_free_space[1]}"
                
                case $array_length in
                    1)
                        if [ "$disk_space_sector_default" -gt 5000 ]; then
                            echo_dongke
                            echo "[SUCCESS] Dung lượng vẫn còn Đại hiệp có thể tạo ổ cứng"
                            echo_dongke
                            accept_create
                        else
                            echo_space
                            echo "[ERROR] HẾT DUNG LƯỢNG Ổ CỨNG $nameOFdisk"
                            echo_space
                            exit
                        fi
                    ;;
                    
                    2 | *)
                        
                        if [ "$disk_space_sector" -gt 5000 ]; then
                            echo_dongke
                            echo "[SUCCESS] Dung lượng vẫn còn Đại hiệp có thể tạo ổ cứng"
                            echo_dongke
                            accept_create
                            
                        else
                            echo_space
                            echo "[ERROR] HẾT DUNG LƯỢNG Ổ CỨNG $nameOFdisk"
                            echo_space
                            exit
                        fi
                    ;;
                    
                esac
            fi
            
        else
            # Không tồn tại
            echo "Không có ổ cứng nào là $nameOFdisk"
        fi
    fi
    
}



######################## Menu script #########################
echo "---------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------"
echo "----                                                                         ----"
echo "----                                                                         ----"
echo "----                                 TOOL Ổ CỨNG                              ----"
echo "----                    For distribution Linux: Ubuntu/RHEL/CentOS           ----"
echo "----                                  **ver0.1**                             ----"
echo "----                                                                         ----"
echo "----                            *create by Daz9_Tu4n*                        ----"
echo "----                                                                         ----"
list_menu
echo "----                                                                         ----"
echo "---------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------"
echo_space
read -p "Vui lòng chọn option [1-${#arrayMenu[@]}] : " choice_option
case $choice_option in
    1)
        read -p " Đại hiệp chắc chắn muốn tiến hành tạo mới? (y/n) : " choice
        case $choice in
            [yY])
                clear
                lay_thong_tin_disk
                tao_sdxY
            ;;
            *)
                echo "Tạm biệt Đại hiệp"
            ;;
        esac
        
    ;;
    2)
        read -p " Đại hiệp chắc chắn muốn nâng khối lượng ổ cứng? (y/n) : " choice
        case $choice in
            [yY])
                lay_thong_tin_disk
                tao_sdxY
            ;;
            *)
                echo "Tạm biệt Đại hiệp"
            ;;
        esac
    ;;
    3)
        echo "Chức năng đang trong giai đoạn phát triển"
    ;;
    *)
        exit_va_clear
    ;;
esac