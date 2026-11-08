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
printf "С каким портом должен работать бастион?"
read -r -p "Введите номер порта (число от 0001 до 9999): " jumpNode_port

		#------Устанавливаем утилиту "sshpass"
		#------Если была создана пара ключей ранее, то удаляем их, чтобы не было конфликта с вновь созданными
		#------Генерим новую пару ключей, тихо кладем ее в стоковый каталог

#sudo dnf install sshpass -y
#rm -f ~/.ssh/.id_rsa ~/.ssh/.id_rsa.pub
#ssh-keygen -N "" -f ~/.ssh/.id_rsa -q

		#------Блок формирвания конфига для бастиона. Делаем это с помощью мощного built-in под названием awk
		#------Первая строчка запускаем awk. Задаем переменые, которые будут использоваться в теле команды и заполняем их. Делаем это на языке Bash
		#------Далее идет тело команды awk в кавычках ''
		#------Все в этих кавычках написано на языке утилиты awk, а не Bash!!!
		#------


awk -v string_with_ip="$nodes_ip_without_jumpNode" -v port="$jumpNode_port" \				#    awk [flag] [key=value] \
'/__ROUND_ROBIN_SERVERS__/ {										#    (single quote) /PATTERN/ {
	count = split (string_with_ip, massive_with_ip, " ")						#	action ...
	for (i=1; i<=count; i++){									#	next		      }
		print "    server " massive_with_ip[i] ":" port " max_fails=2 fail_timeout=30s;"	#    {print}
				}									#    (single quote) file_in > file_out
	next												#
			  }										#

/__LEAST_CONN_SERVERS__/ {										# Задаем паттерн __LESAT_CONN_SERVERS__, который АВК будет искать в шаблонном файле
	count = split (string_with_ip, massive_with_ip, " ")						# Внимание! АВК принимает на вход ТОЛЬКО строку. Тут режем строку со входа по пробелу и суем в массив
	for (i=1; i<=count; i++) {									# Потому что в нашем цикле нужен массив. Начинаем по шаблону вставлять айпи из массива там, где
		print "    server " massive_with_ip[i] ":" port " max_fails=2 fail_timeout=30s;"	# утилита находит паттерн и заменяет его на текущий айпи.
				 }									# Закрываем логику работы при нахождении паттерна
	next												# Переходим к следующей строке
		 }											# Или к следующему паттерну и действиям при его обнаружении

/__WEIGHT_BALANCE_SERVERS__/ {										# Остальные блоки - аналогично.
        count = split (string_with_ip, massive_with_ip, " ")
        for (i=1; i<=count; i++) {
                print "    server " massive_with_ip[i] ":" port " weight=1 max_fails=2 fail_timeout=30s;"
                                 }
        next
                 }
{print}													# Если ни один паттерн не подошел, то просто перепечатываем строку не меняя ее.
' balancer_template.conf > balancer_${jumpNode_name}.conf						# На вход скармливаем шаблон, на выходе файл с обработкой по паттернам.


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
