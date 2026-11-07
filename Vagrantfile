BASE_BOX_IMAGE   = "bento/rockylinux-9"	#Если у вас другой бокс, то обязательно
BASE_BOX_VERSION = "202510.26.0"	#введите сюда его актуальные данные

BASE_IP     = [192, 168, 10]		#Блок формирования переменных- введите первые 3 октета сети
IP_START    = 100			#введите четвертый октет, начиная с введенного числа (не включительно) будут формироваться уникальные айпи нод
NODE_COUNT  = 3				#введите количество нод
NODE_MEMORY = 512			#отведенная RAM
NODE_CPUS   = 1				#отведенные процессоры
NODE_PREFIX = "rocky"			#префикс названия нод

make_ip = ->(last_octet) { (BASE_IP + [last_octet]).join(".") }

NODES = (1..NODE_COUNT).map do |i|
  { name: "#{NODE_PREFIX}#{i}", ip: make_ip.(IP_START + i) }
end
#ALL_NODES = NODES.map { |n| "#{n[:name]}=#{n[:ip]}" }.join(" ")
ALL_NODES = "\"#{NODES.map { |n| "#{n[:name]}=#{n[:ip]}" }.join(" ")}\""
SUBNET    = make_ip.(0) + "/24"

Vagrant.configure("2") do |config|
  config.vm.box          = BASE_BOX_IMAGE
  config.vm.box_version  = BASE_BOX_VERSION
  config.vm.box_check_update = false

  (1..NODE_COUNT).each do |i|
    node_name = "#{NODE_PREFIX}#{i}"
    node_ip   = make_ip.(IP_START + i)

    config.vm.define node_name do |node|
      node.vm.hostname = node_name
      node.vm.network :private_network, ip: node_ip

      node.vm.provision "shell", inline: <<~SHELL
        cat > /etc/vagrant-info.env <<'EOF'
        NODE_COUNT=#{NODE_COUNT}
        SUBNET=#{SUBNET}
        NODE_NAME=#{node_name}
        NODE_IP=#{node_ip}
        ALL_NODES=#{ALL_NODES}
        EOF
        chmod 644 /etc/vagrant-info.env		#сюда ляжет файл с информацией о созаднных нодах
      SHELL

      node.vm.provision "shell", inline: <<-SHELL
        echo "=================================================="
        echo "  VAGRANT NODE IS UP AND CONFIGURED"
        echo "--------------------------------------------------"
        echo "  Hostname : #{node_name}"
        echo "  IP       : #{node_ip}"
        echo "  Time     : $(TZ='Europe/Moscow' date)"
        echo "=================================================="
      SHELL

      node.vm.provider "virtualbox" do |vb|
        vb.gui    = false
        vb.memory = NODE_MEMORY
        vb.cpus   = NODE_CPUS
      end
    end
  end
end