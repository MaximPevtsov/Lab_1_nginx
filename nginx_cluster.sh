#!/bin/bash

		#------Подключаем файл с данными о нодах из vagrant
		#------Файл содержит ALL_NODES, NODE_NAME, NODE_IP, SUBNET, NODE_COUNT

source /etc/vagrant-info.env

		#------Включаем порт :80, потому что по дефолту он выключен в RHEL подобных дистрибутивах

NODES_DEFAULT_PORT="8080"

sudo firewall-cmd --permanent --add-port=80/tcp > /dev/null 2>&1                  	#SELinux tcp :80 activated
sudo firewall-cmd --reload > /dev/null 2>&1						#Do all saently (NO stderr NO stdout)


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
echo ""
		#------ Убираем лишний пробел в начале обоих массивов
		#------ Записываем отдельно айпи и имя бастиона
		#------ Определяем количество нод (в будущем возможен код, где будет создаваться 2 и более бастиона)
		#------ Просим юзера ввести порт для бастиона. Нужно ввести число без нулей впереди от 1 до 65536 (пример: 8, 22, 80, 197, 6549 и тд)
		#------ Внимание! Убедитесь, что порт свободен и не используется никаким другим процессом до запуска скрипта! Если не хотите/не можете - используйте дефолтный порт ":80"

nodes_names_without_jumpNode="${nodes_names_without_jumpNode# }"
nodes_ip_without_jumpNode="${nodes_ip_without_jumpNode# }"
jumpNode_ip="${NODE_IP}"
jumpNode_name=$(hostname)
#nodes_count=$(echo $nodes_names_without_jumpNode | wc -w)


		#------Устанавливаем утилиту "sshpass"
		#------Если была создана пара ключей ранее, то удаляем их, чтобы не было конфликта с вновь созданными
		#------Генерим новую пару ключей, тихо кладем ее в стоковый каталог
sleep 2
echo ""
echo ""
echo ""
echo "|-----------------------------------------------------------------|"
echo "|                  JUMP_NODE SETTING STARTED!                     |"
echo " ----------------------------------------------------------------- "
echo "|           Installing and configurate nginx on jumpNode          |"
echo "|            Making configuration file for jumpNode	        |"
echo "|                      Wait, please...				|"
echo " ----------------------------------------------------------------- "
echo ""
sleep 5
sudo dnf install sshpass -y 			> /dev/null
rm -f ~/.ssh/id_rsa ~/.ssh/id_rsa.pub		> /dev/null
ssh-keygen -N "" -f ~/.ssh/id_rsa -q		> /dev/null
sudo dnf install nginx -y 			2> /dev/null
sudo systemctl enable nginx

		#------Блок формирвания конфига для бастиона. Делаем это с помощью мощного built-in под названием awk
		#------Первая строчка запускаем awk. Задаем переменые, которые будут использоваться в теле команды и заполняем их. Делаем это на языке Bash
		#------Далее идет тело команды awk в кавычках ''
		#------Все в этих кавычках написано на языке утилиты awk, а не Bash!!!
		#------Конструкция:
		#------
		#------    awk [flag] [key=value] \
		#------    (single quote) /PATTERN/ {
		#------       action ...
		#------       next		    }
		#------    {print}
		#------    (single quote) file_in > file_out
		#------

sudo chmod u+x balancer_template.conf
awk -v string_with_ip="$nodes_ip_without_jumpNode" -v port="$NODES_DEFAULT_PORT" \
'/__ROUND_ROBIN_SERVERS__/ {
	count = split (string_with_ip, massive_with_ip, " ")
	for (i=1; i<=count; i++){
		print "    server " massive_with_ip[i] ":" port " max_fails=2 fail_timeout=30s;"
				}
	next
			  }

		#------ В нашем скрипте 3 блока, обьясним принцип работы на примере блока №2 ниже.
		#------ Задаем паттерн __LESAT_CONN_SERVERS__, который АВК будет искать в шаблонном файле
		#------ Внимание! АВК принимает на вход ТОЛЬКО строку. Тут режем строку со входа по пробелу и суем в массив,
		#------ потому что в нашем цикле нужен массив. Начинаем по шаблону вставлять айпи из массива там, где
		#------ утилита находит паттерн и заменяет его на текущий айпи.
		#------ Закрываем логику работы при нахождении паттерна.
		#------ Переходим к следующей строке
		#------ или к следующему паттерну и действиям при его обнаружении.
		#------ Если ни один паттерн не подошел, то просто перепечатываем строку не меняя ее.
		#------ На вход скармливаем файл с шаблоном file_in, на выходе получаем всегда перезаписанный новый файл с обработкой по паттернам file_out.

