#!/usr/bin/env bash

KEYS=(
	"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ1t/XwPrdm1w6D7EZB4jCeu7JIyaN9N8Q0LgE3Da/8a evgeny@NZXT"
	"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOa31Rjyhho74iZPeNzKG2TsphSyD4I+KCoc2DCoiysw evgeny@MacBook-Air-Evgeny.local"
)

SSH_DIR="/root/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
touch "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

added=0

for key in "${KEYS[@]}"; do
	if ! grep -qxF -- "$key" "$AUTH_KEYS"; then
		echo "$key" >> "$AUTH_KEYS"
		((added += 1))
	fi
done

echo "Готово. Добавлено ключей: $added"
echo "Всего ключей в authorized_keys: $(wc -l < "$AUTH_KEYS")"