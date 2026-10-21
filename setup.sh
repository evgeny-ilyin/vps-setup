#!/usr/bin/env bash
set -Eeuo pipefail

# Первоначальная настройка Ubuntu 24.04
# Запускать от root.

if [[ $EUID -ne 0 ]]; then
    echo "Ошибка: запусти скрипт от root."
    exit 1
fi

if [[ ! -r /etc/os-release ]]; then
    echo "Ошибка: не удалось определить ОС."
    exit 1
fi

. /etc/os-release

if [[ "$ID" != "ubuntu" || "$VERSION_ID" != "24.04" ]]; then
    echo "Ошибка: требуется Ubuntu 24.04. Обнаружена: $PRETTY_NAME"
    exit 1
fi

# Проверяем, что SSH-ключи заранее добавлены.
AUTH_KEYS="/root/.ssh/authorized_keys"

if [[ ! -s "$AUTH_KEYS" ]]; then
    echo "Ошибка: отсутствует $AUTH_KEYS или он пуст."
    echo "Сначала добавь публичные SSH-ключи."
    exit 1
fi

# Не начинаем обновление, если SSH-конфигурация уже некорректна.
sshd -t

echo "==> Обновление списка пакетов..."
apt-get update

echo "==> Обновление установленных пакетов..."
export DEBIAN_FRONTEND=noninteractive
apt-get upgrade -y

echo "==> Установка утилит..."
apt-get install -y htop nload vim traceroute

echo
echo "==> Проверка установки..."
for cmd in htop nload vim traceroute; do
    if command -v "$cmd" >/dev/null 2>&1; then
        printf 'OK: %s\n' "$cmd"
    else
        printf 'ОШИБКА: %s не найден\n' "$cmd"
        exit 1
    fi
done

echo
echo "==> Настройка завершена!"
echo "SSH-конфигурация не изменялась."
echo "Парольный вход не отключался."