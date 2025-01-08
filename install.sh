#!/bin/bash

CONFIG_FILE="config.json"
PRIVATE_YAML="connector/private.yaml"
CONFIG_YAML="connector/config.yaml"

# === Функция: Проверка соединения через telnet и curl ===
check_connection() {
  local domain="fp-api.cbdbzi.uz"
  local ip="10.95.88.47"
  local port="443"
  local url="https://$domain/cfip/healthcheck"

  echo "Проверка соединения с $domain ($ip:$port)..."

  # Проверка через telnet
  if command -v telnet &>/dev/null; then
    echo "Проверка через telnet..."
    (echo quit | telnet "$ip" "$port") &>/dev/null
    if [ $? -eq 0 ]; then
      echo "Telnet: Соединение с $ip:$port успешно установлено."
    else
      echo "Telnet: Не удалось установить соединение с $ip:$port."
    fi
  else
    echo "Telnet не установлен. Установите telnet для проверки соединения."
  fi

  # Проверка через curl
  echo "Проверка через curl..."
  curl --resolve "$domain:$port:$ip" --head "$url" -k &>/dev/null
  if [ $? -eq 0 ]; then
    echo "Curl: Healthcheck $url успешно доступен."
  else
    echo "Curl: Не удалось получить доступ к $url."
  fi
}

# === Вызов скрипта crt.sh ===
run_crt_script() {
  if [ -f "crt.sh" ]; then
    echo "Запуск crt.sh..."
    bash crt.sh
  else
    echo "Файл crt.sh не найден!"
    exit 1
  fi
}

# === Функция: Проверка наличия config.json ===
check_config_file() {
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "Файл конфигурации $CONFIG_FILE не найден!"
    exit 1
  fi
}

# === Функция: Извлечение значений из config.json ===
extract_config_values() {
  ORG_ID=$(sed -n 's/.*"id": "\(.*\)".*/\1/p' "$CONFIG_FILE")
  PASSWORD=$(sed -n 's/.*"password": "\(.*\)".*/\1/p' "$CONFIG_FILE")
  BINCODES=$(sed -n 's/.*"bincodes": \[\([^]]*\)\].*/\1/p' "$CONFIG_FILE" | tr -d '"' | tr ',' ' ')
  ORG_SALT=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
}

# === Функция: Распаковка файлов ===
unpack_files() {
  for archive in connector-conf.*; do
    if [[ -f $archive ]]; then
      case $archive in
        *.zip) unzip "$archive" ;;
        *.tgz) tar -xzf "$archive" ;;
        *) echo "Неизвестный формат: $archive"; exit 1 ;;
      esac
    fi
  done
}

# === Функция: Загрузка Docker-образа ===
load_docker_image() {
  for archive in connector*.tar.gz; do
    if [[ -f $archive ]]; then
      echo "Загрузка Docker-образа из файла $archive..."
      docker load < "$archive"
    else
      echo "Файл с шаблоном connector*.tar.gz не найдены!"
      exit 1
    fi
  done
}

# === Функция: Копирование сертификатов ===
copy_certificates() {
  if [ -d "certs" ] && [ -d "connector/certs" ]; then
    cp -R certs/* connector/certs/
  else
    echo "Папка certs или connector/certs не найдена!"
    exit 1
  fi
}

# === Функция: Обработка файла private.yaml ===
update_private_yaml() {
  if [ ! -f "$PRIVATE_YAML" ]; then
    echo "Файл $PRIVATE_YAML не найден!"
    exit 1
  fi

  sed -i \
    -e "s|<org>|$ORG_ID|g" \
    -e "s|<org-signing.key password>|$PASSWORD|g" \
    -e "s|<org-signing.key secret>|$PASSWORD|g" \
    -e "s|<org-encryption.key secret>|$PASSWORD|g" \
    -e "s|<org-encryption.key password>|$PASSWORD|g" \
    "$PRIVATE_YAML"
}

# === Функция: Проверка и добавление строки в config.yaml ===
update_config_yaml() {
  if [ -f "$CONFIG_YAML" ]; then
    if ! grep -q "id: $ORG_ID" "$CONFIG_YAML"; then
      echo "Добавление строки с id: $ORG_ID в config.yaml..."
      
      # Преобразуем bincodes в строку с кавычками, учитывая что это список строк
      BINCODES_QUOTED=$(echo "$BINCODES" | sed 's/\([^,]\+\)/"\1"/g' | tr -d '\n')

      # Добавление необходимых строк в config.yaml
      cat <<EOF >> "$CONFIG_YAML"
    - id: $ORG_ID
      title: $ORG_ID
      encryption-certificate-file: certs/${ORG_ID}-encryption.crt
      requisites:
        - key: CardNumber
          starts: ${BINCODES_QUOTED}
EOF
    else
      echo "Строка с id: $ORG_ID уже присутствует в config.yaml."
    fi
  else
    echo "Файл config.yaml не найден!"
    exit 1
  fi
}

# === Функция: Запуск Docker-команд ===
run_docker_commands() {
  cd connector || { echo "Каталог connector не найден!"; exit 1; }

  if [ -f "docker-compose.yml" ]; then
    VERSION=$(sed -n 's/.*connector:\(.*\)/\1/p' docker-compose.yml | tr -d ' :')
  elif [ -f "docker-compose.yaml" ]; then
    VERSION=$(sed -n 's/.*connector:\(.*\)/\1/p' docker-compose.yaml | tr -d ' :')
  else
    echo "Файл docker-compose не найден!"
    exit 1
  fi

  echo "Используемая версия: $VERSION"

  # Проверяем, какой вариант команды docker-compose используется
  if command -v docker-compose &>/dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
  else
    DOCKER_COMPOSE_CMD="docker compose"
  fi

  $DOCKER_COMPOSE_CMD up -d agent
}

# === Функция: Установка зависимостей ===
install_dependencies() {
  if command -v apt &>/dev/null; then
    echo "Ubuntu/Debian система: Устанавливаем зависимости..."
    sudo apt update
    sudo apt install -y curl telnet unzip
  elif command -v yum &>/dev/null; then
    echo "CentOS/AlmaLinux/Oracle Linux система: Устанавливаем зависимости..."
    sudo yum install -y curl telnet unzip
  elif command -v dnf &>/dev/null; then
    echo "AlmaLinux/Oracle Linux система: Устанавливаем зависимости..."
    sudo dnf install -y curl telnet unzip
  else
    echo "Пакетный менеджер не поддерживается. Установите curl, telnet, unzip вручную."
    exit 1
  fi
}

# === Основной код ===
main() {
  install_dependencies      # Устанавливаем зависимости
  check_connection          # Проверка соединений
  run_crt_script            # Запуск crt.sh
  check_config_file         # Проверка наличия config.json
  extract_config_values     # Извлечение значений
  unpack_files              # Распаковка файлов
  load_docker_image         # Загрузка Docker-образа
  copy_certificates         # Копирование сертификатов
  update_private_yaml       # Обновление private.yaml
  update_config_yaml        # Обновление config.yaml
  run_docker_commands       # Запуск Docker-команд
  echo "Скрипт успешно завершен."
}

# === Запуск основного кода ===
main
