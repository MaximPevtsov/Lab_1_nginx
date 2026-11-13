# Lab_1_nginx — NGINX Cluster Autostart

Скрипт разворачивает лабораторный стенд из нескольких VM (Vagrant): настраивает jump node (бастион) как балансировщик и раздаёт статику с нод.

## Что делает скрипт

1. Читает данные о нодах из `/etc/vagrant-info.env` (`ALL_NODES`, `NODE_NAME`, `NODE_IP`).
2. Открывает порт **80** на бастионе (firewall).
3. Показывает таблицу обнаруженных VM (имя / IP / роль).
4. Ставит `sshpass`, генерирует SSH-ключи (`~/.ssh/id_rsa`, без точки).
5. Ставит nginx на бастион, включает автозапуск.
6. Генерирует конфиг балансировщика `balancer_<jumpNode>.conf` из `balancer_template.conf` по маркерам:
   - `__ROUND_ROBIN_SERVERS__` — round-robin;
   - `__LEAST_CONN_SERVERS__` — least_conn (строки закомментированы `#server`);
   - `__WEIGHT_BALANCE_SERVERS__` — weight (строки закомментированы `#server`).
   Кладёт его в `/etc/nginx/conf.d/`, делает `restorecon`.
7. Для каждой ноды (цикл по IP):
   - копирует SSH-ключ (`ssh-copy-id`, вывод скрыт);
   - ставит nginx, `enable`, открывает порт **8080** (firewall);
   - генерирует `node_<name>.conf` из `node_template.conf` (`listen 8080`, `allow <jumpNode_IP>`, `root`, `index`);
   - копирует конфиг на ноду через `/tmp` + `sudo mv`, `restorecon`, `restart nginx`;
   - генерирует HTML `<name>_default.html` из `html_template.html`;
   - создаёт `/usr/share/nginx/html/<name>_html/`, `chown vagrant`, копирует HTML, `restorecon -Rv`, `restart nginx`.
8. Включает `httpd_can_network_connect` (SELinux), рестартит nginx на бастионе.
9. Проверяет каждую ноду: `curl http://<ip>:8080/`, печатает `success!` (зелёный) или `went wrong!` (красный).

## Требования

- Rocky Linux / RHEL-подобная ОС (SELinux, `firewall-cmd`, `dnf`).
- Vagrant-стенд с несколькими VM в приватной сети.
- Файл `/etc/vagrant-info.env` с переменными:
  - `ALL_NODES` — список `name=ip` через пробел;
  - `NODE_NAME` — имя текущей (jump) ноды;
  - `NODE_IP` — IP текущей (jump) ноды.
- Права `sudo` у пользователя (скрипт использует `sudo`).
- Шаблоны в каталоге со скриптом:
  - `balancer_template.conf`
  - `node_template.conf`
  - `html_template.html`

## Структура файлов

```
Lab_1_nginx/
├── .gitignore
├── nginx_cluster.sh          # основной скрипт
├── balancer_template.conf    # шаблон конфига балансировщика
├── node_template.conf        # шаблон конфига ноды
├── html_template.html        # шаблон статической страницы
└── README.md
```

## Шаблоны: маркеры

Во всех шаблонах на месте подстановки стоит **только маркер**. Всё остальное — `;`, пути, директивы — добавляет `awk` в `print`, **заменяя всю строку с маркером**.

### balancer_template.conf

```nginx
upstream round_robin {
    __ROUND_ROBIN_SERVERS__
}
```

Если нужны `least_conn` и `weight` — **раскомментируйте блок целиком** (вместе с маркером **внутри** `{ ... }`):

```nginx
upstream least_conn {
    least_conn;
    __LEAST_CONN_SERVERS__
}

upstream weight_balance {
    __WEIGHT_BALANCE_SERVERS__
}
```

### node_template.conf

```nginx
server {
    __NODE_PORT__
    server_name _;
    __JUMPNODE_IP__
    deny all;

    location / {
        __DEFAULT_HTML_DIR_OF_NODE_NUMBER__
        __DEFAULT_NODE_HTML_STATIC_FILE__
    }
}
```

> `awk` **заменяет всю строку** с маркером: `__NODE_PORT__` → `listen 8080;`, `__JUMPNODE_IP__` → `allow <jumpNode_IP>;`, `__DEFAULT_HTML_DIR_OF_NODE_NUMBER__` → `root /usr/share/nginx/html/<name>_html;`, `__DEFAULT_NODE_HTML_STATIC_FILE__` → `index <name>_default.html;`. **`;`** — в `print`, **не** в шаблоне.

### html_template.html — маркеры

- `__TITLE__`
- `__NODE_IP__`
- `__CONF_AND_HTML_INFO__`
- `__CONGRATS__`

## Запуск

Зайдите на любую ВМ, созданную в Vagrant под пользователем vagrant. Переместитесь в домашний каталог ~/ одной из своей ВМ, установите утилиту git и клонируйте репозиторий в домашний каталог

```bash
cd
sudo dnf install git -y
git clone https://github.com/MaximPevtsov/Lab_1_nginx.git
```
Перейдите в каталог проекта и запустите его

```bash
cd ~/Lab_1_nginx
chmod +x nginx_cluster.sh
./nginx_cluster.sh
```

Порт нод задан в скрипте: `NODES_DEFAULT_PORT="8080"`. Порт бастиона — из `balancer_template.conf` (`listen 80 default_server`).
Внимание! Если вы будете менять жестко прописанный `NODES_DEFAULT_PORT` на другой, то обязательно дайте доступ от SELinux новому порту, иначе nginx не запустится!

## Проверка результата

На бастионе:

```bash
sudo nginx -t
sudo systemctl status nginx
ls -l /etc/nginx/conf.d/
```

На каждой ноде:

```bash
sudo nginx -t
ls -l /usr/share/nginx/html/<name>_html/
```

С бастиона:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://<node_ip>:8080/
```

Ожидается `200`.

В браузере: открыть `http://<jumpNode_IP>:80/` — должна отдаваться статика нод через балансировщик.


## Безопасность / дисклеймер

Скрипт **учебный**:

- пароль `vagrant` в `sshpass`;
- `StrictHostKeyChecking=no`;
- `chmod u+x` на `.conf`/`.html` (лишнее для продакшена).

Для продакшена **не** использовать как есть: ключи без пароля, отключение проверки host key и `u+x` на конфигах **не** соответствуют практикам безопасности.
