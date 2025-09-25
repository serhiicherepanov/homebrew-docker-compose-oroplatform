# OroDC: Поддержка Прокси Сертификатов

## Описание

OroDC поддерживает автоматическую установку пользовательских сертификатов в PHP контейнеры для работы с корпоративными прокси и внутренними CA.

## Как это работает

1. **Обнаружение**: OroDC автоматически проверяет папку `.crt` в корне проекта
2. **Сборка**: При наличии сертификатов создается проектный Docker образ на основе базового
3. **Установка**: Сертификаты устанавливаются в системное хранилище доверенных сертификатов Alpine Linux
4. **Конвертация**: PEM файлы автоматически конвертируются в CRT формат

## Использование

### 1. Добавление сертификатов

Создайте папку `.crt` в корне проекта и поместите туда сертификаты:

```bash
mkdir .crt
# Скопируйте ваши сертификаты
cp /path/to/corporate-ca.crt .crt/
cp /path/to/proxy-cert.pem .crt/
```

**Поддерживаемые форматы:**
- `.crt` - устанавливаются как есть
- `.pem` - автоматически конвертируются в `.crt`

### 2. Использование с сертификатами

#### Метод 1: Docker Compose Override (рекомендуется)

```bash
# Автоматическое использование при наличии .crt папки
orodc up -d

# Или явно указать использование сертификатов
docker-compose -f docker-compose.yml -f docker-compose.certs.yml up -d
```

#### Метод 2: Ручная сборка образа

```bash
# Используя включенный скрипт
./docker/php-node-symfony/build-project-image.sh \
  /path/to/project \
  ghcr.io/digitalspacestdio/orodc-php-node-symfony:8.4-22-2-alpine \
  my-project-php:latest

# Затем обновите docker-compose.yml для использования my-project-php:latest
```

### 3. Структура проекта

```
your-oro-project/
├── .crt/                           # Папка с сертификатами
│   ├── corporate-ca.crt           # Корпоративный CA
│   ├── proxy-cert.pem             # Прокси сертификат (PEM)
│   └── internal-ca.crt            # Внутренний CA
├── .env.orodc                     # Конфиг OroDC
├── docker-compose.yml             # Базовый compose
├── docker-compose.override.yml    # Ваши переопределения
└── ...                           # Остальные файлы проекта
```

## Автоматическая интеграция

OroDC автоматически:

1. **Определяет наличие сертификатов**:
   - Проверяет папку `.crt` при запуске
   - Подсчитывает количество `.crt` и `.pem` файлов

2. **Выбирает стратегию сборки**:
   - **Без сертификатов**: использует стандартные образы
   - **С сертификатами**: собирает проектные образы

3. **Устанавливает сертификаты**:
   - Копирует в `/usr/local/share/ca-certificates/`
   - Конвертирует PEM → CRT
   - Обновляет системное хранилище: `update-ca-certificates`

## Примеры использования

### Корпоративный прокси

```bash
# 1. Получите сертификат корпоративного прокси
curl -k https://proxy.company.com:8080/ca-cert > .crt/company-proxy.crt

# 2. Запустите проект
orodc up -d

# 3. Проверьте установку сертификатов
orodc ssh
ls -la /usr/local/share/ca-certificates/
```

### Внутренний CA

```bash
# 1. Добавьте внутренний CA сертификат
cp /etc/ssl/certs/internal-ca.crt .crt/

# 2. Пересоберите контейнеры
orodc down
orodc up -d --build

# 3. Тестируйте HTTPS соединения
orodc curl -I https://internal-api.company.local
```

### Множественные сертификаты

```bash
# Добавьте несколько сертификатов
cp corporate-ca.pem .crt/
cp proxy-intermediate.crt .crt/
cp root-ca.crt .crt/

# OroDC автоматически обработает все сертификаты
orodc up -d --build
```

## Отладка

### Проверка установленных сертификатов

```bash
# Войдите в контейнер
orodc ssh

# Посмотрите установленные сертификаты
ls -la /usr/local/share/ca-certificates/

# Проверьте системное хранилище
cat /etc/ssl/certs/ca-certificates.crt | grep -A5 -B5 "your-cert-name"

# Тестируйте SSL соединение
openssl s_client -connect example.com:443 -CApath /etc/ssl/certs/
```

### Логи сборки

```bash
# Просмотрите логи сборки образа
docker-compose -f docker-compose.yml -f docker-compose.certs.yml build fpm

# Детальные логи
docker build --no-cache \
  -f docker/php-node-symfony/Dockerfile.project-certs \
  --build-arg BASE_IMAGE=ghcr.io/digitalspacestdio/orodc-php-node-symfony:8.4-22-2-alpine \
  .
```

### Проблемы с сертификатами

```bash
# Проверьте формат сертификата
openssl x509 -in .crt/your-cert.crt -text -noout

# Проверьте PEM сертификат
openssl x509 -in .crt/your-cert.pem -text -noout

# Тестируйте HTTPS соединение с подробностями
orodc curl -v -I https://problematic-site.com
```

## Переменные окружения

```bash
# Отключить использование сертификатов (если нужно)
export DC_ORO_DISABLE_CUSTOM_CERTS=true

# Путь к папке сертификатов (по умолчанию: .crt)
export DC_ORO_CERTS_DIR=custom-certs

# Режим отладки сборки
export DC_ORO_BUILD_DEBUG=true
```

## Безопасность

⚠️  **Важные замечания по безопасности:**

1. **Не добавляйте .crt в Git** - добавьте в `.gitignore`:
   ```bash
   echo ".crt/" >> .gitignore
   ```

2. **Проверяйте сертификаты перед установкой**:
   ```bash
   openssl x509 -in .crt/cert.crt -text -noout
   ```

3. **Используйте минимально необходимые сертификаты** - не устанавливайте лишние CA

4. **Регулярно обновляйте сертификаты** при изменении корпоративной инфраструктуры

## Ограничения

- Поддерживаются только форматы `.crt` и `.pem`
- Сертификаты устанавливаются для всех PHP контейнеров (fpm, cli, consumer, websocket, ssh)
- Требует пересборку образов при добавлении новых сертификатов
- Работает только с Alpine Linux образами

## FAQ

**Q: Можно ли использовать .p12/.pfx сертификаты?**  
A: Нет, поддерживаются только .crt и .pem. Конвертируйте их:
```bash
openssl pkcs12 -in cert.p12 -out cert.pem -nodes
```

**Q: Как узнать, что сертификаты установлены?**  
A: Проверьте логи сборки или выполните в контейнере:
```bash
ls -la /usr/local/share/ca-certificates/
```

**Q: Работает ли с самоподписанными сертификатами?**  
A: Да, любые сертификаты в .crt/.pem формате будут установлены.

**Q: Можно ли отключить эту функцию?**  
A: Да, не создавайте папку .crt или используйте стандартный docker-compose.yml без override.

## Поддержка

При возникновении проблем:

1. Проверьте логи: `orodc logs fpm`
2. Проверьте сборку: `docker-compose build fpm --no-cache`
3. Войдите в контейнер: `orodc ssh` и проверьте `/usr/local/share/ca-certificates/`
4. Создайте issue с подробным описанием проблемы