/__LEAST_CONN_SERVERS__/ {
	count = split (string_with_ip, massive_with_ip, " ")
	for (i=1; i<=count; i++) {
		print "    #server " massive_with_ip[i] ":" port " max_fails=2 fail_timeout=30s;"
				 }
	next
		 }

/__WEIGHT_BALANCE_SERVERS__/ {
        count = split (string_with_ip, massive_with_ip, " ")
        for (i=1; i<=count; i++) {
                print "    #server " massive_with_ip[i] ":" port " weight=1 max_fails=2 fail_timeout=30s;"
                                 }
        next
                 }
{print}
' balancer_template.conf > balancer_${jumpNode_name}.conf
chmod u+x balancer_${jumpNode_name}.conf

echo " ----------------------------------------------------------------- "
echo "|              jumpNode config generated                          |"
echo "|           Send them to /etc/nginx/conf.d/                       |"
echo " ----------------------------------------------------------------- "
echo ""
sleep 3
sudo mv balancer_${jumpNode_name}.conf /etc/nginx/conf.d/balancer_${jumpNode_name}.conf
sudo restorecon -v /etc/nginx/conf.d/balancer_${jumpNode_name}.conf > /dev/null 2>&1
echo "config generated successfully!"
		#------ Prepare to node_conf and HTML generating
		#------ Готовим массивы айпи и имен нод.
		#------ Сейчас они в строках, а нам нужны в виде массивов, чтобы обращаться к рандомным членам по индексу.



nodes_ip_massive=()
nodes_names_massive=()
for item in $nodes_ip_without_jumpNode
do
	nodes_ip_massive+=("$item")
done

for item in $nodes_names_without_jumpNode
do
	nodes_names_massive+=("$item")
done

		#------ node_conf generator
		#------ Огромный блок. Тут даем права для файлов шаблонов и затем для каждой ноды в цикле:
		#------ 1. Определяем и запоминаем ее адрес node_addr для обращения через ssh
		#------ 2. Кладем публичный ключ бастиона в ноду, куча опций, чтобы сделать это автоматически и без прерывания
		#------ 3. Ставим nginx, делаем enable, включаем порт 8080 на ноде для listen
		#------ 4. Блок awk по аналогии выше формирует из шаблона node_template.conf по паттернам рабочий конфиг node_${node_name}.conf
		#------ 5. Даем права, пересылаем в два этапа файл конфига на ноду ребутаем nginx
		#------				---следующая нода---


