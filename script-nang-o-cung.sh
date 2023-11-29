
# Khởi tạo thư mục log
# Kiểm tra thư mục log tồn tại
if ls /var/log | grep -q nangDisk; then
    echo "Có thông tin"
    touch /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
else
    mkdir -p /var/log/nangDisk
    touch /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
fi


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
    echo "[WARNING] Nhập sai điều kiện input, không có thông về dữ liệu $1"  >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
}
function checkCharaterPhysicalVolume {
    echo "[WARNING] Nhập sai điều kiện input, không có thông về volume group cuar partition $1" >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
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
        partprobe
        echo "HỆ THỐNG TỰ ĐỘNG TẠO PHYSICAL VOLUME THEO THÔNG SỐ ĐÃ KHAI BÁO"
        pvcreate /dev/$nameDisk$partitionNumber
        echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-TẠO PARTITION $nameDisk$partitionNumber THÀNH CÔNG"
        echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-TẠO PARTITION $nameDisk$partitionNumber THÀNH CÔNG" >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
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
        partprobe
        echo_dongke
        echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-TẠO PARTITION THÀNH CÔNG"
        echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-TẠO PARTITION THÀNH CÔNG" >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
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
                    echo "$(date +%Y/%m/%d-%H:%M)-[INFO]-Partition $partition_name chưa tạo physical volume"  >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
                    break
                else
                    # Chuyển tiếp quá trình tạo volume group
                    pvcreate /dev/$partition_name
                    echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-Physical Volume đã được tạo:" $partition_name
                    echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-Physical Volume đã được tạo:" $partition_name >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
                    break
                fi
                
            else
                echo "không có partition nào tên $partition_name"
                echo "$(date +%Y/%m/%d-%H:%M)-[ERROR]-không có partition nào tên $partition_name"  >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
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
            echo "$(date +%Y/%m/%d-%H:%M)-[WARNING] Tên $nameOfVolumeGroup đã được sử dụng rồi !"
        else
            echo_space
            echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-Tên '"$nameOfVolumeGroup"' có thể sử dụng" >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
            echo_space
            read -p "Bạn có chắc muốn tạo volume group (VG) trên disk $nameOFdisk (y/n) : " choice
            echo_space
            case $choice in
                [yY])
                    echo_space
                    while true; do
                        read -p "Bạn hãy xem lại danh sách lsblk mới nhất và điền phân vùng disk muốn tạo tạo volume group (viết dưới dạng sdx1,sdX2,..) " diskPartition
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
                                    echo "$(date +%Y/%m/%d-%H:%M)-[INFO] Partition này chưa tạo volume group tạo nhé"
                                    echo_dongke
                                    vgcreate $nameOfVolumeGroup /dev/$diskPartition
                                    echo_dongke
                                    break 2  # Ngắt cả hai vòng lặp
                                else
                                    echo_space
                                    echo_dongke
                                    echo "$(date +%Y/%m/%d-%H:%M)-[WARNING] Partition $diskPartition này đã tạo volume group (VG) $vg_exist rồi vui lòng chọn disk khác nhé" >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
                                    echo_dongke
                                    echo_space
                                fi
                            else
                                echo_space
                                echo_dongke
                                echo "$(date +%Y/%m/%d-%H:%M)-[ERROR] không có ổ $diskPartition, hoặc ổ này đã đc tạo volume group rồi, hoặc không đúng định dạng" >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
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
            echo "$(date +%Y/%m/%d-%H:%M)-[WARNING]-Logical volume '$lvAndvg' đã tồn tại. Vui lòng nhập tên khác!" >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
            echo_dongke
        else
            while true; do
                read -p "Người Bạn muốn cấp cho logical volume bao nhiêu Phần trăm dung lượng nào? :" capacity_lv
                if [[ "$capacity_lv" =~ ^[0-9]+$ ]] && [ -n "$capacity_lv" ] && [ ${#capacity_lv} -lt 4 ]; then
                    if [ "$capacity_lv" -le 100 ]; then
                        echo "Dung lượng cấp phát: $capacity_lv%"
                        echo "$(date +%Y/%m/%d-%H:%M)-[INFO]-Dung lượng cấp phát: $capacity_lv%" >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
                        echo $nameOfVolumeGroup
                        lvcreate -l $capacity_lv%FREE $nameOfVolumeGroup --name $nameOfLogicalVolume
                        
                        while true; do
                            read -p "Lựa chọn kiểu định dạng filesystems cho $nameOfVolumeGroup-$nameOfLogicalVolume (ext4 hay xfs): " file_systems
                            file_system_name=$(echo "$file_systems" | tr '[:upper:]' '[:lower:]')
                            
                            case $file_system_name in
                                ext4)
                                    echo "Đã chọn kiểu định dạng: $file_system_name"
                                    mkfs.ext4 /dev/$nameOfVolumeGroup/$nameOfLogicalVolume
                                    echo " Logical volume đã được tạo và định dạng thành công $file_system_name."
                                    echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS] Logical volume đã được tạo và định dạng thành công $file_system_name." >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
                                    echo_space
                                    echo "Để mount thư mục vào Bạn sử dụng lệnh sau nhé"
                                    echo_space
                                    echo_dongke_dai
                                    echo "mount /dev/$nameOfVolumeGroup/$nameOfLogicalVolume /path/<thư mục cần mount>"
                                    echo_dongke_dai
                                    break 3
                                ;;
                                xfs)
                                    echo "Đã chọn kiểu định dạng: $file_system_name"
                                    mkfs.xfs /dev/$nameOfVolumeGroup/$nameOfLogicalVolume
                                    echo "Logical volume đã được tạo và định dạng thành công $file_system_name."
                                    echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-Logical volume đã được tạo và định dạng thành công $file_system_name." >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
                                    echo_space
                                    echo "Để mount thư mục vào Bạn sử dụng lệnh sau nhé"
                                    echo_space
                                    echo_dongke_dai
                                    echo "mount /dev/$nameOfVolumeGroup/$nameOfLogicalVolume /path/<thư mục cần mount>"
                                    echo_dongke_dai
                                    break 3
                                ;;
                                *)
                                    echo "$(date +%Y/%m/%d-%H:%M)-[ERROR]-Lựa chọn không hợp lệ. Vui lòng chọn lại."
                                ;;
                            esac
                        done
                    else
                        echo "$(date +%Y/%m/%d-%H:%M)-[WARNING]-Vui lòng nhập số nhỏ hơn hoặc bằng 100."
                    fi
                else
                    echo "$(date +%Y/%m/%d-%H:%M)-[WARNING]-Vui lòng nhập số!"
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

