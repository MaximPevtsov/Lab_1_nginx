#!/bin/bash

active_nodes_answers=""
active_nodes_answers=$(sudo nmap -sn 192.168.56.101-254)
sudo firewall-cmd --permanent --add-port=80/tcp                   #SELinux tcp :80 activated
sudo firewall-cmd --reload
mkdir /home/vagrant/Lab_1_nginx/ready_configs/
for word in $active_nodes_answers
do
        if [[ $word == 192.* ]]
        then
                 active_nodes_ip="$active_nodes_ip $word"
        fi
done
bastion_ip=$(hostname -I)
bastion_check=$(echo $bastion_ip | awk '{print $2}')
for ip in $active_nodes_ip
do
	if [[ $ip == $bastion_check ]]
	then
		jumpNode_ip=$ip
	else
		active_nodes_ip_without_jumpNode="$active_nodes_ip_without_jumpNode $ip"
	fi
done
echo "Адрес бастиона - " $jumpNode_ip
echo "Адреса обнаруженных нодов - " $active_nodes_ip_without_jumpNode
sudo dnf install sshpass -y
rm -f ~/.ssh/.id_rsa ~/.ssh/.id_rsa.pub
ssh-keygen -N "" -f ~/.ssh/.id_rsa -q
nodes_count=$(echo $active_nodes_ip_without_jumpNode | wc -w)
echo "Количество нодов - "$nodes_count
echo "upstream lab_1 {" > /home/vagrant/Lab_1_nginx/ready_configs/balancer.conf
for ip in $active_nodes_ip_without_jumpNode
do
	echo -e "\tserver $ip:8080 max_fails=2 fail_timeout=10s;" >> /home/vagrant/Lab_1_nginx/ready_configs/balancer.conf
done
echo -e "}\n" >> /home/vagrant/Lab_1_nginx/ready_configs/balancer.conf
echo "\
	server {
		listen     80 default_server;
		server_name _;
		
		location / {
			proxy_pass http://lab_1;

			   }
		}
" >> /home/vagrant/Lab_1_nginx/ready_configs/balancer.conf
sudo  mv /home/vagrant/Lab_1_nginx/ready_configs/balancer.conf /etc/nginx/conf.d/balancer.conf
sudo restorecon -v /etc/nginx/conf.d/balancer.conf
for ip in $active_nodes_ip_without_jumpNode          #Making ssh public key insert, nginx install, generate HTML page and send it  ---start---
do

	node_addr="vagrant@$ip"
	sshpass -p "vagrant"\
	ssh-copy-id -i ~/.ssh/.id_rsa.pub -o\
	StrictHostKeyChecking=no\
	$node_addr
	node_name=$(ssh $node_addr "hostname")
	echo "nginx installing on "$node_name ", wait please..."
	ssh $node_addr "sudo dnf install nginx -y"
	sleep 5
	ssh $node_addr "sudo systemctl enable nginx"
	ssh $node_addr "sudo firewall-cmd --permanent --add-port=8080/tcp"		#SELinux setting
	ssh $node_addr "sudo firewall-cmd --reload"					#SELinux setting
	echo "<!DOCTYPE html>
		<html>
		<head>
		<title>Welcome to $node_name!</title>
		<style>
		    body {
		        width: 35em;
		        margin: 0 auto;
		        font-family: Tahoma, Verdana, Arial, sans-serif;
		    }
		</style>
		</head>
		<body>
		<h1>Active user and IP address - $node_addr</h1>
		<p>If you see this page, the nginx web server is successfully installed and
		working. Further configuration is required.</p>
	" > /home/vagrant/Lab_1_nginx/ready_configs/${node_name}_default.html			# ---end---

							# ---start--- Making node config
	ssh $node_addr "sudo mkdir /usr/share/nginx/html/lab_1"
	ssh $node_addr "sudo chown vagrant:vagrant  /usr/share/nginx/html/lab_1"
	echo "server {
		listen     8080;
		server_name _;
		allow $jumpNode_ip;
		deny all;
		
		location / {
			root /usr/share/nginx/html/lab_1;
			index ${node_name}_default.html;
		}
	}
" > /home/vagrant/Lab_1_nginx/ready_configs/${node_name}_host.conf
	scp /home/vagrant/Lab_1_nginx/ready_configs/${node_name}_default.html $node_addr:/usr/share/nginx/html/lab_1
	ssh $node_addr "sudo restorecon -Rv /usr/share/nginx/html/lab_1/"		#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	scp /home/vagrant/Lab_1_nginx/ready_configs/${node_name}_host.conf $node_addr:/tmp/
	ssh $node_addr "sudo mv /tmp/${node_name}_host.conf /etc/nginx/conf.d/"
	ssh $node_addr "sudo restorecon -v /etc/nginx/conf.d/${node_name}_host.conf"	#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	ssh $node_addr "sudo chmod a+x /etc/nginx/conf.d/${node_name}_host.conf"
	ssh $node_addr "sudo systemctl restart nginx"

done							# ---end---
sudo setsebool -P httpd_can_network_connect on  					#SELinux setting
sudo systemctl restart nginx
echo "Testing nodes work from jumpNode, wait..."
sleep 5
for i in $active_nodes_ip_without_jumpNode
do
	curl $bastion_check:80
	if [[ $? == 0 ]]
	then
		echo "ping of "$i" success!"
	else
		echo "Something went wrong!"
	fi

done
echo "end of script!"