count_conf=0
count_html=0
sudo chmod u+x node_template.conf
sudo chmod u+x html_template.html
for ip in $nodes_ip_without_jumpNode          #Making ssh public key insert, nginx install, generate HTML page and send it  ---start---
do
	node_addr="vagrant@$ip"
	sshpass -p "vagrant" \
	ssh-copy-id -i ~/.ssh/id_rsa.pub -o \
	StrictHostKeyChecking=no \
	$node_addr 				> /dev/null 2>&1
	node_name=$(ssh $node_addr "hostname")
	echo ""
	echo ""
	echo ""
	echo ""
	echo "|-----------------------------------------------------------------|"
	echo "|                     NODE SETTING STARTED!                       |"
	echo " ----------------------------------------------------------------- "
	echo "|     Syncronize SSH keys and make node nginx configuration       |"
	echo "|       Installing nginx on "$node_name", wait please...                |"
	echo " ----------------------------------------------------------------- "
	echo ""
	sleep 5
	ssh $node_addr "sudo dnf install nginx -y" 2> /dev/null
	ssh $node_addr "sudo systemctl enable nginx" 2> /dev/null
	ssh $node_addr "sudo firewall-cmd --permanent --add-port=8080/tcp" > /dev/null 2>&1               #SELinux setting
	ssh $node_addr "sudo firewall-cmd --reload"                        > /dev/null 2>&1            			 #SELinux setting
	sleep 2
	awk -v jumpNode_ip=$NODE_IP -v port=$NODES_DEFAULT_PORT -v current_node_name=${nodes_names_massive[count_conf]} \
	' /__NODE_PORT__/ {
	print "        listen " port ";"
	next
			  }
	/__JUMPNODE_IP__/ {
	print "        allow " jumpNode_ip ";"
	next
			  }
	/__DEFAULT_HTML_DIR_OF_NODE_NUMBER__/ {
	print "        root /usr/share/nginx/html/" current_node_name "_html;"
	next
					 }
	/__DEFAULT_NODE_HTML_STATIC_FILE__/ {
	print "        index " current_node_name "_default.html;"
	next
					 }

	{print}

	' node_template.conf > node_${node_name}.conf
	count_conf+=1
	chmod u+x node_${node_name}.conf
	echo ""
	echo " ----------------------------------------------------------------- "
	echo "|                Configuration nginx file ready!!!                |"
	echo "|                 Send them to the " $node_name "                       |"
	echo " ----------------------------------------------------------------- "
	echo ""
	sleep 5
	scp /home/vagrant/Lab_1_nginx/node_${node_name}.conf $node_addr:/tmp/
	ssh $node_addr "sudo mv /tmp/node_${node_name}.conf /etc/nginx/conf.d/"
	ssh $node_addr "sudo restorecon -v /etc/nginx/conf.d/node_${node_name}.conf > /dev/null 2>&1" 	  #SELinux
	ssh $node_addr "sudo chmod u+x /etc/nginx/conf.d/node_${node_name}.conf"
	ssh $node_addr "sudo systemctl restart nginx"
	echo "done!"

		#------ Until "HERE" the code is working in tests 11.11.20206 14:08

		#------ HTML generator
		#------ Генерируем с помощью awk готовую html страницу ${node_name}_default.html из шаблона html_template.html
		#------ Все по аналогии выше, даем права нужные в конце
		#------ 
		#------
		#------
		#------
		#------
		#------


	echo ""
	echo " ----------------------------------------------------------------- "
	echo "|   Okay, now making default HTML page for " ${node_name} "             |"
	echo "|                Wait, please, dear comrade!                      |"
	echo " ----------------------------------------------------------------- "
	echo ""
	sleep 3
	awk -v jumpNode_ip=$NODE_IP -v current_node_ip=${nodes_ip_massive[count_html]} -v current_node_name=${nodes_names_massive[count_html]} \
        ' /__TITLE__/ {
        print "    <title>Welcome to NODE " current_node_name "!</title>"
        next
                          }
        /__NODE_IP__/ {
        print "<h1>Node ip - " current_node_ip "</h1>"
        next
                          }
        /__CONF_AND_HTML_INFO__/ {
        print "<p>You can find nginx configuration in /etc/nginx/conf.d/node_" current_node_name ".conf</p>"
	print "<p>Default static html-file in /usr/share/nginx/html/" current_node_name "_html/" current_node_name "_default.html</p>"
        next
                                         }
        /__CONGRATS__/ {
        print "<p class=\"status\">If u see this - proxy work correctly. Congratulations, comrad!</p>"
        print "<p class=\"status\">Press CTRL+F5 to reboot browser cash and then press F5 a few time to see balancer work.</p>"
	next
                                         }

        {print}

        ' html_template.html > ${node_name}_default.html
        count_html+=1
        sudo chmod u+x ${node_name}_default.html
	echo "done!"
	sleep 3
                   # ---end---


	echo ""
	echo " ----------------------------------------------------------------- "
	echo "|                       HTML page ready!                          |"
	echo "|                    Send them to current node                    |"
	echo " ----------------------------------------------------------------- "
	echo ""
	sleep 3
	ssh $node_addr "sudo mkdir -p /usr/share/nginx/html/${node_name}_html"
	ssh $node_addr "sudo chown vagrant:vagrant /usr/share/nginx/html/${node_name}_html"
	scp /home/vagrant/Lab_1_nginx/${node_name}_default.html $node_addr:/usr/share/nginx/html/${node_name}_html/
	ssh $node_addr "sudo restorecon -Rv /usr/share/nginx/html/${node_name}_html/"               #SELinux
	rm ${node_name}_default.html
	ssh $node_addr "sudo systemctl enable nginx"
	ssh $node_addr "sudo systemctl restart nginx"
	echo "done!"
done


sudo setsebool -P httpd_can_network_connect on > /dev/null 2>&1                                         #SELinux setting
sudo systemctl restart nginx

		#------
		#------

echo " "
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo ""
echo ""
echo ""
echo " ----------------------------------------------------------------- "
echo "|     Almost done! Now lets check our node by 'curl' command.     |"
echo "|           Testing request from jumpNode to node...              |"
echo " ----------------------------------------------------------------- "
echo ""
sleep 3
for ip in $nodes_ip_without_jumpNode
do
        if curl -s -o /dev/null -w "%{http_code}" "http://${ip}:${NODES_DEFAULT_PORT}/" | grep -q '^200$'
        then
                echo -e "ping of ${ip} ${GREEN}success!${NC}"
		sleep 1
        else
                echo -e "ping of ${ip} ${RED}went wrong!${NC}"
        	sleep 1
	fi
done
echo " "
echo "End of the programm! Now try to start balancer in your browser..."
