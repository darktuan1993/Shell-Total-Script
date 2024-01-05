
# Create thư mục log
# Kiểm tra thư mục log tồn tại
if ls /var/log | grep -q tool-script; then
    echo "The detection system has information"
    touch /var/log/tool-script/tool-$(date +%Y%m%d).log
else
    mkdir -p /var/log/tool-script
    touch /var/log/tool-script/tool-$(date +%Y%m%d).log
fi


# ---------------------------------- VARIABLE & EFFECT ----------------------------------
arrayMenu=("Tao moi partition + volumn group + logical volume + Mount folder" "Nang dung luong o cung LVM" "View log manage disk" "SWAP" "Exit")
arrayMenuSwap=("Su dung swapfile" "Add Phan vung cho swap" "Exit")
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

# Danh sách menu Swap
function list_menu_swap() {
    for ((i = 0; i < ${#arrayMenuSwap[@]}; i++)); do
        echo "----                  $((i + 1)). ${arrayMenuSwap[$i]}          "
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
    echo "[WARNING] Wrong input condition, no data information $1"
    echo "[WARNING] Wrong input condition, no data information $1"  >> /var/log/tool-script/tool-$(date +%Y%m%d).log
}
function checkCharaterPhysicalVolume {
    echo "[WARNING] Wrong input conditions, no information about the partition's volume group $1" >> /var/log/tool-script/tool-$(date +%Y%m%d).log
    echo "[WARNING] Wrong input conditions, no information about the partition's volume group $1"
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
    echo_dongke_dai
    echo "Tên disk: $nameDisk"
    echo "Dung lượng: $capacityDisk"
    echo "Partition : $partitionNumber"
    echo_dongke_dai
    # Nếu nhập số của phân vùng dạng sdb1,sdb2
    if [ -n "$3" ]; then
        echo_dongke
        echo "HARD DRIVE CREATION IS IN PROCESS"
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
        echo "THE SYSTEM AUTOMATICALLY CREATES PHYSICAL VOLUME ACCORDING TO THE DECLARED PARAMETERS"
        pvcreate /dev/$nameDisk$partitionNumber
        echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-CREATE PARTITION $nameDisk$partitionNumber SUCCESS !!"
        echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-CREATE PARTITION $nameDisk$partitionNumber SUCCESS !!" >> /var/log/tool-script/tool-$(date +%Y%m%d).log
    else
        # NHẤN ENTER LUÔN
        echo_dongke
        echo "HARD DRIVE CREATION IS IN PROCESS"
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
        echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-CREATE PARTITION SUCCESS"
        echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-CREATE PARTITION SUCCESS" >> /var/log/tool-script/tool-$(date +%Y%m%d).log
        echo_dongke
    fi
    
}
# Tạo PHYSICAL Volume LV
function create_physical_volume {
    while true; do
        read -p "Please import the newly created partition to create physical_volume (example: sdx1, sdx2,...) : " partition_name
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
                    echo "Partition $partition_name physical volume has not been created !"
                    echo "$(date +%Y/%m/%d-%H:%M)-[INFO]-Partition $partition_name physical volume has not been created"  >> /var/log/tool-script/tool-$(date +%Y%m%d).log
                    break
                else
                    # Chuyển tiếp quá trình tạo volume group
                    pvcreate /dev/$partition_name
                    echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-Physical Volume has been created:" $partition_name
                    echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-Physical Volume has been created:" $partition_name >> /var/log/tool-script/tool-$(date +%Y%m%d).log
                    break
                fi
                
            else
                echo "There is no partition named $partition_name"
                echo "$(date +%Y/%m/%d-%H:%M)-[ERROR]-There is no partition named $partition_name"  >> /var/log/tool-script/tool-$(date +%Y%m%d).log
            fi
            
            
        fi
    done
}

# Tạo VOLUME Volume LV
function create_volume_group() {
    echo_space
    
    while true; do
        read -p "Enter the name of the volume group you want to create : " nameOfVolumeGroup
        # Check volume group
        found=false
        for vg_name in "${vg_names[@]}"; do
            if [ "$vg_name" == "$nameOfVolumeGroup" ]; then
                found=true
            fi
        done
        
        if [ "$found" == true ]; then
            echo "$(date +%Y/%m/%d-%H:%M)-[WARNING] The name $nameOfVolumeGroup is already taken!"
        else
            echo_space
            echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-The name '"$nameOfVolumeGroup"' can be used" >> /var/log/tool-script/tool-$(date +%Y%m%d).log
            echo_space
            read -p "Are you sure you want to create a volume group (VG) on disk $nameOFdisk (y/n) : " choice
            echo_space
            case $choice in
                [yY])
                    echo_space
                    while true; do
                        read -p "Please review the latest lsblk list and fill in the disk partition you want to create the volume group (written as sdx1, sdX2,..) " diskPartition
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
                                    echo "$(date +%Y/%m/%d-%H:%M)-[INFO]-This partition has not yet created a volume group"
                                    echo_dongke
                                    vgcreate $nameOfVolumeGroup /dev/$diskPartition
                                    echo_dongke
                                    break 2  # Ngắt cả hai vòng lặp
                                else
                                    echo_space
                                    echo_dongke
                                    echo "$(date +%Y/%m/%d-%H:%M)-[WARNING]-Partition $diskPartition has created a volume group (VG). $vg_exist then please choose another disk" >> /var/log/tool-script/tool-$(date +%Y%m%d).log
                                    echo_dongke
                                    echo_space
                                fi
                            else
                                echo_space
                                echo_dongke
                                echo "$(date +%Y/%m/%d-%H:%M)-[ERROR]-No drive $diskPartition, Either this drive has already been created as a volume group, or it is not in the correct format" >> /var/log/tool-script/tool-$(date +%Y%m%d).log
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
        read -p "Enter the name of the logical volume you want to create: " nameOfLogicalVolume
        lvAndvg="${nameOfVolumeGroup}-${nameOfLogicalVolume}"
        
        if ls /dev/mapper | grep -q $lvAndvg; then
            echo_dongke
            echo "$(date +%Y/%m/%d-%H:%M)-[WARNING]-Logical volume '$lvAndvg' already exists. Please enter another name!" >> /var/log/tool-script/tool-$(date +%Y%m%d).log
            echo_dongke
        else
            while true; do
                read -p "How much per capacity do you want to allocate to the logical volume? (nhap tu 1 - 100) :" capacity_lv
                if [[ "$capacity_lv" =~ ^[0-9]+$ ]] && [ -n "$capacity_lv" ] && [ ${#capacity_lv} -lt 4 ]; then
                    if [ "$capacity_lv" -le 100 ]; then
                        echo "Dung lượng cấp phát: $capacity_lv%"
                        echo "$(date +%Y/%m/%d-%H:%M)-[INFO]-Allocated capacity: $capacity_lv%" >> /var/log/tool-script/tool-$(date +%Y%m%d).log
                        echo $nameOfVolumeGroup
                        lvcreate -l $capacity_lv%FREE $nameOfVolumeGroup --name $nameOfLogicalVolume
                        
                        while true; do
                            read -p "Select the filesystems format for $nameOfVolumeGroup-$nameOfLogicalVolume (ext4 hay xfs): " file_systems
                            file_system_name=$(echo "$file_systems" | tr '[:upper:]' '[:lower:]')
                            
                            case $file_system_name in
                                ext4)
                                    echo "Format type selected: $file_system_name"
                                    mkfs.ext4 /dev/$nameOfVolumeGroup/$nameOfLogicalVolume
                                    echo " The logical volume has been created and formatted SUCCESS $file_system_name."
                                    echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-The logical volume has been created and formatted SUCCESS $file_system_name." >> /var/log/tool-script/tool-$(date +%Y%m%d).log
                                    echo_space
                                    echo "To mount the folder, use the following command"
                                    echo_space
                                    echo_dongke_dai
                                    echo "mount /dev/$nameOfVolumeGroup/$nameOfLogicalVolume /path/<thư mục cần mount>"
                                    echo_dongke_dai
                                    break 3
                                ;;
                                xfs)
                                    echo "Format type selected: $file_system_name"
                                    mkfs.xfs /dev/$nameOfVolumeGroup/$nameOfLogicalVolume
                                    echo "The logical volume has been created and formatted SUCCESS $file_system_name."
                                    echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-The logical volume has been created and formatted SUCCESS $file_system_name." >> /var/log/tool-script/tool-$(date +%Y%m%d).log
                                    echo_space
                                    echo "To mount the folder, use the following command"
                                    echo_space
                                    echo_dongke_dai
                                    echo "mount /dev/$nameOfVolumeGroup/$nameOfLogicalVolume /path/<thư mục cần mount>"
                                    echo_dongke_dai
                                    break 3
                                ;;
                                *)
                                    echo "$(date +%Y/%m/%d-%H:%M)-[ERROR]-Invalid selection. Please select again."
                                ;;
                            esac
                        done
                    else
                        echo "$(date +%Y/%m/%d-%H:%M)-[WARNING]-Please enter a number less than or equal to 100%."
                    fi
                else
                    echo "$(date +%Y/%m/%d-%H:%M)-[WARNING]-Please enter number!"
                fi
            done
            echo_dongke
            echo_space
            echo "......In the process of creating a Logical Volume......"
            echo_space
            echo_dongke
            break
        fi
    done
    
}

# Extend Volume Group
function extendVolumeGroup {
    echo "After creating the partition, Create the program to upgrade the capacity of the volume group"
    while true; do
        # Nhập tên volume group
        read -p "Please enter the name of the volume group that needs to expand capacity here : " vg_group_name
        # Điều kiện nhập phải khác rỗng
        if [ ${#vg_group_name} = 0 ]; then
            echo "You need to enter the volume group name"
        else
            # echo "Truyền tham số xuống $2 , độ dài là  ${#2} "
            # Nhập rồi phải kiểm tra xem có thông tin của vg-group hay không
            if ls /dev | grep -q $vg_group_name; then
                echo "Have information"
                
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
                echo "$(date +%Y/%m/%d-%H:%M)-[ERROR]-There is no information about Volume-Group" >> /var/log/tool-script/tool-$(date +%Y%m%d).log
            fi
        fi
    done
}

# Extend Logical Volume
function extendLogicalVolume {
    echo "Upgrade data for logical volume"
    while true; do
        # Nhập tên logical volume
        read -p "Please enter the name of the Logical Volume whose capacity you need to extend here : " logical_volume_name
        if [ ${#logical_volume_name} = 0 ]; then
            echo "You need to enter a logical volume name"
            echo "$(date +%Y/%m/%d-%H:%M)-[ERROR]-You need to enter a logical volume name" >> /var/log/tool-script/tool-$(date +%Y%m%d).log
        else
            # echo "Truyền tham số xuống $2 , độ dài là  ${#2} "
            # echo "Truyền tham số xuống $2 "
            
            # Check kiểu filesystems của phân vùng
            vg_name_fixed=$(echo "$vg_group_name" | sed 's/-/--/g')
            lv_name_fixed=$(echo "$logical_volume_name" | sed 's/-/--/g')
            
            # Kiểm tra filesystems:
            fileSystem_disk=$(df -hT /dev/mapper/$vg_name_fixed-$lv_name_fixed | awk 'NR>1 {print $2}')
            
            echo 'The file system type is:' $fileSystem_disk
            
            # Nếu nhấn enter thì mặc định sẽ extend có thông số number không có thì phải nhập
            if [ ${#2} -eq 0 ]; then
                echo "Upgrade capacity according to default status"
                echo "$(date +%Y/%m/%d-%H:%M)-[INFO]-Upgrade capacity according to default status" >> /var/log/tool-script/tool-$(date +%Y%m%d).log
                # read -p "Hãy nhập tên của partition để extend cho logical volume : " partition_name
                # echo "$partition_name "
                lvextend /dev/$vg_group_name/$logical_volume_name /dev/$partition_name
                
                case $fileSystem_disk in
                    ext4)
                        # Thực thi các lệnh cho hệ thống tập tin ext4
                        echo "Execute Resize for filesystem $fileSystem_disk SUCCESS "
                        echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-Execute Resize for filesystem $fileSystem_disk SUCCESS " >> /var/log/tool-script/tool-$(date +%Y%m%d).log
                        resize2fs /dev/$vg_group_name/$logical_volume_name
                        
                    ;;
                    
                    xfs)
                        # Thực thi các lệnh cho hệ thống tập tin xfs
                        echo "Execute Resize for filesystem $fileSystem_disk SUCCESS "
                        echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-Execute Resize for filesystem $fileSystem_disk SUCCESS " >> /var/log/tool-script/tool-$(date +%Y%m%d).log
                        xfs_growfs /dev/$vg_group_name/$logical_volume_name
                    ;;
                    
                    *)
                        echo "File systems are not supported"
                        echo "$(date +%Y/%m/%d-%H:%M) - [ERROR]- File systems are not supported"  >> /var/log/tool-script/tool-$(date +%Y%m%d).log
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
                            echo "Execute Resize for filesystem $fileSystem_disk SUCCESS "
                            echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-Execute Resize for filesystem $fileSystem_disk SUCCESS " >> /var/log/tool-script/tool-$(date +%Y%m%d).log
                            resize2fs /dev/$vg_group_name/$logical_volume_name
                            
                        ;;
                        
                        xfs)
                            # Thực thi các lệnh cho hệ thống tập tin xfs
                            echo "Execute Resize for filesystem $fileSystem_disk SUCCESS "
                            echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-Execute Resize for filesystem $fileSystem_disk SUCCESS " >> /var/log/tool-script/tool-$(date +%Y%m%d).log
                            xfs_growfs /dev/$vg_group_name/$logical_volume_name
                        ;;
                        
                        *)
                            echo "File systems are not supported"
                            echo "$(date +%Y/%m/%d-%H:%M) - [ERROR]- File systems are not supported"  >> /var/log/tool-script/tool-$(date +%Y%m%d).log
                        ;;
                    esac
                    
                    
                    
                    break
                else
                    echo "$(date +%Y/%m/%d-%H:%M)-[ERROR]-No information"  >> /var/log/tool-script/tool-$(date +%Y%m%d).log
                fi
            fi
        fi
    done
}

# Extend Swap
function extendSwapDisk {
    read -p "Nhập volume group swap cần extend :" vg_extend
    
    echo $partition_name
    echo $vg_extend
    vgextend $vg_extend /dev/$partition_name
    lvextend -l +100%FREE /dev/$vg_extend/swap
    echo_dongke
    echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-Extend sucess for partition swap !!!"
    echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-Extend sucess for partition swap !!!" > /var/log/tool-script/tool-$(date +%Y%m%d).log
    echo_dongke
    swapoff -v /dev/$vg_extend/swap
    mkswap /dev/$vg_extend/swap
    swapon -va
}

function usingFileSwap {
    counter=0
    while [ -e "/swapfile_$(date +%Y-%m-%d-%H)-$counter" ]; do
        counter=$((counter+1))
    done
    sudo dd if=/dev/zero of="/swapfile_$(date +%Y-%m-%d-%H)-$counter" bs=1M count=$1
    mkswap /swapfile_$(date +%Y-%m-%d-%H)-$counter
    chmod 0644 /swapfile_$(date +%Y-%m-%d-%H)-$counter
    swapon /swapfile_$(date +%Y-%m-%d-%H)-$counter
    echo_space
    echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-Uprade dung luong swap thành công"
    echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-Uprade dung luong swap thành công" >> /var/log/tool-script/tool-$(date +%Y%m%d).log
    echo_space
    echo_dongke_dai
    free -h
    echo_dongke_dai
    break
    
}

# ---------------------------------- CHECK -------------------------------------

# Check điều kiện tạo ổ cứng và tạo ổ cứng
function conditionCreateDisk {
    while true; do
        read -p "Input the partition number $nameOFdisk (just enter the number), SHOULD If Enter does not enter anything, it will default to the order (ex: $nameOFdisk 1, $nameOFdisk 2,..): " partitionNumber
        
        if is_number "$partitionNumber" || [ -z "$partitionNumber" ]; then
            if ls /dev | grep -q $nameOFdisk$partitionNumber && [ -n "$partitionNumber" ]; then
                echo_space
                echo_dongke_dai
                echo "$(date +%Y/%m/%d-%H:%M)-[ERROR]-Hard drive has been there !" >> /var/log/tool-script/tool-$(date +%Y%m%d).log
                echo_dongke_dai
                echo_space
            else
                while true; do
                    echo_dongke
                    read -p "Input capacity in GB: " capacityNumber
                    echo_dongke
                    if is_number "$capacityNumber"; then
                        break
                    else
                        echo "$(date +%Y/%m/%d-%H:%M)-[ERROR]-Just enter the number, friend?" >> /var/log/tool-script/tool-$(date +%Y%m%d).log
                    fi
                done
                
                if [ -n "$partitionNumber" ]; then
                    # Đẩy config theo số phân vùng được nhập vào fdisk
                    create_partition_disk $nameOFdisk $capacityNumber $partitionNumber
                    echo_dongke
                    echo " "
                    echo "NEW LSBLK LIST, PLEASE CHECK AGAIN: "
                    echo " "
                    lsblk
                    echo "----------- DONE -----------  "
                    echo_dongke
                    if [ "$choice_option" = 2 ]; then
                        # Sau khi đã tạo partition xong, Create chương trình nâng cấp dung lượng
                        # echo "Sau khi đã tạo partition xong, Create chương trình nâng cấp dung lượng"
                        create_physical_volume
                        extendVolumeGroup $nameOFdisk $partitionNumber
                        extendLogicalVolume $nameOFdisk $partitionNumber
                        break 3
                        elif [ "$choice_option" = 4 ]; then
                        create_physical_volume
                        extendSwapDisk
                        break 3
                    else
                        # Create partition + VG + LV mới + Mount
                        # echo " Create partition + VG + LV mới + Mount"
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
                    echo "NEW LSBLK LIST, PLEASE CHECK AGAIN: "
                    echo " "
                    lsblk
                    echo "----------- DONE -----------  "
                    echo_dongke
                    # Nhập thông tin để tạo physical volume
                    if [ "$choice_option" = 2 ]; then
                        # Sau khi đã tạo partition xong, Create chương trình nâng cấp dung lượng
                        # echo "Sau khi đã tạo partition xong, Create chương trình nâng cấp dung lượng"
                        create_physical_volume
                        extendVolumeGroup $nameOFdisk $partitionNumber
                        extendLogicalVolume $nameOFdisk $partitionNumber
                        break 3
                        elif [ "$choice_option" = 4 ]; then
                        create_physical_volume
                        extendSwapDisk
                        break 3
                    else
                        # Create partition + VG + LV mới + Mount
                        # echo " Create partition + VG + LV mới + Mount"
                        create_physical_volume
                        create_volume_group
                        echo_dongke
                        create_logical_volume
                        exit_va_clear
                    fi
                fi
                
            fi
        else
            echo "$(date +%Y/%m/%d-%H:%M)-[WARNING] Please enter the number !" >> /var/log/tool-script/tool-$(date +%Y%m%d).log
        fi
    done
}

# Đồng ý tạo ổ cứng
function accept_create() {
    read -p "Do you agree to create a new drive? (y/n): " choice
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
    read -p "Enter the drive name you want to create (nhap dang sdx) : " nameOFdisk
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
                echo "$(date +%Y/%m/%d-%H:%M)-[INFO]-Partitions can be created on this hard drive !" >> /var/log/tool-script/tool-$(date +%Y%m%d).log
                echo_dongke
                accept_create
            else
                disk_space_sector_default="${size_free_space[0]}"
                disk_space_sector="${size_free_space[1]}"
                
                case $array_length in
                    1)
                        if [ "$disk_space_sector_default" -gt 5000 ]; then
                            echo_dongke
                            echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-Space is still available You can create a hard drive"  >> /var/log/tool-script/tool-$(date +%Y%m%d).log
                            echo_dongke
                            accept_create
                        else
                            echo_space
                            echo "$(date +%Y/%m/%d-%H:%M)-[ERROR]-OUT OF HARD DRIVE SPACE $nameOFdisk" >> /var/log/tool-script/tool-$(date +%Y%m%d).log
                            echo_space
                            exit
                        fi
                    ;;
                    
                    2 | *)
                        
                        if [ "$disk_space_sector" -gt 5000 ]; then
                            echo_dongke
                            echo "$(date +%Y/%m/%d-%H:%M)-[SUCCESS]-Space is still available You can create a hard drive" >> /var/log/tool-script/tool-$(date +%Y%m%d).log
                            echo_dongke
                            accept_create
                            
                        else
                            echo_space
                            echo "$(date +%Y/%m/%d-%H:%M)-[ERROR]-OUT OF HARD DRIVE SPACE $nameOFdisk" >> /var/log/tool-script/tool-$(date +%Y%m%d).log
                            echo_space
                            exit
                        fi
                    ;;
                    
                esac
            fi
            
        else
            # Không tồn tại
            echo "$(date +%Y/%m/%d-%H:%M)-[ERROR]-There is no hard drive $nameOFdisk" >> /var/log/tool-script/tool-$(date +%Y%m%d).log
        fi
    fi
    
}



