CFIP Connector installer

CFIP Connector installer — это инструмент для автоматической установки и настройки клиента с использованием Docker и Docker Compose.

Основные функции

Установка Docker и Docker Compose.

Генерация сертификатов.

Автоматическая установка необходимых пакетов и настройка конфигурационных файлов.

Запуск Docker с предварительно настроенными параметрами.


Установка и использование

1. Запуск Docker-установки
Выполните скрипт docker.sh с правами sudo или от имени root:

sudo ./docker.sh

Скрипт автоматически установит Docker и Docker Compose.


2. Настройка конфигурации
Откройте файл config.json и заполните следующие параметры:

{  
    "organization": "Название вашей организации",  
    "password": "Пароль для генерации сертификатов"  
}


3. Установка и настройка
Выполните скрипт install.sh:

./install.sh

Скрипт автоматически:

Установит необходимые пакеты (unzip, telnet и другие).

Распакует файлы.

Сгенерирует сертификаты.

Заполнит конфигурационные файлы.

Запустит Docker.




Требования

Linux-сервер с поддержкой sudo или доступом к root.

Установленные зависимости:

bash

curl
