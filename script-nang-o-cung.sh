########### Variable List ###########
arrayMenu=("T?o ph�n disk m?i v� mount" "N�ng c?p dung l??ng" "Tho�t")
mapfile -t vg_names < <(vgdisplay | awk '/VG Name/ {print $3}')
capacityNumber=""

# Danh s�ch menu
function list_menu() {
    for ((i = 0; i < ${#arrayMenu[@]}; i++)); do
        echo "                                 $((i + 1)). ${arrayMenu[$i]}                          "
    done
}
# L?y th�ng tin disk
function lay_thong_tin_disk() {
    clear
    echo " "
    echo "============================ Check th�ng tin ph�n v�ng df -HT ==================================="
    df -hT
    echo " "
    echo "============================ Check th�ng tin ??a lsblk ============================"
    lsblk
}

# T?o Ph�n v�ng
function create_partition_disk() {
    nameDisk=$1
    capacityDisk=$2
    partitionNumber=$3

    echo "T�n disk: $nameDisk"
    echo "Dung l??ng: $capacityDisk"
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
        echo "T?O PARTITION TH�NH C�NG"
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

        echo "T?O PARTITION TH�NH C�NG"
    fi

}

# T?o volume group VG
function create_volume_group() {
    read -p "Nh?p t�n volume group mu?n t?o : " nameOfVolumeGroup
    # Check volume group
    # echo " Danh s�ch volume group:  ${vg_names[@]}  "
    for vg_name in "${vg_names[@]}"; do
        if [ "$vg_name" == "$nameOfVolumeGroup" ]; then
            found=true
            break
        fi
    done
    if [ "$found" == true ]; then
        echo "T�n $nameOfVolumeGroup ?� ???c s? d?ng r?i !"
    else
        echo "T�n $nameOfVolumeGroup c� th? s? d?ng"
        read -p "Nh?p t�n ph�n v�ng disk mu?n t?o (nh?p d?ng sdbx) : " partition_number
        vgcreate $nameOfVolumeGroup /dev/$partition_number
    fi
}

# ??ng � t?o ? c?ng
function accept_create() {
    read -p "B?n c� ??ng � t?o ? ??a m?i kh�ng? (y/n): " choice
    case $choice in
    [yY])
        while true; do
            read -p "Nh?p s? c?a ph�n v�ng $nameOFdisk (ch? c?n nh?p s?), n?u Enter ko nh?p g� th� m?c ??nh theo th? t? (v� d?: $nameOFdisk 1, $nameOFdisk 2,..): " partitionNumber

              if ls /dev | grep -q $nameOFdisk$partitionNumber && [ -n "$partitionNumber" ]; then
                echo "C� ? c?ng n�y r?i ng??i anh em ?i"
            else

                # Check s?
                function is_number() {
                    [[ $1 =~ ^[0-9]+$ ]]
                }

                while true; do
                    read -p "Nh?p dung l??ng theo GB: " capacityNumber

                    if is_number "$capacityNumber"; then
                        break
                    else
                        echo "Nh?p s? th�i ng??i anh em"
                    fi
                done

                if [ -n "$partitionNumber" ]; then
                    # ??y config theo s? ???c nh?p
                    create_partition_disk $nameOFdisk $capacityNumber $partitionNumber
                    echo " "
                    echo "Danh S�ch ph�n v�ng lsblk m?i"
                    echo " "
                    lsblk
                    # create_volume_group
                else
                    # ??y m?c ??nh s? th? t? d?ng sdb1 sdb2 sdb3
                    create_partition_disk $nameOFdisk $capacityNumber $partitionNumber
                    echo " "
                    echo "Danh S�ch ph�n v�ng lsblk m?i"
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
    read -p "Nh?p t�n ? ??a mu?n t?o (nh?p d?ng sdx) : " nameOFdisk
    # Ki?m tra k� t? nh?p
    if [ ${#nameOFdisk} -gt 3 ]; then
        echo "Nh?p sai t�n r?i ph�n, l�m g� c� ? n�o l� $nameOFdisk, t? tho�t sau 2s "
        sleep 2
        exit
    else
        if ls /dev | grep -q $nameOFdisk; then
            # N?u t?n t?i ? c?ng th� check ti?p dung l??ng
            mapfile -t size_free_space < <(parted /dev/$nameOFdisk unit s print free | awk '/Free Space/ {print $3}' | sed 's/s$//')

            array_length=${#size_free_space[@]}

            disk_space_sector_default="${size_free_space[0]}"
            disk_space_sector="${size_free_space[1]}"

            # echo "?? d�i m?ng size_free_space ${#size_free_space[@]}"
            case $array_length in
            1)
                if [ "$disk_space_sector_default" -gt 5000 ]; then
                    echo "Dung l??ng v?n c�n b?n c� th? t?o ? c?ng"
                    accept_create
                else
                    echo "H?t dung l??ng"
                    exit
                fi
                ;;

            2 | *)

                if [ "$disk_space_sector" -gt 5000 ]; then
                    echo "Dung l??ng v?n c�n b?n c� th? t?o ? c?ng"
                    accept_create

                else
                    echo "H?t dung l??ng"
                    exit
                fi
                ;;
            esac

        else
            # Kh�ng t?n t?i
            echo "Kh�ng c� ? c?ng n�o l� $nameOFdisk"
        fi
    fi

}

# Menu script
echo "---------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------"
echo "----                                N�NG C?P ? C?NG                          ----"
echo "----                     Distribution Linux: Ubuntu/RHEL/CentOS              ----"
echo "----                                  **ver0.1**                             ----"
echo "----                             *create by Daz9_Tu4n*                       ----"
list_menu
echo "---------------------------------------------------------------------------------"
echo "---------------------------------------------------------------------------------"

read -p "Vui l�ng ch?n option [1-${#arrayMenu[@]}]" choice
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
