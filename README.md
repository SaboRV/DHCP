# Цель домашнего задания
Отработать навыки установки и настройки DHCP, TFTP, PXE загрузчика и автоматической загрузки

## Описание домашнего задания

1. Следуя шагам из документа https://docs.centos.org/en-US/8-docs/advanced-install/assembly_preparing-for-a-network-install  установить и настроить загрузку по сети для дистрибутива CentOS 8.
В качестве шаблона воспользуйтесь репозиторием https://github.com/nixuser/virtlab/tree/main/centos_pxe 
2. Поменять установку из репозитория NFS на установку из репозитория HTTP.
3. Настроить автоматическую установку для созданного kickstart файла (*) Файл загружается по HTTP.


# Введение
Бывают ситуации, когда ИТ-специалисту потребуется переустановить ОС на большом количестве хостов. Переустановка вручную потребует от специалиста большого количества времени. В этот момент стоит обратить внимание на PXE.
PXE (Preboot eXecution Environment) — это набор протоколов, которые позволяют загрузить хост из сети. Для загрузки будет использоваться сетевая карта хоста.
Для PXE требуется:
Со стороны клиента (хоста на котором будем устанавливать или загружать ОС):
Cетевая карта, которая поддерживает стандарт PXE
Со стороны сервера:
DHCP-сервер
TFTP-сервер

TFTP (Trivial File Transfer Protocol) — простой протокол передачи файлов, используется главным образом для первоначальной загрузки бездисковых рабочих станций. Основная задача протокола TFTP — отправка указанных файлов клиенту.
TFTP работает на 69 UDP порту. TFTP — очень простой протокол, у него нет аутентификации, возможности удаления файлов и т д. Протокол может только отправлять запросы на чтение и запись…

DHCP (Dynamic Host Configuration Protocol) — протокол динамической настройки узла, позволяет сетевым устройствам автоматически получать IP-адрес и другие параметры, необходимые для работы в сети TCP/IP. 
Протокол DHCP пришёл на смену протоколу BOOTP. DHCP сохраняет обратную совместимость с BOOTP. Основное отличие протоколов заключается в том, что протокол DHCP помимо IP-адреса может отправлять клиенту дополнительные опции (маску подсети, адреса DNS-серверов, имя домена, адрес TFTP-сервера). 

Протокол DHCP использует следующие порты:
UDP 67 на сервере
UDP 68 на клиенте

Также DHCP позволяет DHCP-клиенту отправить ответом опции для DHCP-сервера.

Через DHCP мы можем передать клиенту адрес PXE-сервера и имя файла, к которому мы будем обращаться.

# РЕШЕНИЕ

# 1. Работа с шаблоном из задания

Скачиваем файлы, указанные в домашнем задании. Рассмотрим загруженный Vagrantfile:

# -*- mode: ruby -*-
# vi: set ft=ruby :
# export VAGRANT_EXPERIMENTAL="disks"

Vagrant.configure("2") do |config|

config.vm.define "pxeserver" do |server|
  server.vm.box = 'centos/8.4'
  server.vm.disk :disk, size: "15GB", name: "extra_storage1"

  server.vm.host_name = 'pxeserver'
  server.vm.network :private_network, 
                     ip: "10.0.0.20", 
                     virtualbox__intnet: 'pxenet'

  # server.vm.network "forwarded_port", guest: 80, host: 8081

  server.vm.provider "virtualbox" do |vb|
    vb.memory = "1024"
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  end

  # ENABLE to setup PXE
  server.vm.provision "shell",
    name: "Setup PXE server",
    path: "setup_pxe.sh"
  end


# config used from this
# https://github.com/eoli3n/vagrant-pxe/blob/master/client/Vagrantfile
  config.vm.define "pxeclient" do |pxeclient|
    pxeclient.vm.box = 'centos/8.4'
    pxeclient.vm.host_name = 'pxeclient'
    pxeclient.vm.network :private_network, ip: "10.0.0.21"
    pxeclient.vm.provider :virtualbox do |vb|
      vb.memory = "2048"
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      vb.customize [
          'modifyvm', :id,
          '--nic1', 'intnet',
          '--intnet1', 'pxenet',
          '--nic2', 'nat',
          '--boot1', 'net',
          '--boot2', 'none',
          '--boot3', 'none',
          '--boot4', 'none'
        ]
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end
      # ENABLE to fix memory issues
