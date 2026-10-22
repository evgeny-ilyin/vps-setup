
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
if ! SSH_CONFIG="$(sshd -T 2>&1)"; then
	echo "Ошибка: не удалось проверить конфигурацию SSH:"
	echo "$SSH_CONFIG"
	exit 1
fi

if ! grep -qx 'pubkeyauthentication yes' <<< "$SSH_CONFIG"; then
	echo "Ошибка: SSH-аутентификация по ключу сейчас не включена."
	echo "Текущее значение:"
	grep '^pubkeyauthentication ' <<< "$SSH_CONFIG" || echo "Параметр не найден"
	echo "Сначала настрой и проверь вход по ключу."
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

check_setting() {
	local setting="$1"
	local expected="$2"

	if ! grep -Eq "^${setting}[[:space:]]+(${expected})$" <<< "$EFFECTIVE"; then
		echo "Ошибка: настройка $setting имеет неожиданное значение."
		grep -E "^${setting}[[:space:]]" <<< "$EFFECTIVE" || true
		return 1
	fi
}

if 	! check_setting pubkeyauthentication yes ||
		! check_setting passwordauthentication no ||
		! check_setting kbdinteractiveauthentication no ||
		! check_setting permitrootlogin 'prohibit-password|without-password'; then
			echo "Эффективные настройки SSH:"
			grep -E '^(pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|permitrootlogin) ' <<< "$EFFECTIVE"
			echo "Резервная копия sshd_config: $BACKUP"
			exit 1
fi

echo "Проверка эффективных настроек SSH пройдена."

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