# Extend Volume Group
function extendVolumeGroup {
    echo "Sau khi đã tạo partition xong, Khởi tạo chương trình nâng cấp dung lượng cho volume group"
    while true; do
        # Nhập tên volume group
        read -p "Hãy nhập tên của vg-group cần extend dung lượng vào đây : " vg_group_name
        # Điều kiện nhập phải khác rỗng
        if [ ${#vg_group_name} = 0 ]; then
            echo "Bạn cần phải nhập tên volume group"
        else
            # echo "Truyền tham số xuống $2 , độ dài là  ${#2} "
            # Nhập rồi phải kiểm tra xem có thông tin của vg-group hay không
            if ls /dev | grep -q $vg_group_name; then
                echo "Có thông tin"
                
                # Nếu nhấn enter thì mặc định sẽ extend có thông số number không có thì phải nhập
                if [ ${#2} -eq 0 ]; then
                    # echo "Trường hợp nhấn enter disk khi tạo"
                    echo "$partition_name "
                    vgextend $vg_group_name /dev/$partition_name
                    pvscan
                    break
                else
                    # Extend Volume Group
                    vgextend $vg_group_name /dev/$nameOFdisk$partitionNumber
                    pvscan
                    break
                fi
            else
                echo "$(date +%Y/%m/%d-%H:%M)-[ERROR]-Không có thông tin của Volume Group" >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
            fi
        fi
    done
}

# Extend Logical Volume
function extendLogicalVolume {
    echo "Nâng cấp dữ liệu cho logical volume"
    while true; do
        # Nhập tên logical volume
        read -p "Hãy nhập tên của Logical Volume cần extend dung lượng vào đây : " logical_volume_name
        if [ ${#logical_volume_name} = 0 ]; then
            echo "Bạn cần phải nhập tên logical volume"
            echo "$(date +%Y/%m/%d-%H:%M)-[ERROR]-Bạn cần phải nhập tên logical volume" >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
        else
            # echo "Truyền tham số xuống $2 , độ dài là  ${#2} "
            # echo "Truyền tham số xuống $2 "
            
            # Check kiểu filesystems của phân vùng
            vg_name_fixed=$(echo "$vg_group_name" | sed 's/-/--/g')
            lv_name_fixed=$(echo "$logical_volume_name" | sed 's/-/--/g')
            
            # Kiểm tra filesystems:
            fileSystem_disk=$(df -hT /dev/mapper/$vg_name_fixed-$lv_name_fixed | awk 'NR>1 {print $2}')
            
            echo 'Kiểu file systems là:' $fileSystem_disk
            
            # Nếu nhấn enter thì mặc định sẽ extend có thông số number không có thì phải nhập
            if [ ${#2} -eq 0 ]; then
                echo "Nâng cấp dung lượng theo trạng thái mặc định"
                echo "$(date +%Y/%m/%d-%H:%M)-[INFO]-Nâng cấp dung lượng theo trạng thái mặc định" >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
                # read -p "Hãy nhập tên của partition để extend cho logical volume : " partition_name
                # echo "$partition_name "
                lvextend /dev/$vg_group_name/$logical_volume_name /dev/$partition_name
                
                case $fileSystem_disk in
                    ext4)
                        # Thực thi các lệnh cho hệ thống tập tin ext4
                        echo "Thực thi Resize cho filesystem $fileSystem_disk thành công "
                        echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-Thực thi Resize cho filesystem $fileSystem_disk thành công " >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
                        resize2fs /dev/$vg_group_name/$logical_volume_name
                        
                    ;;
                    
                    xfs)
                        # Thực thi các lệnh cho hệ thống tập tin xfs
                        echo "Thực thi Resize cho filesystem $fileSystem_disk thành công "
                        echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-Thực thi Resize cho filesystem $fileSystem_disk thành công " >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
                        xfs_growfs /dev/$vg_group_name/$logical_volume_name
                    ;;
                    
                    *)
                        echo "Hệ thống tập tin không được hỗ trợ"
                        echo "$(date +%Y/%m/%d-%H:%M) - [ERROR]- Hệ thống tập tin không được hỗ trợ"  >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
                    ;;
                esac
                break
            else
                
                if ls /dev/$vg_group_name | grep -q $logical_volume_name; then
                    echo "Có thông tin"
                    lvextend /dev/$vg_group_name/$logical_volume_name /dev/$nameOFdisk$partitionNumber
                    
                    case $fileSystem_disk in
                        ext4)
                            # Thực thi các lệnh cho hệ thống tập tin ext4
                            echo "Thực thi Resize cho filesystem $fileSystem_disk thành công "
                            echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-Thực thi Resize cho filesystem $fileSystem_disk thành công " >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
                            resize2fs /dev/$vg_group_name/$logical_volume_name
                            
                        ;;
                        
                        xfs)
                            # Thực thi các lệnh cho hệ thống tập tin xfs
                            echo "Thực thi Resize cho filesystem $fileSystem_disk thành công "
                            echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-Thực thi Resize cho filesystem $fileSystem_disk thành công " >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
                            xfs_growfs /dev/$vg_group_name/$logical_volume_name
                        ;;
                        
                        *)
                            echo "Hệ thống tập tin không được hỗ trợ"
                            echo "$(date +%Y/%m/%d-%H:%M) - [ERROR]- Hệ thống tập tin không được hỗ trợ"  >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
                        ;;
                    esac
                    
                    
                    
                    break
                else
                    echo "$(date +%Y/%m/%d-%H:%M)-[ERROR]-Không có thông tin"  >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
                fi
            fi
        fi
    done
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
                echo "$(date +%Y/%m/%d-%H:%M)-[ERROR]-Có ổ cứng này rồi người Bạn ơi" >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
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
                        echo "$(date +%Y/%m/%d-%H:%M)-[ERROR]-Nhập số thôi người Bạn?" >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
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
                        extendVolumeGroup $nameOFdisk $partitionNumber
                        extendLogicalVolume $nameOFdisk $partitionNumber
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
                        extendVolumeGroup $nameOFdisk $partitionNumber
                        extendLogicalVolume $nameOFdisk $partitionNumber
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
            echo "$(date +%Y/%m/%d-%H:%M)-[WARNING] vui lòng nhập số thôi người Bạn" >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
        fi
    done
}



# Đồng ý tạo ổ cứng
function accept_create() {
    read -p "Bạn có đồng ý tạo ổ đĩa mới không? (y/n): " choice
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
                echo "$(date +%Y/%m/%d-%H:%M)-[INFO] Có thể tạo phân vùng trên ổ cứng này !" >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
                echo_dongke
                accept_create
            else
                disk_space_sector_default="${size_free_space[0]}"
                disk_space_sector="${size_free_space[1]}"
                
                case $array_length in
                    1)
                        if [ "$disk_space_sector_default" -gt 5000 ]; then
                            echo_dongke
                            echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-Dung lượng vẫn còn Bạn có thể tạo ổ cứng"  >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
                            echo_dongke
                            accept_create
                        else
                            echo_space
                            echo "$(date +%Y/%m/%d-%H:%M)-[ERROR]-HẾT DUNG LƯỢNG Ổ CỨNG $nameOFdisk" >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
                            echo_space
                            exit
                        fi
                    ;;
                    
                    2 | *)
                        
                        if [ "$disk_space_sector" -gt 5000 ]; then
                            echo_dongke
                            echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS] Dung lượng vẫn còn Bạn có thể tạo ổ cứng" >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
                            echo_dongke
                            accept_create
                            
                        else
                            echo_space
                            echo "$(date +%Y/%m/%d-%H:%M)-[ERROR]- HẾT DUNG LƯỢNG Ổ CỨNG $nameOFdisk" >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
                            echo_space
                            exit
                        fi
                    ;;
                    
                esac
            fi
            
        else
            # Không tồn tại
            echo "$(date +%Y/%m/%d-%H:%M)-[ERROR]-Không có ổ cứng nào là $nameOFdisk" >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
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
echo "----                                                                         ----"
list_menu
echo "----                                                                         ----"
echo "---------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------"
echo_space
read -p "Vui lòng chọn option [1-${#arrayMenu[@]}] : " choice_option
case $choice_option in
    1)
        read -p " Bạn chắc chắn muốn tiến hành tạo mới? (y/n) : " choice
        case $choice in
            [yY])
                clear
                lay_thong_tin_disk
                tao_sdxY
            ;;
            *)
                echo "Good bye!"
            ;;
        esac
        
    ;;
    2)
        read -p " Bạn chắc chắn muốn nâng khối lượng ổ cứng? (y/n) : " choice
        case $choice in
            [yY])
                lay_thong_tin_disk
                tao_sdxY
            ;;
            *)
                echo "Good bye!"
            ;;
        esac
    ;;
    3)
        cat /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
        # echo "$(date +%Y/%m/%d-%H:%M)-[ERROR] Chức năng đang trong giai đoạn phát triển" >> /var/log/nangDisk/nang-disk-$(date +%Y%m%d).log
    ;;
    *)
        exit_va_clear
    ;;
esac