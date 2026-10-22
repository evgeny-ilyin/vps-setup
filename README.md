# VPS Setup

Скрипты для первоначальной настройки VPS на Ubuntu 24.04.

Все скрипты скачиваются и запускаются непосредственно на сервере. Для скачивания используется `wget`.

## Содержание

- `add-ssh-keys.sh` — добавление публичных SSH-ключей в `authorized_keys`.
- `setup.sh` — обновление системы и установка базовых утилит.
- `disable-password-auth.sh` — отключение SSH-аутентификации по паролю.

## 1. Подключение к новому серверу

Подключиться к серверу по SSH.

Перед началом убедиться, что используется Ubuntu 24.04:

```bash
lsb_release -a
```

## 2. Добавление SSH-ключей

Скачать и запустить скрипт:

```bash
wget -q https://raw.githubusercontent.com/evgeny-ilyin/vps-setup/main/add-ssh-keys.sh -O /root/add-ssh-keys.sh && bash /root/add-ssh-keys.sh
```

Скрипт добавляет публичные ключи в:

```text
/root/.ssh/authorized_keys
```

Повторный запуск не должен создавать дубликаты ключей.

### Проверка

Посмотреть список добавленных ключей:

```bash
cat /root/.ssh/authorized_keys
```

После этого **открыть новое SSH-подключение с компьютера по ключу** и убедиться, что вход работает. Текущую SSH-сессию пока не закрывать.

## 3. Обновление системы и установка утилит

Скачать и запустить основной скрипт:

```bash
wget -q https://raw.githubusercontent.com/evgeny-ilyin/vps-setup/main/setup.sh -O /root/setup.sh && bash /root/setup.sh
```

Скрипт выполняет:

- обновление списка пакетов (`apt-get update`);
- обновление установленных пакетов (`apt-get upgrade`);
- установку утилит `htop`, `nload`, `vim`, `traceroute`.

Скрипт не меняет настройки SSH и не отключает вход по паролю.

После обновления проверить, остались ли пакеты, ожидающие обновления:

```bash
apt list --upgradable
```

При необходимости перезагрузить сервер:

```bash
reboot
```

## 4. Отключение входа по SSH-паролю

**Выполнять только после успешной проверки входа по SSH-ключу.**

Сначала убедиться, что:
- вход по ключу работает в отдельной SSH-сессии;
- публичный ключ добавлен в `authorized_keys`;
- есть доступ к консоли управления VPS у провайдера на случай проблем с SSH.

Скачать и запустить скрипт:

```bash
wget -q https://raw.githubusercontent.com/evgeny-ilyin/vps-setup/main/disable-password-auth.sh -O /root/disable-password-auth.sh && bash /root/disable-password-auth.sh
```

Скрипт должен отключать аутентификацию по паролю в SSH, сохраняя вход по ключу. После изменения настроек нужно проверить конфигурацию SSH и применить её безопасным способом.

> Важно: этот раздел рассчитан на наличие `disable-password-auth.sh` в репозитории. Перед запуском проверь содержимое скрипта и убедись, что он корректно обрабатывает настройки SSH именно на используемой системе.

После применения настроек **не закрывать существующую SSH-сессию**, пока не будет проверено новое подключение по ключу.

Скрипт:

- сохраняет резервную копию `/etc/ssh/sshd_config`;
- создаёт `/etc/ssh/sshd_config.d/00-disable-password-auth.conf`;
- отключает `PasswordAuthentication` и `KbdInteractiveAuthentication`;
- проверяет синтаксис конфигурации и итоговые параметры через `sshd -T`;
- применяет изменения через `systemctl reload ssh`, не требуя закрывать текущую сессию.

После запуска проверить настройки:

```bash
sshd -T | grep -E '^(permitrootlogin|pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication)'
```

Ожидаемый результат:

```text
permitrootlogin prohibit-password или without-password
pubkeyauthentication yes
passwordauthentication no
kbdinteractiveauthentication no
```

Если настройки не соответствуют ожидаемым, не закрывать текущую SSH-сессию и проверить конфигурацию вручную.


## 5. Просмотр скриптов перед запуском

Перед первым запуском можно скачать файл отдельно и посмотреть его содержимое:

```bash
wget -q https://raw.githubusercontent.com/evgeny-ilyin/vps-setup/main/setup.sh -O /root/setup.sh
less /root/setup.sh
```

Запуск после проверки:

```bash
bash /root/setup.sh
```

Для выхода из `less` нажать `q`.


## 6. Удаление скачанных скриптов

После успешной настройки сервера можно удалить локальные копии скриптов:

```bash
rm -f /root/add-ssh-keys.sh /root/setup.sh /root/disable-password-auth.sh
```


## Полезные команды

Проверить версию Ubuntu:

```bash
lsb_release -a
```

Проверить состояние SSH:

```bash
systemctl status ssh
```

Проверить итоговую SSH-конфигурацию:

```bash
sshd -T | grep -E '^(permitrootlogin|pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication)'
```

Посмотреть последние сообщения SSH:

```bash
journalctl -u ssh -n 50 --no-pager
```

## Безопасность

- В GitHub размещать только публичные SSH-ключи. Приватные ключи никогда не публиковать.
- Перед запуском скачанных скриптов с правами `root` проверять их содержимое.
- Не отключать парольную аутентификацию, пока вход по ключу не проверен.
- Хранить доступ к панели управления VPS у провайдера на случай потери SSH-доступа.

