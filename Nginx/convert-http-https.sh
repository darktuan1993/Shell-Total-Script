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
    ssl_certificate /etc/nginx/vhosts/cert/test.cer;
    ssl_certificate_key /etc/nginx/vhosts/cert/test.key;
    ssl_dhparam /etc/nginx/vhosts/cert/test.pem;
    ssl_trusted_certificate /etc/nginx/vhosts/cert/test.pem;
"
    host_var="\$host"
    request_uri_var="\$request_uri"
    path_config="/etc/nginx/conf.d/*.conf"

# Thêm khối code server và add thêm config 
function add_line_config {

    # Xác định vị trí dòng của directive server tokens
    line_number_server_tokens=$(grep -n "server_tokens off;" "$1" | cut -d ":" -f 1)
    # Xác định vị trí của của dòng  location / {
    line_number_location=$(grep -n "location / {" "$1" | cut -d ":" -f 1)

    if [ -n "$line_number_server_tokens" ]; then
        # Tăng số dòng lên 1 để xác định vị trí thêm cấu hình mới và Thêm cấu hình SSL vào vị trí ngay sau dòng server_tokens off;
        insert_line=$((line_number_server_tokens + 1))
        echo "Add con fix vao truoc dong location / trong $1"
        awk -v line="$insert_line" -v config="$ssl_config" 'NR == line {print config} {print}' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
    else
        # Giảm số dòng lên 1 để xác định vị trí thêm cấu hình mới và Thêm cấu hình SSL vào vị trí ngay sau dòng location /;
        echo "Add con fix vao truoc dong location / trong $1"
        insert_line=$((line_number_location - 1))
        awk -v line="$insert_line" -v config="$ssl_config" 'NR == line {print config} {print}' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
    fi

    # Thêm khối redirect vào dưới file server
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
        for file in /etc/nginx/conf.d/*.conf
        do
            filename="${file##*/}"  # Bỏ phần đường dẫn
            filename="${filename%.conf}"  # Bỏ phần đuôi .conf
            listen_directive=$(awk '/^server\s*{/,/^}/ {if ($1 == "listen") print $2}' "$file")

            # Kiểm tra xem "443" có xuất hiện trong chuỗi "listen_directive" hay không
            if [[ $listen_directive == "443" ]]; then
                echo "Da cau hinh SSL"
                # Nếu gặp 443 sẽ ngắt luôn không cấu hình nữa
                break;  
                exit;
            else
                echo "File config chua cau hinh SSL "
                # Sửa listen thành 443 và sll 
                sed -i "s/$listen_directive/443 ssl/g" "$file"
                add_line_config $file
                # cat $file

            fi
        done

}
update_config


