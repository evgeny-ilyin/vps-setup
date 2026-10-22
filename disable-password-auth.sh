
#!/usr/bin/env bash
set -Eeuo pipefail

# Отключение SSH-входа по паролю на Ubuntu.
# Вход по публичному SSH-ключу должен быть предварительно проверен.

if [[ "$EUID" -ne 0 ]]; then
	echo "Ошибка: запусти скрипт от root."
	exit 1
fi

if ! command -v sshd >/dev/null 2>&1; then
	echo "Ошибка: sshd не найден."
	exit 1
fi

CONFIG="/etc/ssh/sshd_config"
DROPIN_DIR="/etc/ssh/sshd_config.d"
BACKUP="${CONFIG}.backup.$(date +%Y%m%d-%H%M%S)"

# Убедиться, что SSH разрешает вход по ключу до изменений.
# if ! sshd -T 2>/dev/null | grep -qx 'pubkeyauthentication yes'; then
# 	echo "Ошибка: SSH-аутентификация по ключу сейчас не включена."
# 	echo "Сначала настрой и проверь вход по ключу."
# 	exit 1
# fi

# Убедиться, что SSH разрешает вход по ключу до изменений.
if ! SSH_CONFIG="$(sshd -T 2>&1)"; then
    echo "Ошибка: не удалось проверить конфигурацию SSH:"
    echo "$SSH_CONFIG"
    exit 1
fi

if ! grep -qx 'pubkeyauthentication yes' <<< "$SSH_CONFIG"; then
    echo "Ошибка: SSH-аутентификация по ключу сейчас не включена."
    echo "Текущее значение:"
    grep '^pubkeyauthentication ' <<< "$SSH_CONFIG" || echo "Параметр не найден"
    echo "Сначала проверь настройки SSH."
    exit 1
fi

cp -a "$CONFIG" "$BACKUP"
echo "Резервная копия: $BACKUP"

# Отдельный drop-in с ранним именем, чтобы переопределить
# стандартные настройки Ubuntu, если они подключены через Include.
# OpenSSH использует первое полученное значение для большинства
# параметров, поэтому файл 00-... может иметь приоритет над другими.
mkdir -p "$DROPIN_DIR"
DROPIN="$DROPIN_DIR/00-disable-password-auth.conf"
DROPIN_BACKUP=""

if [[ -e "$DROPIN" ]]; then
	DROPIN_BACKUP="${DROPIN}.backup.$(date +%Y%m%d-%H%M%S)"
	cp -a "$DROPIN" "$DROPIN_BACKUP"
	echo "Резервная копия drop-in: $DROPIN_BACKUP"
fi

cat > "$DROPIN" <<'EOF'
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
EOF

# Проверить синтаксис конфигурации.
if ! sshd -t; then
	echo "Ошибка конфигурации SSH. Восстанавливаю изменения."
	if [[ -n "$DROPIN_BACKUP" ]]; then
		cp -a "$DROPIN_BACKUP" "$DROPIN"
	else
		rm -f "$DROPIN"
	fi
	cp -a "$BACKUP" "$CONFIG"
	exit 1
fi

# Проверить фактические настройки с учётом Include.
EFFECTIVE="$(sshd -T)"

if ! grep -qx 'pubkeyauthentication yes' <<< "$EFFECTIVE" ||
	! grep -qx 'passwordauthentication no' <<< "$EFFECTIVE" ||
	! grep -qx 'kbdinteractiveauthentication no' <<< "$EFFECTIVE" ||
	! grep -qx 'permitrootlogin prohibit-password' <<< "$EFFECTIVE"; then
	echo "Ошибка: эффективные настройки не соответствуют ожидаемым."
	echo "Резервная копия sshd_config: $BACKUP"
	echo "Проверь настройки вручную:"
	sshd -T | grep -E '^(permitrootlogin|pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication)'
	exit 1
fi

# Применить конфигурацию без принудительного разрыва активных сессий.
if systemctl reload ssh; then
	echo "Готово: настройки SSH применены."
	echo "Вход по ключу разрешён, парольная аутентификация отключена."
	echo "Вход root по паролю запрещён."
	echo "Проверь новое SSH-подключение, не закрывая текущую сессию."
else
	echo "Ошибка перезагрузки конфигурации SSH."
	echo "Проверь сервис вручную: systemctl status ssh"
	exit 1
fi