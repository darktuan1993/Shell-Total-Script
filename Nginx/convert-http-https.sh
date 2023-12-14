# Đọc danh sách file trong thư mục cấu hình vhost => ok
# Lấy tên file bỏ đi đuôi .conf và đường dẫn => ok
# Kiểm tra điều kiện 443 đã cấu hình config hay chưa , nếu chưa notify và break => ok
# Thêm config add ssl cert vào bên trong khối server => ok
# Thêm dòng redirect => ok
# Thay thế tên phần listen port vào vào phần nội dung => ok

# Cần chuyển đổi 80 - 443
# Giữ nguyên config và add thêm cert wild card và khối server, thêm redirect cuối cùng

# Variable
ssl_config="

        ssl_certificate /etc/nginx/cert_vnpay_local/vnpay.local.pem;
        ssl_certificate_key /etc/nginx/cert_vnpay_local/vnpay.local.key;
        ssl_dhparam /etc/nginx/cert_vnpay_local/dhparam.pem;

"
    host_var="\$host"
    request_uri_var="\$request_uri"
    path_config="/etc/nginx/conf.d/*.conf"

# Thêm khối code server và add thêm config
function add_line_config {

    # Xác định vị trí dòng của directive server tokens
    # line_number_server_tokens=$(grep -n "server_tokens off;" "$1" | cut -d ":" -f 1)
    # Xác định vị trí của của dòng  location / {
    # line_number_location=$(grep -n "location / {" "$1" | cut -d ":" -f 1)

    line_numbers=()

    while IFS= read -r line_number; do
        line_numbers+=("$line_number")
    done < <(grep -n "location" "$1" | cut -d ":" -f 1)

    # echo $line_numbers---------$1

    insert_line=$((line_numbers - 1))
        # echo $line_numbers-----$insert_line---------$1
    awk -v line="$insert_line" -v config="$ssl_config" 'NR == line {print config} {print}' "$1" > "$1.tmp" && mv "$1.tmp" "$1"

redirect_config="

server {
    listen 80;
    server_name $filename;
    server_tokens off;
    if ($host_var = $filename) {
        return 301 https://$filename$request_uri_var;
    }
}

"
        echo -e "$redirect_config" >> "$file"  # Bật tắt config redirect ở đây
}

    # Update config
function update_config {
    read -p "nhập chữ cái đầu config : " choice_option
    echo $choice_option

    function change_from_path_config {
        filename="${file##*/}"  # Bỏ phần đường dẫn
        filename="${filename%.conf}"  # Bỏ phần đuôi .conf
        listen_directive=$(awk '/^server\s*{/,/^}/ {if ($1 == "listen") print $2}' "$file")
        # port_directive=$(awk '/^server\s*{/,/^}/ {if ($1 == "listen") print $1}' "$file")
        if grep -q "ssl_certificate" $file; then
            echo "$filename - CHECK SSLCONFIG => DA CONFIG TU TRC"
        else
            echo "CONFIG SLL NGINX $filename"
            sed -i "0,/$listen_directive/{s/$listen_directive/443 ssl;/}" "$file"

            add_line_config $file

        fi
    }

    if [ -z "$choice_option" ]; then
        path_total=/etc/nginx/vhosts_11_16/*local.conf
        for file in $path_total; do
            change_from_path_config
        done
    else
        path_total=/etc/nginx/vhosts_11_16/$choice_option*local.conf
        for file in $path_total; do
            change_from_path_config
        done
    fi

    echo "----------------------------------"
    echo "GENERATE CONFIG SSL COMPLETE !!!!"
    echo "----------------------------------"
    nginx -t
}
update_config

