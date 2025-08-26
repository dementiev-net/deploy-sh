#!/bin/bash

# ============================================
# Скрипт для распаковки и деплоя измененных файлов
# Использование: ./deploy_changes.sh [path_to_zip_file] [target_directory]
# Версия: 1.0
# ============================================

# Настройки по умолчанию (можно изменить)
DEFAULT_TARGET_DIR="/var/www/html"  # Путь к боевому сайту
BACKUP_DIR="./backup"
LOG_FILE="./deploy.log"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =====================================================
# ФУНКЦИИ ДЛЯ ВЫВОДА СООБЩЕНИЙ
# =====================================================
log_info() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
    echo -e "${GREEN}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

log_warning() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1"
    echo -e "${YELLOW}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

log_error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    echo -e "${RED}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

log_question() {
    echo -e "${BLUE}$1${NC}"
}

# =====================================================
# ФУНКЦИЯ ДЛЯ СОЗДАНИЯ БЭКАПА ФАЙЛА
# =====================================================
create_backup() {
    local file_path="$1"
    local backup_timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/$(basename "$file_path")_$backup_timestamp"
    
    mkdir -p "$BACKUP_DIR"
    
    if cp "$file_path" "$backup_file" 2>/dev/null; then
        log_info "Создан бэкап: $backup_file"
        return 0
    else
        log_error "Не удалось создать бэкап для $file_path"
        return 1
    fi
}

# =====================================================
# ФУНКЦИЯ ДЛЯ ПОДТВЕРЖДЕНИЯ ДЕЙСТВИЯ
# =====================================================
confirm_action() {
    local prompt="$1"
    local default="${2:-n}"
    
    while true; do
        log_question "$prompt (y/n) [default: $default]: "
        read -r response
        
        # Если ответ пустой, используем значение по умолчанию
        if [ -z "$response" ]; then
            response="$default"
        fi
        
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                log_warning "Пожалуйста, введите 'y' или 'n'"
                ;;
        esac
    done
}

# =====================================================
# ОСНОВНОЙ СКРИПТ
# =====================================================

# Проверка аргументов
if [ $# -lt 1 ]; then
    log_error "Использование: $0 <путь_к_zip_файлу> [целевая_директория]"
    echo "Пример: $0 ./deploy/changes_20231201_143022.zip /var/www/html"
    exit 1
fi

ZIP_FILE="$1"
TARGET_DIR="${2:-$DEFAULT_TARGET_DIR}"

# Проверка существования ZIP файла
if [ ! -f "$ZIP_FILE" ]; then
    log_error "ZIP файл не найден: $ZIP_FILE"
    exit 1
fi

# Проверка целевой директории
if [ ! -d "$TARGET_DIR" ]; then
    log_error "Целевая директория не существует: $TARGET_DIR"
    if confirm_action "Создать директорию $TARGET_DIR?"; then
        mkdir -p "$TARGET_DIR"
        log_info "Создана директория: $TARGET_DIR"
    else
        exit 1
    fi
fi

log_info "Начинаем деплой из $ZIP_FILE в $TARGET_DIR"

# Показываем содержимое архива
log_info "Содержимое архива:"
unzip -l "$ZIP_FILE"

if ! confirm_action "Продолжить деплой?"; then
    log_info "Деплой отменен пользователем"
    exit 0
fi

# Создаем временную директорию для распаковки
TEMP_DIR=$(mktemp -d)
log_info "Временная директория: $TEMP_DIR"

# Распаковываем архив во временную директорию
if ! unzip -q "$ZIP_FILE" -d "$TEMP_DIR"; then
    log_error "Ошибка при распаковке архива"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Получаем список всех файлов из архива
FILES_TO_DEPLOY=$(find "$TEMP_DIR" -type f -exec realpath --relative-to="$TEMP_DIR" {} \;)

# Проверяем каждый файл и спрашиваем разрешение на перезапись
for file in $FILES_TO_DEPLOY; do
    source_file="$TEMP_DIR/$file"
    target_file="$TARGET_DIR/$file"
    
    log_info "Обработка файла: $file"
    
    if [ -f "$target_file" ]; then
        log_warning "Файл уже существует: $target_file"
        
        # Показываем различия если возможно
        if command -v diff >/dev/null 2>&1; then
            echo -e "\n${YELLOW}Различия между файлами:${NC}"
            if ! diff -u "$target_file" "$source_file"; then
                echo "Файлы отличаются"
            else
                log_info "Файлы идентичны"
                continue
            fi
            echo ""
        fi
        
        if confirm_action "Перезаписать $target_file?" "y"; then
            # Создаем бэкап перед перезаписью
            if create_backup "$target_file"; then
                # Создаем директорию если нужно
                mkdir -p "$(dirname "$target_file")"
                
                if cp "$source_file" "$target_file"; then
                    log_info "Файл обновлен: $target_file"
                else
                    log_error "Ошибка при копировании файла: $target_file"
                fi
            else
                log_warning "Файл пропущен из-за ошибки создания бэкапа: $target_file"
            fi
        else
            log_info "Файл пропущен: $target_file"
        fi
    else
        # Файл не существует, просто копируем
        mkdir -p "$(dirname "$target_file")"
        
        if cp "$source_file" "$target_file"; then
            log_info "Новый файл создан: $target_file"
        else
            log_error "Ошибка при создании файла: $target_file"
        fi
    fi
done

# Удаляем временную директорию
rm -rf "$TEMP_DIR"

# Проверяем наличие файла с информацией о коммите
COMMIT_INFO_FILE="$(dirname "$ZIP_FILE")/commit_info.txt"
if [ -f "$COMMIT_INFO_FILE" ]; then
    log_info "Информация о коммите:"
    cat "$COMMIT_INFO_FILE"
fi

log_info "Деплой завершен!"
log_info "Лог сохранен в: $LOG_FILE"
log_info "Бэкапы сохранены в: $BACKUP_DIR"

# Показываем статистику
echo ""
echo -e "${GREEN}=== СТАТИСТИКА ДЕПЛОЯ ===${NC}"
echo "ZIP файл: $ZIP_FILE"
echo "Целевая директория: $TARGET_DIR"
echo "Время деплоя: $(date)"
echo "Лог файл: $LOG_FILE"