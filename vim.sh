echo "
        set encoding=utf-8
        set termencoding=utf-8" >> /etc/vimrc
dnf upgrade -y libmodulemd
dnf install -y glibc-langpack-ru
