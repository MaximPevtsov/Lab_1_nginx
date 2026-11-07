#!/bin/bash

		#------Подключаем файл с данными о нодах из vagrant
		#------Файл содержит ALL_NODES, NODE_NAME, NODE_IP, SUBNET, NODE_COUNT

source /etc/vagrant-info.env

		#------Включаем порт :80, потому что по дефолту он выключен в RHEL подобных дистрибутивах

#sudo firewall-cmd --permanent --add-port=80/tcp                   #SELinux tcp :80 activated
#sudo firewall-cmd --reload

#mkdir /home/vagrant/Lab_1_nginx/ready_configs/

		#------Формируем графику приветствия

echo " ----------------------------------------------------------------- "
echo "|            WELCOME TO NGINX CLUSTER AUTOSTART!                  |"
echo "|       This programm will deploy private subnet + jump node      |"
echo "|    Use README in https://github.com/MaximPevtsov/Lab_1_nginx    |"
echo "|                   Have a fun, comrade!                          |"
echo " ----------------------------------------------------------------- "
echo " "
sleep 2
echo " "
echo "////      The following VMs were detected     ////"
echo " ||                                            || "
echo " ||                                            || "
echo " \/                                            \/ "
echo " "

		#------Выводим таблицу со всеми нодами, их айпи, ролью.
		#------Тут же записываем в две переменные массив с именами нод и массив с айпи нод
		#------Внимание! Имена и адреса в двух разных массивах идут под одинаковым индексом для удобства!

printf "  %-12s %-16s %s\n" "NAME" "IP" "ROLE"
echo "--------------------------------------------------"
for item in $ALL_NODES
do
	name="${item%%=*}"
	ip="${item##*=}"
	role="node"
	if [[ "$name" == "$NODE_NAME" ]]
	then
		role="jump node (u are here!!!)"
	else
		nodes_names_without_jumpNode="$nodes_names_without_jumpNode $name"		# формируем массив с именами нод
		nodes_ip_without_jumpNode="$nodes_ip_without_jumpNode $ip"			# формируем массив с айпи нод
	fi
	printf "  %-12s %-16s %s\n" "$name" "$ip" "$role"
done

		#------Убираем лишний пробел в начале обоих массивов
		#------записываем отдельно айпи и имя бастиона
		#------Определяем количество нод (в будущем возможен код, где будет создаваться 2 и более бастиона)

nodes_names_without_jumpNode="${nodes_names_without_jumpNode# }"
nodes_ip_without_jumpNode="${nodes_ip_without_jumpNode# }"
jumpNode_ip="${NODE_IP}"
jumpNode_name=$(hostname)
nodes_count=$(echo $nodes_names_without_jumpNode | wc -w)

	#------

#nodes_ip_and_names_without_nodeJump=""

#for element in $ALL_NODES
#do
#        if [[ $element != "${NODE_NAME}=${NODE_IP}" ]]
#        then
#                nodes_ip_and_names_without_nodeJump="$nodes_ip_and_names_without_nodeJump $element"
#        fi
#done
#nodes_ip_and_names_without_nodeJump="${nodes_ip_and_names_without_nodeJump# }"
#echo "All nodes NO jumpNode:$nodes_ip_and_names_without_nodeJump"

#for item in $nodes_ip_and_names_without_nodeJump
#do
#	current_name="${item%%=*}"
#	current_ip="${item##*=}"
#	nodes_names_without_jumpNode="$nodes_names_without_jumpNode $current_name"
#	nodes_ip_without_jumpNode="$nodes_ip_without_jumpNode $current_ip"
#done



#sudo dnf install sshpass -y
#rm -f ~/.ssh/.id_rsa ~/.ssh/.id_rsa.pub
#ssh-keygen -N "" -f ~/.ssh/.id_rsa -q