#     end
  end

end

Жирным шрифтом отмечены строки, в которых требуется внести изменения. Давайте рассмотрим их более подробно:

Pxeclient.vm.box = 'centos/8.4' и server.vm.box = 'centos/8.4' — на данный момент в Vagrant Box нет образа с таким именем. Нам требуется образ CentOS 8.4, мы можем воспользоваться образом bento/centos-8.4. Плюсом этого Vagrant Box является то, что по умолчанию он создаёт ОС с размером диска 60ГБ. При использовании данного образа нам не придётся полдключать дополнительный диск.

# export VAGRANT_EXPERIMENTAL="disks" и server.vm.disk :disk, size: "15GB", name: "extra_storage1" — так как нам хватает свободного места, мы можем не подключать дополнитеный диск. Если вы планируете в своём домашнем задании подключить дополнительный диск, то команда export VAGRANT_EXPERIMENTAL="disks" должна быть введена в терминале. 

# server.vm.network "forwarded_port", guest: 80, host: 8081 — опция проброса порта. В нашем ДЗ её рекомендуется расскомментировать. Также для удобства можно поменять порт 8081 на любой удобный Вам.

# ENABLE to setup PXE — блок настройки PXE-сервера с помощью bash-скрипта. Так как мы будем использовать Ansible для настройки хоста, данный блок нам не понадобится. Его можно удалить. Далее можно будет добавить блок настройки хоста с помощью Ansible…

Для настройки хоста через Ansible, нам потребуется добавить дополнтельный сетевой интефейс для Pxeserver. Пример добавления сетевого интефейса, с адресом 192.168.50.10: 
server.vm.network :private_network, ip: "192.168.50.10", adapter: 3

После внесения всех изменений запускаем наш стенд с помощью команды vagrant up

Выполнение команды закончится с ошибкой, так как на Pxeclient настроена загрузка по сети.

Теперь мы можем приступить к настройке Pxe-сервера. 


# Настройка Web-сервера

### 0. Так как у CentOS 8 закончилась поддержка, для установки пакетов нам потребуется поменять репозиторий. Сделать это можно с помощью следующих команд:


sed -i 's|baseurl=http://vault.centos.org|baseurl=http://vault.epel.cloud|g' /etc/yum.repos.d/CentOS-Linux-*
sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Linux-*
sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-Linux-*
Обновляем систему: yum update


Добавим в /etc/vimrc следующие строки для правильного отображения кирилицы в vim:
        set encoding=utf-8
        set termencoding=utf-8

### 1. Устанавливаем Web-сервер Apache: yum install httpd

sudo systemctl enable httpd.service
sudo systemctl start httpd.service
[root@pxeserver ~]# sudo systemctl status httpd.service
● httpd.service - The Apache HTTP Server
   Loaded: loaded (/usr/lib/systemd/system/httpd.service; enabled; vendor preset: disabled)
   Active: active (running) since Sun 2024-02-25 06:37:40 UTC; 2h 3min ago
     Docs: man:httpd.service(8)
 Main PID: 1021 (httpd)
   Status: "Total requests: 1142; Idle/Busy workers 100/0;Requests/sec: 0.154; Bytes served/sec: 853KB/sec"
    Tasks: 278 (limit: 4955)
   Memory: 468.1M
   CGroup: /system.slice/httpd.service
           ├─1021 /usr/sbin/httpd -DFOREGROUND
           ├─1158 /usr/sbin/httpd -DFOREGROUND
           ├─1159 /usr/sbin/httpd -DFOREGROUND
           ├─1160 /usr/sbin/httpd -DFOREGROUND
           ├─1161 /usr/sbin/httpd -DFOREGROUND
           └─2209 /usr/sbin/httpd -DFOREGROUND

Feb 25 06:37:40 pxeserver systemd[1]: Starting The Apache HTTP Server...
Feb 25 06:37:40 pxeserver httpd[1021]: AH00558: httpd: Could not reliably determine the server's fully qualified domain name, usi>
Feb 25 06:37:40 pxeserver systemd[1]: Started The Apache HTTP Server.
Feb 25 06:37:40 pxeserver httpd[1021]: Server configured, listening on: port 80


