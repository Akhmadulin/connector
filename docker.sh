#!/bin/bash

# Определяем ОС
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Не удалось определить операционную систему."
    exit 1
fi

# Устанавливаем зависимости и Docker
if [[ "$OS" == "ubuntu" ]]; then
    echo "Установка Docker для Ubuntu..."

    # Обновляем список пакетов и устанавливаем зависимости
    sudo apt update
    sudo apt install -y curl ca-certificates gnupg lsb-release

    # Создаём директорию для ключей (если ещё не создана)
    sudo mkdir -m 0755 -p /etc/apt/keyrings

    # Добавляем официальный GPG-ключ Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # Добавляем Docker в список репозиториев APT
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Обновляем список пакетов и устанавливаем Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

elif [[ "$OS" == "ol" || "$OS" == "oracle" ]]; then
    echo "Установка Docker для Oracle Linux..."

    # Обновляем список пакетов и устанавливаем зависимости
    sudo dnf update -y
    sudo dnf install -y dnf-plugins-core

    # Добавляем официальный репозиторий Docker
    sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo

    # Устанавливаем Docker
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
    echo "Ваша ОС ($OS) не поддерживается этим скриптом."
    exit 1
fi

# Запускаем и включаем Docker
sudo systemctl start docker
sudo systemctl enable docker

# Проверяем, существует ли группа docker, и создаём её при необходимости
if ! getent group docker > /dev/null; then
    sudo groupadd docker
fi

# Добавляем текущего пользователя в группу docker
sudo usermod -aG docker $USER

# Устанавливаем Docker Compose (если нужна отдельная установка)
DOCKER_COMPOSE_VERSION="v2.20.2"
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

echo "Docker и Docker Compose установлены. Перезагрузите систему для применения изменений."