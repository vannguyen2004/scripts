#!/bin/bash


function check_OS {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        distro=$ID
        echo "Hệ điều hành hiện tại là: $PRETTY_NAME"
        install_growpart $distro
        
    else
        echo "Không xác định được OS nhấn Enter để thoát"
        read 
        exit 1
    fi
}

function install_growpart {
    distro=$1
    if command -v growpart >/dev/null 2>&1; then
        echo "✅ growpart đã được cài đặt trên hệ thống."
    else 
        if [[ "$distro" == "ubuntu" || "$distro" == "debian" ]]; then
            echo "📦 Đang cài đặt cloud-guest-utils (Ubuntu/Debian)..."
            sudo apt update -y &> /dev/null
            sudo apt install cloud-guest-utils -y &> /dev/null
        elif [[ "$distro" == "centos" || "$distro" == "almalinux" || "$distro" == "fedora" ]]; then
            echo echo "📦 Đang cài đặt cloud-utils-growpart (CentOS/AlmaLinux/Fedora)..."
            sudo dnf install cloud-utils-growpart -y &> /dev/null
        else
            echo "⚠️ Hệ điều hành $distro hiện chưa được hỗ trợ trong script này."
            exit 1
        fi 
    fi 
    extend_disk
}

function extend_disk {
    PARTITION=$(pvs | grep  $(lvdisplay $(df -h / | grep / | awk '{print $1}') | grep "VG Name" | awk '{print $3}') | awk '{print $1}')
    EXTEND_SECTOR=$(echo "$PARTITION" | awk '{print $1}' | sed -E 's#([0-9])$# \1#')
    LV_PATH=$(df -h / | grep / | awk '{print $1}') 

if [ ! -b "$PARTITION" ]; then
    echo "❌ Lỗi: Phân vùng $PARTITION không tồn tại."
    echo "   Vui lòng kiểm tra lại bằng lệnh: lsblk"

    exit 1
fi

echo "👉 Đang mở rộng phân vùng $PARTITION..."
if [ ! -e $PARTITION ]; then
    echo "Không tìm thấy $PARTITION để mở rộng vui lòng kiểm tra lại"
    exit 1
fi
if ! sudo growpart --dry-run $EXTEND_SECTOR &> /dev/null ; then
    echo "Không thể mở rộng phân vùng $EXTEND_SECTOR được nữa"
else
   sudo growpart  $EXTEND_SECTOR > /dev/null
    if [ $? != 0 ]; then
        echo "Đã xãy ra lỗi vui lòng kiểm tra lại"
    else
        echo "Mở rộng phân vùng $PARTITION thành công"
    fi 
fi
echo "👉 Kiểm tra Physical Volume..."
if ! sudo pvs >/dev/null 2>&1; then
    echo "❌ Lỗi: không tìm thấy LVM Physical Volume. Hệ thống có thể không dùng LVM."
    exit 1
fi

echo "👉 Đang mở rộng Physical Volume trên $PARTITION..."
if ! sudo pvresize $PARTITION  &> /dev/null; then
    echo "❌ Lỗi khi chạy pvresize trên $PARTITION."
    exit 1
else
    echo "✅Mở rộng Physical Volume trên $PARTITION thành công"
fi

echo "👉 Kiểm tra LV PATH..."
if [ ! -e "$LV_PATH" ]; then
    echo "❌ Lỗi: Logical Volume $LV_PATH không tồn tại."
    echo "   Kiểm tra bằng lệnh: lvdisplay"
    exit 1
fi
echo "👉 Đang mở rộng Logical Volume $LV_PATH..."
if ! sudo lvextend -r -l +100%FREE "$LV_PATH" &> /dev/null; then
    echo "❌ Lỗi khi mở rộng Logical Volume $LV_PATH."
    exit 1
else
    echo "✅ Mở rộng Logical Volume thành công"
fi
echo "✅ Hoàn tất! Dung lượng mới:"
df -h /
}

main (){
    echo "-------Script extend disk sẽ bắt đầu trong 5 giây tiếp theo---------"
    sleep 5
    echo "👉 Dung lương đĩa trước khi nâng cấp"
    df -h /
    check_OS
}
main  "$@"