2. Далее скачиваем образ CentOS 8.4.2150:
wget https://mirror.cs.pitt.edu/centos-vault/8.4.2105/isos/x86_64/CentOS-8.4.2105-x86_64-dvd1.iso
Размер образа больше 9ГБ, скачивание может занять продолжительное время.

3. Монтируем данный образ:
mount -t iso9660 CentOS-8.4.2105-x86_64-dvd1.iso /mnt -o loop,ro

4. Создаём каталог /iso и копируем в него содержимое данного каталога:
mkdir /iso
cp -r /mnt/* /iso
5. Ставим права 755 на каталог /iso: chmod -R 755 /iso
6. Настраиваем доступ по HTTP для файлов из каталога /iso:
Создаем конфигурационный файл: vi /etc/httpd/conf.d/pxeboot.conf
Добавляем следующее содержимое в файл:
Alias /centos8 /iso
### Указываем адрес директории /iso
<Directory /iso>
    Options Indexes FollowSymLinks
    #Разрешаем подключения со всех ip-адресов
    Require all granted
Перезапускаем веб-сервер: systemctl restart httpd
Добавляем его в автозагрузку: systemctl enable httpd

7. Проверяем, что веб-сервер работает и каталог /iso доступен по сети:
- С компьютера сначала подключаемся к тестовой странице Apache: 
см. Pic_1

- Далее проверям доступность файлов по сети:
см. Pic_2

На этом настройка веб-сервера завершена.

### Настройка TFTP-сервера
TFTP-сервер потребуется для отправки первичных файлов загрузки (vmlinuz, initrd.img и т. д.)

1. Устанавливаем tftp-сервер: yum install tftp-server
2. Запускаем службу: systemctl start tftp.service
3. Проверяем, в каком каталоге будут храниться файлы, которые будет отдавать TFTP-сервер:
[root@pxeserver ~]# systemctl status tftp.service
● tftp.service - Tftp Server
   Loaded: loaded (/usr/lib/systemd/system/tftp.service; indirect; vendor prese>
   Active: active (running) since Sat 2024-02-24 17:58:43 UTC; 8s ago
     Docs: man:in.tftpd
 Main PID: 41479 (in.tftpd)
    Tasks: 1 (limit: 4953)
   Memory: 192.0K
   CGroup: /system.slice/tftp.service
           └─41479 /usr/sbin/in.tftpd -s /var/lib/tftpboot

Feb 24 17:58:43 pxeserver systemd[1]: Started Tftp Server.


В статусе видим, что рабочий каталог /var/lib/tftpboot
4. Созаём каталог, в котором будем хранить наше меню загрузки:
mkdir /var/lib/tftpboot/pxelinux.cfg
5. Создаём меню-файл: vi /var/lib/tftpboot/pxelinux.cfg/default


default menu.c32
prompt 0
#Время счётчика с обратным отсчётом (установлено 15 секунд)
timeout 150
#Параметр использования локального времени
ONTIME local
#Имя «шапки» нашего меню
menu title OTUS PXE Boot Menu
       #Описание первой строки
       label 1
       #Имя, отображаемое в первой строке
       menu label ^ Graph install CentOS 8.4
       #Адрес ядра, расположенного на TFTP-сервере
       kernel /vmlinuz
       #Адрес файла initrd, расположенного на TFTP-сервере
       initrd /initrd.img
       #Получаем адрес по DHCP и указываем адрес веб-сервера
       append ip=enp0s3:dhcp inst.repo=http://10.0.0.20/centos8
       label 2
       menu label ^ Text install CentOS 8.4
       kernel /vmlinuz
       initrd /initrd.img
       append ip=enp0s3:dhcp inst.repo=http://10.0.0.20/centos8 text
       label 3
       menu label ^ rescue installed system
       kernel /vmlinuz
       initrd /initrd.img
       append ip=enp0s3:dhcp inst.repo=http://10.0.0.20/centos8 rescue


Label 1-3 различаются только дополнительными параметрами:
label 1 — установка вручную в графическом режиме
label 2 — установка вручную в текстовом режиме
label 3 — восстановление системы

6. Распакуем файл syslinux-tftpboot-6.04-5.el8.noarch.rpm:
rpm2cpio /iso/BaseOS/Packages/syslinux-tftpboot-6.04-5.el8.noarch.rpm | cpio -dimv

7. После распаковки в каталоге пользователя root будет создан каталог tftpboot из которого потребуется скопировать следующие файлы:
- pxelinux.0
- ldlinux.c32
- libmenu.c32
- libutil.c32
- menu.c32
- vesamenu.c32
cd tftpboot
cp pxelinux.0 ldlinux.c32 libmenu.c32 libutil.c32 menu.c32 vesamenu.c32 /var/lib/tftpboot/

8. Также в каталог /var/lib/tftpboot/ нам потребуется скопировать файлы initrd.img и vmlinuz, которые располагаются в каталоге /iso/images/pxeboot/:
cp /iso/images/pxeboot/{initrd.img,vmlinuz} /var/lib/tftpboot/

9. Далее перезапускаем TFTP-сервер и добавляем его в автозагрузку:
systemctl restart tftp.service 
systemctl enable tftp.service
[root@pxeserver tftpboot]# systemctl status tftp.service 
● tftp.service - Tftp Server
   Loaded: loaded (/usr/lib/systemd/system/tftp.service; indirect; vendor prese>
   Active: active (running) since Sat 2024-02-24 18:03:31 UTC; 10s ago
     Docs: man:in.tftpd
 Main PID: 41505 (in.tftpd)
    Tasks: 1 (limit: 4953)
   Memory: 180.0K
   CGroup: /system.slice/tftp.service
           └─41505 /usr/sbin/in.tftpd -s /var/lib/tftpboot


### Настройка DHCP-сервера

1. Устанавливаем DHCP-сервер: yum install dhcp-server
2. Правим конфигурационный файл: vi /etc/dhcp/dhcpd.conf


option space pxelinux;
option pxelinux.magic code 208 = string;
option pxelinux.configfile code 209 = text;
option pxelinux.pathprefix code 210 = text;
option pxelinux.reboottime code 211 = unsigned integer 32;
option architecture-type code 93 = unsigned integer 16;

#Указываем сеть и маску подсети, в которой будет работать DHCP-сервер
subnet 10.0.0.0 netmask 255.255.255.0 {
        #Указываем шлюз по умолчанию, если потребуется
        #option routers 10.0.0.1;
        #Указываем диапазон адресов
        range 10.0.0.100 10.0.0.120;

        class "pxeclients" {
          match if substring (option vendor-class-identifier, 0, 9) = "PXEClient";
          #Указываем адрес TFTP-сервера
          next-server 10.0.0.20;
          #Указываем имя файла, который надо запустить с TFTP-сервера
          filename "pxelinux.0";
        }


systemctl start dhcpd
systemctl enable dhcpd
systemctl status dhcpd

[root@pxeserver ~]# systemctl status dhcpd
● dhcpd.service - DHCPv4 Server Daemon
   Loaded: loaded (/usr/lib/systemd/system/dhcpd.service; enabled; vendor preset: disabled)
   Active: active (running) since Sun 2024-02-25 07:01:36 UTC; 3min 12s ago
     Docs: man:dhcpd(8)
           man:dhcpd.conf(5)
 Main PID: 2052 (dhcpd)
   Status: "Dispatching packets..."
    Tasks: 1 (limit: 4955)
   Memory: 4.8M
   CGroup: /system.slice/dhcpd.service
           └─2052 /usr/sbin/dhcpd -f -cf /etc/dhcp/dhcpd.conf -user dhcpd -group dhcpd --no-pid

Feb 25 07:01:36 pxeserver dhcpd[2052]: 
Feb 25 07:01:36 pxeserver dhcpd[2052]: No subnet declaration for eth0 (10.0.2.15).
Feb 25 07:01:36 pxeserver dhcpd[2052]: ** Ignoring requests on eth0.  If this is not what
Feb 25 07:01:36 pxeserver dhcpd[2052]:    you want, please write a subnet declaration
Feb 25 07:01:36 pxeserver dhcpd[2052]:    in your dhcpd.conf file for the network segment
Feb 25 07:01:36 pxeserver dhcpd[2052]:    to which interface eth0 is attached. **
Feb 25 07:01:36 pxeserver dhcpd[2052]: 
Feb 25 07:01:36 pxeserver dhcpd[2052]: Sending on   Socket/fallback/fallback-net
Feb 25 07:01:36 pxeserver dhcpd[2052]: Server starting service.
Feb 25 07:01:36 pxeserver systemd[1]: Started DHCPv4 Server Daemon.


На данном этапе мы закончили настройку PXE-сервера для ручной установки сервера. Давайте попробуем запустить процесс установки вручную, для удобства воспользуемся установкой через графический интерфейс:

В настройках виртуальной машины pxeclient рекомендуется поменять графический контроллер на VMSVGA и добавить видеопамяти. Видеопамять должна стать 20 МБ или больше. 

Проверяем загрузку системы pxeclient. Все работает.

# Необходимо настроить автоматическую установку.

### Настройка автоматической установки с помощью Kickstart-файла

1. Создаем kickstart-файл и кладём его в каталог к веб-серверу: vi /iso/ks.cfg


#version=RHEL8
#Использование в установке только диска /dev/sda
ignoredisk --only-use=sda
autopart --type=lvm
#Очистка информации о партициях
clearpart --all --initlabel --drives=sda
#Использование графической установки
graphical
#Установка английской раскладки клавиатуры
keyboard --vckeymap=us --xlayouts='us'
#Установка языка системы
lang en_US.UTF-8
#Добавление репозитория
url --url=http://10.0.0.20/centos8/BaseOS/
#Сетевые настройки
network  --bootproto=dhcp --device=enp0s3 --ipv6=auto --activate
network  --bootproto=dhcp --device=enp0s8 --onboot=off --ipv6=auto --activate
network  --hostname=otus-pxe-client
#Устанвка пароля root-пользователю (Указан SHA-512 hash пароля 123)
rootpw --iscrypted $6$sJgo6Hg5zXBwkkI8$btrEoWAb5FxKhajagWR49XM4EAOfO/Dr5bMrLOkGe3KkMYdsh7T3MU5mYwY2TIMJpVKckAwnZFs2ltUJ1abOZ.
firstboot --enable
#Не настраиваем X Window System
skipx
#Настраиваем системные службы
services --enabled="chronyd"
#Указываем часовой пояс
timezone Europe/Moscow --isUtc
user --groups=wheel --name=val --password=$6$ihX1bMEoO3TxaCiL$OBDSCuY.EpqPmkFmMPVvI3JZlCVRfC4Nw6oUoPG0RGuq2g5BjQBKNboPjM44.0lJGBc7OdWlL17B3qzgHX2v// --iscrypted --gecos="val"

%packages
@^minimal-environment
kexec-tools

%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end

%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end



2. Добавляем параметр в меню загрузки:
vi /var/lib/tftpboot/pxelinux.cfg/default 


default menu.c32
prompt 0
timeout 150
ONTIME local
menu title OTUS PXE Boot Menu
       label 1
       menu label ^ Graph install CentOS 8.4
       kernel /vmlinuz
       initrd /initrd.img
       append ip=enp0s3:dhcp inst.repo=http://10.0.0.20/centos8
       label 2
       menu label ^ Text install CentOS 8.4
       kernel /vmlinuz
       initrd /initrd.img
       append ip=enp0s3:dhcp inst.repo=http://10.0.0.20/centos8 text
       label 3
       menu label ^ rescue installed system
       kernel /vmlinuz
       initrd /initrd.img
       append ip=enp0s3:dhcp inst.repo=http://10.0.0.20/centos8 rescue
       label 4
       menu label ^ Auto-install CentOS 8.4
       #Загрузка данного варианта по умолчанию
       menu default
       kernel /vmlinuz
       initrd /initrd.img
       append ip=enp0s3:dhcp inst.ks=http://10.0.0.20/centos8/ks.cfg inst.repo=http://10.0.0.20/centos8/


В append появляется дополнительный параметр inst.ks, в котором указан адрес kickstart-файла. 

см. Pic_3


После внесения данных изменений, можем перезапустить нашу ВМ pxeclient и проверить, что запустится процесс автоматической установки ОС.

см. Pic_4

После установки системы необходимо выключить виртуальную машину и поменять в свойствах системы в Oracle VM загрузку системы с диска. Далее запускаем виртуальную маштину. Система запустилась.
см. Pic_5

# Установка с помощью Ansible
1. Запускаем Vagrand up.
2. Запускаем ansible-playbook playbook.yml.
3. Перезагружаем виртуальную машину pxeclient.После установки системы выключаем.
   Меняем загрузку виртуальной машины pxeclient с сети на жесткий диск. Запускаем pxeclient.


















