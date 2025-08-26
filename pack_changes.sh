#!/bin/bash

# ============================================
# Скрипт для упаковки измененных файлов из последнего Git commit
# Использование: ./pack_changes.sh
# Версия: 1.0
# ============================================

# Настройки (можно изменить под ваши нужды)
OUTPUT_DIR="./deploy"
ZIP_NAME="changes_$(date +%Y%m%d_%H%M%S).zip"
GIT_REPO_PATH="$(pwd)"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# =====================================================
# ФУНКЦИИ ДЛЯ ВЫВОДА СООБЩЕНИЙ
# =====================================================
log_info() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${RED}[ERROR]${NC} $1"
}

# =====================================================
# ОСНОВНОЙ СКРИПТ
# =====================================================

# Проверка, что мы находимся в Git репозитории
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    log_error "Текущая директория не является Git репозиторием!"
    exit 1
fi

# Проверка наличия коммитов
if ! git rev-parse HEAD > /dev/null 2>&1; then
    log_error "В репозитории нет коммитов!"
    exit 1
fi

# Получаем хэш последнего коммита
LAST_COMMIT=$(git rev-parse HEAD)
log_info "Последний коммит: $LAST_COMMIT"

# Получаем список измененных файлов в последнем коммите
CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r $LAST_COMMIT)

if [ -z "$CHANGED_FILES" ]; then
    log_warning "В последнем коммите нет измененных файлов"
    exit 0
fi

log_info "Найденные измененные файлы:"
echo "$CHANGED_FILES" | while read file; do
    echo "  - $file"
done

# Создаем директорию для вывода, если её нет
mkdir -p "$OUTPUT_DIR"

# Создаем временную директорию для подготовки файлов
TEMP_DIR=$(mktemp -d)
log_info "Временная директория: $TEMP_DIR"

# Копируем измененные файлы с сохранением структуры директорий
echo "$CHANGED_FILES" | while read file; do
    if [ -f "$file" ]; then
        # Создаем необходимые директории в временной папке
        mkdir -p "$TEMP_DIR/$(dirname "$file")"
        # Копируем файл
        cp "$file" "$TEMP_DIR/$file"
        log_info "Скопирован: $file"
    else
        log_warning "Файл не найден (возможно, удален): $file"
    fi
done

# Переходим в временную директорию и создаем архив
cd "$TEMP_DIR"

# Создаем ZIP архив
if zip -r "$GIT_REPO_PATH/$OUTPUT_DIR/$ZIP_NAME" . > /dev/null 2>&1; then
    log_info "Архив создан: $OUTPUT_DIR/$ZIP_NAME"
    
    # Показываем содержимое архива
    log_info "Содержимое архива:"
    unzip -l "$GIT_REPO_PATH/$OUTPUT_DIR/$ZIP_NAME"
    
    # Создаем файл с информацией о коммите
    cat > "$GIT_REPO_PATH/$OUTPUT_DIR/commit_info.txt" << EOF
Commit Hash: $LAST_COMMIT
Commit Date: $(git show -s --format=%ci $LAST_COMMIT)
Commit Author: $(git show -s --format=%an $LAST_COMMIT)
Commit Message: $(git show -s --format=%s $LAST_COMMIT)
Archive Created: $(date)
Archive Name: $ZIP_NAME
EOF
    
    log_info "Информация о коммите сохранена: $OUTPUT_DIR/commit_info.txt"
else
    log_error "Ошибка при создании архива!"
    cd "$GIT_REPO_PATH"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Возвращаемся в исходную директорию и удаляем временную
cd "$GIT_REPO_PATH"
rm -rf "$TEMP_DIR"

log_info "Готово! Файлы упакованы в: $OUTPUT_DIR/$ZIP_NAME"
echo ""
echo "Для деплоя скопируйте следующие файлы на боевой сервер:"
echo "  - $OUTPUT_DIR/$ZIP_NAME"
echo "  - $OUTPUT_DIR/commit_info.txt"
echo "  - deploy_changes.sh (скрипт для распаковки)"