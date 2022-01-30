#!/bin/bash

## System updaten

apt update -y
apt upgrade -y

## Abfrage nach Port und Netzwerk

echo ""
until [[ $PORT =~ ^[0-9]+$ ]] && [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]; do
  read -rp "Welcher Port?: " -e -i 51820 PORT
done
until [[ $WIREGUARD != "" ]]; do
  read -rp "Welcher IP-Bereich für das Wireguard Netzwerk?: " -e -i 10.0.0.0 WIREGUARD
done
until [[ $HELIUMCLIENT != "" ]]; do
  read -rp "Wie ist die Helium Miner Wireguard Client IP?: " -e -i 10.0.0.2 HELIUMCLIENT
done

## Lösche ufw Firewall und flush iptables

systemctl stop ufw
systemctl disable ufw
apt remove -y ufw
iptables -F
iptables -X

## Installiere Tools und Wireguard

apt install -y net-tools
apt install -y tuned
apt install -y wireguard

## Konfiguriere Firewall

echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf
iptables -t nat -I POSTROUTING 1 -s $WIREGUARD/24 -o enp1s0 -j MASQUERADE
iptables -I INPUT -i wg0 -j ACCEPT
iptables -I FORWARD -i enp1s0 -o wg0 -j ACCEPT
iptables -I FORWARD -i wg0 -o enp1s0 -j ACCEPT
iptables -I INPUT -i enp1s0 -p udp --dport $PORT -j ACCEPT
iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1240
iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o enp1s0 -j MASQUERADE
iptables -A FORWARD -i enp1s0 -o wg0 -p tcp --syn --dport 44158 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -i enp1s0 -o wg0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -t nat -A PREROUTING -i enp1s0 -p tcp --dport 44158 -j DNAT --to-destination $HELIUMCLIENT
apt install -y iptables-persistent
netfilter-persistent save

## Öffne .config File

nano /etc/wireguard/wg0.conf

## Aktiviere Wireguard

systemctl enable wg-quick@wg0.service
systemctl start wg-quick@wg0.service

## Zeige Firewall-Regeln und Wireguard Status
iptables -S
iptables -t nat -L
systemctl status wg-quick@wg0.service