#echo "Количество нодов - "$nodes_count
#echo "upstream lab_1 {" > /home/vagrant/Lab_1_nginx/ready_configs/balancer.conf
#for ip in $active_nodes_ip_without_jumpNode
#do
#       echo -e "\tserver $ip:8080 max_fails=2 fail_timeout=10s;" >> /home/vagrant/Lab_1_nginx/ready_configs/balancer.conf
#done
#echo -e "}\n" >> /home/vagrant/Lab_1_nginx/ready_configs/balancer.conf
#echo "\
#       server {
#               listen     80 default_server;
#               server_name _;
#
#               location / {
#                       proxy_pass http://lab_1;
#
#                          }
#               }
#" >> /home/vagrant/Lab_1_nginx/ready_configs/balancer.conf
#sudo  mv /home/vagrant/Lab_1_nginx/ready_configs/balancer.conf /etc/nginx/conf.d/balancer.conf
#sudo restorecon -v /etc/nginx/conf.d/balancer.conf
#for ip in $active_nodes_ip_without_jumpNode          #Making ssh public key insert, nginx install, generate HTML page and send it  ---start---
#do

#       node_addr="vagrant@$ip"
#       sshpass -p "vagrant"\
#       ssh-copy-id -i ~/.ssh/.id_rsa.pub -o\
#       StrictHostKeyChecking=no\
#       $node_addr
#       node_name=$(ssh $node_addr "hostname")
#       echo "nginx installing on "$node_name ", wait please..."
#       ssh $node_addr "sudo dnf install nginx -y"
#       sleep 5
#       ssh $node_addr "sudo systemctl enable nginx"
#       ssh $node_addr "sudo firewall-cmd --permanent --add-port=8080/tcp"              #SELinux setting
#       ssh $node_addr "sudo firewall-cmd --reload"                                     #SELinux setting
#       echo "<!DOCTYPE html>
#               <html>
#               <head>
#               <title>Welcome to $node_name!</title>
#               <style>
#                   body {
#                       width: 35em;
#                       margin: 0 auto;
#                       font-family: Tahoma, Verdana, Arial, sans-serif;
#                   }
#               </style>
#               </head>
#               <body>
#               <h1>Active user and IP address - $node_addr</h1>
#               <p>If you see this page, the nginx web server is successfully installed and
#               working. Further configuration is required.</p>
#       " > /home/vagrant/Lab_1_nginx/ready_configs/${node_name}_default.html                   # ---end---
#
#                                                       # ---start--- Making node config
#       ssh $node_addr "sudo mkdir /usr/share/nginx/html/lab_1"
#       ssh $node_addr "sudo chown vagrant:vagrant  /usr/share/nginx/html/lab_1"
#       echo "server {
#               listen     8080;
#               server_name _;
#               allow $jumpNode_ip;
#               deny all;
#
#               location / {
#                       root /usr/share/nginx/html/lab_1;
#                       index ${node_name}_default.html;
#               }
#       }
#" > /home/vagrant/Lab_1_nginx/ready_configs/${node_name}_host.conf
#       scp /home/vagrant/Lab_1_nginx/ready_configs/${node_name}_default.html $node_addr:/usr/share/nginx/html/lab_1
#       ssh $node_addr "sudo restorecon -Rv /usr/share/nginx/html/lab_1/"               #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#       scp /home/vagrant/Lab_1_nginx/ready_configs/${node_name}_host.conf $node_addr:/tmp/
#       ssh $node_addr "sudo mv /tmp/${node_name}_host.conf /etc/nginx/conf.d/"
#       ssh $node_addr "sudo restorecon -v /etc/nginx/conf.d/${node_name}_host.conf"    #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#       ssh $node_addr "sudo chmod a+x /etc/nginx/conf.d/${node_name}_host.conf"
#       ssh $node_addr "sudo systemctl restart nginx"
#
#done                                                   # ---end---
#sudo setsebool -P httpd_can_network_connect on                                         #SELinux setting
#sudo systemctl restart nginx
#echo "Testing nodes work from jumpNode, wait..."
#sleep 5
#for i in $active_nodes_ip_without_jumpNode
#do
#       curl $bastion_check:80
#       if [[ $? == 0 ]]
#       then
#               echo "ping of "$i" success!"
#       else
#               echo "Something went wrong!"
#       fi

#done
#echo "end of script!"
