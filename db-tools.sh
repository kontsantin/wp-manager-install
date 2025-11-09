#!/bin/bash
# db-tools.sh
# Функции для работы с базами данных проектов WordPress

# Функция открытия базы данных проекта через mysql клиент
open_db_for_project() {
    local PROJECT_NAME="$1"
    local PROJECT_PATH="$2"

    if [[ -z "$PROJECT_NAME" || -z "$PROJECT_PATH" ]]; then
        echo -e "${RED}❌ Не указан проект или путь${NC}"
        return 1
    fi

    if [[ ! -d "$PROJECT_PATH" ]]; then
        echo -e "${RED}❌ Проект '$PROJECT_NAME' не найден в $PROJECT_PATH${NC}"
        return 1
    fi

    # Проверяем, запущен ли контейнер
    local DB_CONTAINER="${PROJECT_NAME}_db"
    if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
        echo -e "${YELLOW}⚠ Контейнер базы данных '$DB_CONTAINER' не запущен${NC}"
        echo -e "${BLUE}Запустите проект сначала: wpmanager -> 3) Запустить проект${NC}"
        return 1
    fi

    # Читаем информацию о БД из .project-info
    local PROJECT_INFO_FILE="$PROJECT_PATH/.project-info"
    if [[ ! -f "$PROJECT_INFO_FILE" ]]; then
        echo -e "${RED}❌ Файл с информацией о проекте не найден${NC}"
        return 1
    fi

    # Извлекаем данные БД
    local DB_NAME=$(grep "^DB_NAME=" "$PROJECT_INFO_FILE" | cut -d'=' -f2)
    local DB_USER=$(grep "^DB_USER=" "$PROJECT_INFO_FILE" | cut -d'=' -f2)
    local DB_PASS=$(grep "^DB_PASS=" "$PROJECT_INFO_FILE" | cut -d'=' -f2)

    if [[ -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_PASS" ]]; then
        echo -e "${RED}❌ Не удалось получить данные базы данных${NC}"
        return 1
    fi

    echo -e "${BLUE}🔗 Подключение к базе данных проекта '$PROJECT_NAME'...${NC}"
    echo -e "${YELLOW}База данных: $DB_NAME${NC}"
    echo -e "${YELLOW}Пользователь: $DB_USER${NC}"
    echo -e "${YELLOW}Пароль: $DB_PASS${NC}"
    echo ""
    echo -e "${GREEN}Подключение к MySQL... (для выхода: exit или Ctrl+D)${NC}"
    echo ""

    # Подключаемся к MySQL в контейнере
    docker exec -it "$DB_CONTAINER" mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME"
}

# Функция добавления phpMyAdmin в docker-compose для веб-доступа к БД
add_phpmyadmin_to_project() {
    local PROJECT_NAME="$1"
    local PROJECT_PATH="$2"

    if [[ -z "$PROJECT_NAME" || -z "$PROJECT_PATH" ]]; then
        echo -e "${RED}❌ Не указан проект или путь${NC}"
        return 1
    fi

    local COMPOSE_FILE="$PROJECT_PATH/docker-compose.yml"
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        echo -e "${RED}❌ docker-compose.yml не найден${NC}"
        return 1
    fi

    # Проверяем, есть ли уже phpMyAdmin
    if grep -q "phpmyadmin:" "$COMPOSE_FILE"; then
        echo -e "${YELLOW}⚠ phpMyAdmin уже добавлен в проект${NC}"
        return 0
    fi

    # Получаем свободный порт для phpMyAdmin
    local PMA_PORT=8080
    while docker ps --format '{{.Ports}}' | grep -q ":${PMA_PORT}->"; do
        ((PMA_PORT++))
    done

    echo -e "${BLUE}➕ Добавление phpMyAdmin в docker-compose.yml...${NC}"

    # Добавляем сервис phpMyAdmin в docker-compose.yml
    cat >> "$COMPOSE_FILE" <<YAML

  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    restart: unless-stopped
    depends_on:
      - db
    ports:
      - "${PMA_PORT}:80"
    environment:
      PMA_HOST: db
      PMA_PORT: 3306
    networks:
      - wp_network
YAML

    echo -e "${GREEN}✅ phpMyAdmin добавлен${NC}"
    echo -e "${BLUE}Перезапустите проект для применения изменений:${NC}"
    echo -e "  cd $PROJECT_PATH && docker compose down && docker compose up -d"
    echo ""
    echo -e "${GREEN}🌍 Доступ к phpMyAdmin: http://localhost:${PMA_PORT}${NC}"
    echo -e "${YELLOW}Сервер: db (уже настроено)${NC}"
    echo -e "${YELLOW}Пользователь: [из .project-info]${NC}"
    echo -e "${YELLOW}Пароль: [из .project-info]${NC}"
    echo -e "${YELLOW}База данных: [из .project-info]${NC}"
}

# Экспортируем функции
export -f open_db_for_project
export -f add_phpmyadmin_to_project