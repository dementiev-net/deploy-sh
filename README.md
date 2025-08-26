# Скрипты деплоя из Git репозитория на боевой сервер через ZIP архивы

Эта система состоит из двух Bash-скриптов, которые позволяют безопасно и контролируемо переносить изменения из последнего Git коммита на боевой сервер:

- **pack_changes.sh** - упаковывает измененные файлы из последнего коммита в ZIP архив
- **deploy_changes.sh** - распаковывает архив на боевом сервере с проверками и созданием бэкапов

## Требования

### Для pack_changes.sh (машина разработчика):
- macOS или Linux
- Git
- Утилиты `zip/unzip`
- Bash 4.0+

### Для deploy_changes.sh (боевой сервер):
- Linux/Unix система
- Утилита `unzip`
- Bash 4.0+
- `diff` (опционально, для показа различий)

## Установка

1. Скачайте оба скрипта в нужные директории

2. Сделайте их исполняемыми:
```bash
chmod +x pack_changes.sh
chmod +x deploy_changes.sh
```

## Настройка

### pack_changes.sh

Отредактируйте переменные в начале скрипта:

```bash
# Директория для сохранения архивов
OUTPUT_DIR="./deploy"

# Формат имени ZIP файла
ZIP_NAME="changes_$(date +%Y%m%d_%H%M%S).zip"

# Путь к Git репозиторию (по умолчанию текущая директория)
GIT_REPO_PATH="$(pwd)"
```

### deploy_changes.sh

Отредактируйте переменные в начале скрипта:

```bash
# Целевая директория по умолчанию
DEFAULT_TARGET_DIR="/var/www/html"

# Директория для бэкапов
BACKUP_DIR="./backup"

# Файл лога
LOG_FILE="./deploy.log"
```

## Использование

### Шаг 1: Упаковка изменений (на машине разработчика)

```bash
cd /path/to/your/git/repository
./pack_changes.sh
```

**Что происходит:**
- Анализируется последний Git коммит
- Определяются все измененные файлы
- Создается ZIP архив с временной меткой
- Генерируется файл с информацией о коммите
- Файлы сохраняются в директории `./deploy/`

**Результат:**
```
deploy/
├── changes_20231201_143022.zi
└── commit_info.txt
```

### Шаг 2: Деплой на боевой сервер

```bash
./deploy_changes.sh path/to/changes.zip [target_directory]
```

**Примеры:**
```bash
# Деплой в директорию по умолчанию (/var/www/html)
./deploy_changes.sh ./changes_20231201_143022.zip

# Деплой в конкретную директорию
./deploy_changes.sh ./changes_20231201_143022.zip /var/www/my-site

# С полным путем
./deploy_changes.sh /home/user/deploy/changes_20231201_143022.zip /var/www/html
```

**Что происходит:**
- Показывается содержимое архива
- Запрашивается подтверждение деплоя
- Для каждого файла:
  - Проверяется существование на сервере
  - Показываются различия (если файл существует)
  - Запрашивается разрешение на перезапись
  - Создается бэкап (перед перезаписью)
  - Файл копируется в целевую директорию
- Ведется подробный лог операций

## Структура файлов

```
project/
├── pack_changes.sh          # Скрипт упаковки
├── deploy_changes.sh        # Скрипт деплоя
├── deploy/                  # Созданные архивы (создается автоматически)
│   ├── changes_YYYYMMDD_HHMMSS.zip
│   └── commit_info.txt
├── backup/                  # Бэкапы файлов (создается на сервере)
│   ├── index.html_20231201_143022
│   └── style.css_20231201_143025
└── deploy.log               # Лог деплоя (создается на сервере)
```

## Примеры использования

### Базовый workflow

1. **Разработчик делает изменения:**
```bash
git add .
git commit -m "Исправление багов в header"
./pack_changes.sh
```

2. **Копирование на сервер:**
```bash
scp deploy/changes_*.zip deploy/commit_info.txt user@server:/tmp/
scp deploy_changes.sh user@server:/tmp/
```

3. **Деплой на сервере:**
```bash
ssh user@server
cd /tmp
./deploy_changes.sh changes_20231201_143022.zip /var/www/html
```

### Автоматизация с помощью CI/CD

Можно интегрировать в GitHub Actions, GitLab CI или другие CI/CD системы:

```yaml
# Пример для GitHub Actions
- name: Pack changes
  run: ./pack_changes.sh

- name: Upload to server
  run: |
    scp deploy/changes_*.zip server:/tmp/
    ssh server "cd /tmp && ./deploy_changes.sh changes_*.zip"
```

### Отладка

Для подробной отладки добавьте в начало скрипта:
```bash
set -x  # Показать выполняемые команды
set -e  # Остановиться при первой ошибке
```

## Лицензия

MIT License - используйте и модифицируйте свободно.