######################## Menu script #########################
echo "---------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------"
echo "----                                                                         ----"
echo "----                                                                         ----"
echo "----                                  TOOL Ổ CỨNG                            ----"
echo "----                    For distribution Linux: Ubuntu/RHEL/CentOS           ----"
echo "----                                  **ver1.1**                             ----"
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
        read -p " Are you sure you want to proceed with creating a new hard drive ? (y/n) : " choice
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
        read -p " Are you sure you want to increase the volume of your hard drive? (y/n) : " choice
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
        cat /var/log/tool-script/tool-$(date +%Y%m%d).log
        # echo "$(date +%Y/%m/%d-%H:%M)-[ERROR] Chức năng đang trong giai đoạn phát triển" >> /var/log/tool-script/tool-$(date +%Y%m%d).log
    ;;
    4)
        clear
        echo_dongke_dai
        echo_space
        list_menu_swap
        echo_space
        echo_dongke_dai
        read -p "Vui long chon option [1-${#arrayMenuSwap[@]}] : " choice_option_swap
        
        
        case  $choice_option_swap in
            
            1)
                #   Using Swap file
                # echo $choice_option_swap
                while true; do
                    read -p "Nhap dung luong cho swapfile(ex: 1Gb nhap la 1024) :" capacity_swap
                    if is_number "$capacity_swap" || [ -z "$capacity_swap" ]; then
                        usingFileSwap $capacity_swap
                        
                    else
                        echo "Chỉ được nhập số thôi"
                    fi
                done
            ;;
            2)
                #   Using partition dissk
                echo $choice_option_swap
                clear
                lay_thong_tin_disk
                free -m
                tao_sdxY
            ;;
            3)
                exit
            ;;
        esac
    ;;
    *)
        exit_va_clear
    ;;
esac