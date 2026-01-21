# Переход на Wildcard SSL сертификат

## Цель

Заменить автоматическое получение SSL сертификатов через Let's Encrypt на использование купленного wildcard сертификата `*.aviatx.ru`.

## Входные данные

- **Формат сертификата:** Отдельные файлы `.crt` и `.key`
- **Домен:** `*.aviatx.ru`
- **Метод доставки:** Ручное копирование на сервер перед деплоем

## Изменения в инфраструктуре

### Что удаляется

- Контейнер `nginx-proxy-letsencrypt` (jrcs/letsencrypt-nginx-proxy-companion)
- Docker volume `acme`
- Переменные `SSL_TEST`, `_letsencrypt_test`
- Файл `templates/env_proxy.yml.j2` (или его содержимое)

### Что добавляется

- Директория `/srv/aviatx/ssl/` для хранения сертификатов
- Монтирование сертификатов в nginx-proxy
- Проверка наличия сертификатов перед деплоем

## Структура сертификатов на сервере

```
/srv/aviatx/ssl/
├── app.aviatx.ru.crt    # Сертификат (включая chain)
└── app.aviatx.ru.key    # Приватный ключ
```

**Важно:** Файлы должны называться по имени домена (VIRTUAL_HOST):
- Для `app.aviatx.ru`: `app.aviatx.ru.crt` и `app.aviatx.ru.key`
- Для `test.aviatx.ru`: `test.aviatx.ru.crt` и `test.aviatx.ru.key`

При использовании wildcard сертификата можно использовать один и тот же файл под разными именами (символические ссылки или копии).

## Инструкция для администратора

### Подготовка сертификата

1. Убедитесь, что сертификат в формате PEM (текстовый, начинается с `-----BEGIN CERTIFICATE-----`)

2. Если есть intermediate/chain сертификаты, объедините их:
   ```bash
   cat wildcard.crt intermediate.crt root.crt > combined.crt
   ```

3. Скопируйте файлы на сервер:
   ```bash
   scp combined.crt user@server:/srv/aviatx/ssl/app.aviatx.ru.crt
   scp wildcard.key user@server:/srv/aviatx/ssl/app.aviatx.ru.key
   ```

4. Установите правильные права:
   ```bash
   chmod 600 /srv/aviatx/ssl/*.key
   chmod 644 /srv/aviatx/ssl/*.crt
   chown root:root /srv/aviatx/ssl/*
   ```

### Деплой

1. Запустите `aviatx` или `setup.sh`
2. Выберите "Full Install"
3. Скрипт проверит наличие сертификатов и продолжит деплой

### Обновление сертификата

При обновлении wildcard сертификата (обычно раз в год):

1. Загрузите новые файлы в `/srv/aviatx/ssl/`
2. Перезапустите nginx-proxy:
   ```bash
   docker restart nginx-proxy
   ```

## Миграция с Let's Encrypt

При обновлении существующей установки:

1. Загрузите wildcard сертификат в `/srv/aviatx/ssl/`
2. Запустите `aviatx` → "Full Install"
3. Старый контейнер `letsencrypt` будет удалён автоматически
4. Volume `acme` можно удалить вручную:
   ```bash
   docker volume rm aviatx_acme
   ```

## Использование одного wildcard для нескольких поддоменов

Если нужно использовать один wildcard сертификат для нескольких инстансов (app.aviatx.ru, test.aviatx.ru и т.д.), создайте символические ссылки:

```bash
cd /srv/aviatx/ssl/

# Основные файлы
cp wildcard.crt aviatx.ru.crt
cp wildcard.key aviatx.ru.key

# Символические ссылки для поддоменов
ln -s aviatx.ru.crt app.aviatx.ru.crt
ln -s aviatx.ru.key app.aviatx.ru.key

ln -s aviatx.ru.crt test.aviatx.ru.crt
ln -s aviatx.ru.key test.aviatx.ru.key
```

## Проверка SSL

После деплоя проверьте корректность SSL:

```bash
# Проверка сертификата
openssl s_client -connect app.aviatx.ru:443 -servername app.aviatx.ru < /dev/null 2>/dev/null | openssl x509 -noout -dates

# Проверка цепочки сертификатов
curl -vI https://app.aviatx.ru 2>&1 | grep -A 6 "Server certificate"
```

## Ожидаемый результат

- Контейнер `letsencrypt` не запускается
- nginx-proxy использует сертификаты из `/srv/aviatx/ssl/`
- HTTPS работает с wildcard сертификатом
- Деплой не запустится без предварительного размещения сертификатов
