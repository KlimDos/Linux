#!/bin/bash

# $1 название сети
# $2 порт
# $3 подсеть (например: 10.0.0)
# $4 tap интерфейс

# Проверяем сеть на существование
if [ -e /etc/openvpn/$1 ]; then
    echo "Сеть существует!!!"
    exit 0
else
    echo "Сеть не существует. Всё Ok. Продолжаем."
fi

net=${3%%.} #Удаляем точку в конце. Для не внимательных ) 

# Генерируем ключи
cp -r /etc/openvpn/new /etc/openvpn/$1/
cd /etc/openvpn/$1
for i in {002..254};
do
    echo  "ifconfig-push $net."`echo $i | sed 's/^[0^t]*//'`" 255.255.255.0" > ccd/$1-$i
done
cd easy-rsa
. ./vars
./clean-all
bash build-dh
bash build-ca
bash build-key-server $1
#Массово генерируем клиентские сертификаты:
for i in {002..254};
do
    ./build-key $1-$i
done
openvpn --genkey --secret ta.key
cp ta.key ../
cp keys/ca.crt ../
cp keys/ca.key ../
cp keys/dh*.pem ../
cp keys/$1.key ../
cp keys/$1.crt ../
cd ../../

mv $1/easy-rsa/keys/$1-*.key $1/key
mv $1/easy-rsa/keys/$1-*.crt $1/key

# Создаем конфиг linux сервера
echo "port $2"                                           > $1/$1-server.conf
echo "proto udp"                                        >> $1/$1-server.conf
echo "dev $4"                                           >> $1/$1-server.conf
echo "ca /etc/openvpn/$1/ca.crt"                        >> $1/$1-server.conf
echo "cert /etc/openvpn/$1/$1.crt"                      >> $1/$1-server.conf
echo "key /etc/openvpn/$1/$1.key"                       >> $1/$1-server.conf
echo "dh /etc/openvpn/$1/dh2048.pem"                    >> $1/$1-server.conf
echo "server $net.0 255.255.255.0"                      >> $1/$1-server.conf
echo "client-config-dir /etc/openvpn/$1/ccd"            >> $1/$1-server.conf
echo "tls-auth /etc/openvpn/$1/ta.key 0"                >> $1/$1-server.conf
echo "comp-lzo"                                         >> $1/$1-server.conf
echo "max-clients 253"                                  >> $1/$1-server.conf
echo "status /var/log/openvpn/$1-status.log"            >> $1/$1-server.conf
echo "log /var/log/openvpn/$1-vpn.log"                  >> $1/$1-server.conf
echo "log-append /var/log/openvpn/$1-vpn.log"           >> $1/$1-server.conf
echo "script-security 2"                                >> $1/$1-server.conf
# Уровень отладочной информации verb                    >> $1/$1-server.conf
echo "verb 2"                                           >> $1/$1-server.conf
echo "multihome"                                        >> $1/$1-server.conf
# Разрешаем обмен пакетами между клиентами              >> $1/$1-server.conf
echo "client-to-client"                                 >> $1/$1-server.conf
echo "keepalive 10 60"                                  >> $1/$1-server.conf

# Создаем конфиг windows сервера
echo "port $2"                                                                             > $1/$1-server.ovpn
echo "proto udp"                                                                          >> $1/$1-server.ovpn
echo "dev $4"                                                                             >> $1/$1-server.ovpn
echo "ca \"$1\\\\ca.crt\""                                                                >> $1/$1-server.ovpn
echo "cert \"$1\\\\$1.crt\""                                                              >> $1/$1-server.ovpn
echo "key \"$1\\\\$1.key\""                                                               >> $1/$1-server.ovpn
echo "dh \"$1\\\\dh2048.pem\""                                                            >> $1/$1-server.ovpn
echo "server $net.0 255.255.255.0"                                                        >> $1/$1-server.ovpn
echo "client-config-dir \"$1\\\\ccd\""                                                    >> $1/$1-server.ovpn
echo "tls-auth \"C:\\\\Program\ Files\\\\OpenVPN\\\\config\\\\$1\\\\ta.key\" 0"           >> $1/$1-server.ovpn
echo "comp-lzo"                                                                           >> $1/$1-server.ovpn
echo "max-clients 253"                                                                    >> $1/$1-server.ovpn
echo "status \"C:\\\\Program\ Files\\\\OpenVPN\\\\log\\\\$1-status.log\""                 >> $1/$1-server.ovpn
echo "log \"C:\\\\Program\ Files\\\\OpenVPN\\\\log\\\\$1-vpn.log\""                       >> $1/$1-server.ovpn
echo "script-security 2"                                                                  >> $1/$1-server.ovpn
# Уровень отладочной информации verb                                                      >> $1/$1-server.ovpn
echo "verb 2"                                                                             >> $1/$1-server.ovpn
# Разрешаем обмен пакетами между клиентами                                                >> $1/$1-server.ovpn
echo "client-to-client"                                                                   >> $1/$1-server.ovpn
echo "keepalive 10 60 "                                                                   >> $1/$1-server.ovpn

# Конвертируем переносы строк в Win стиль
unix2dos $1/$1-server.ovpn

# Настраиваем логирование
touch /var/log/openvpn/$1-vpn.log
touch /var/log/openvpn/$1-status.log
chown root:adm /var/log/openvpn/$1-*
chmod 640 /var/log/openvpn/$1-*

# Создаем конфиг linux клиента
echo "client"                                           >> $1/$1-client.conf
echo "dev tap"                                          >> $1/$1-client.conf
echo "proto udp"                                        >> $1/$1-client.conf
echo "remote  $2"                                       >> $1/$1-client.conf
echo "resolv-retry infinite"                            >> $1/$1-client.conf
echo "nobind"                                           >> $1/$1-client.conf
echo "persist-key"                                      >> $1/$1-client.conf
echo "persist-tun"                                      >> $1/$1-client.conf
echo "ca $1/ca.crt"                                     >> $1/$1-client.conf
echo "cert $1/$1-000.crt"                               >> $1/$1-client.conf
echo "key $1/$1-000.key"                                >> $1/$1-client.conf
# Проверяем сертификат, предъявленный сервером.         >> $1/$1-client.conf
echo "ns-cert-type server"                              >> $1/$1-client.conf
echo "tls-auth $1/ta.key 1"                             >> $1/$1-client.conf
echo "comp-lzo"                                         >> $1/$1-client.conf
# отправку ping-подобных сообщений для того, чтобы каждая сторона знала что другая перестала отвечать
# Пинг каждые 5 секунд, если в течение 20 секунд нет ответа, то считается что удаленных хост не доступен
echo "keepalive 4 16"                                   >> $1/$1-client.conf
echo "verb 3"                                           >> $1/$1-client.conf
echo "route-method exe"                                 >> $1/$1-client.conf
echo "route-delay 5"                                    >> $1/$1-client.conf

# Создаем конфиг windows клиента
unix2dos -n $1/$1-client.conf $1/$1-client.ovpn
