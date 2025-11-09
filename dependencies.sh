#!/bin/bash
# dependencies.sh
# Проверка и установка зависимостей: VS Code и Docker

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция проверки и установки VS Code
check_vscode() {
    echo -e "${BLUE}Проверка VS Code...${NC}"
    if command -v code >/dev/null 2>&1; then
        echo -e "${GREEN}✅ VS Code найден${NC}"
        return 0
    fi

    echo -e "${YELLOW}⚠ VS Code не найден. Попытка установки...${NC}"

    # Попытка установки через snap (для Ubuntu/Debian)
    if command -v snap >/dev/null 2>&1; then
        echo -e "${BLUE}Установка VS Code через snap...${NC}"
        sudo snap install code --classic
        if command -v code >/dev/null 2>&1; then
            echo -e "${GREEN}✅ VS Code установлен через snap${NC}"
            return 0
        fi
    fi

    # Попытка установки через apt
    if command -v apt >/dev/null 2>&1; then
        echo -e "${BLUE}Установка VS Code через apt...${NC}"
        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
        sudo apt update
        sudo apt install -y code
        if command -v code >/dev/null 2>&1; then
            echo -e "${GREEN}✅ VS Code установлен через apt${NC}"
            return 0
        fi
    fi

    echo -e "${RED}❌ Не удалось установить VS Code автоматически${NC}"
    echo -e "${YELLOW}Установите VS Code вручную:${NC}"
    echo -e "  - Скачайте с https://code.visualstudio.com/download"
    echo -e "  - Или в Windows: установите VS Code и добавьте в PATH"
    echo -e "  - В WSL: code --version должен работать"
    return 1
}

# Функция проверки и установки Docker
check_docker() {
    echo -e "${BLUE}Проверка Docker...${NC}"
    if command -v docker >/dev/null 2>&1 && docker --version >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker найден${NC}"
        return 0
    fi

    echo -e "${YELLOW}⚠ Docker не найден. Попытка установки...${NC}"

    # Попытка установки Docker через apt (для Ubuntu/Debian)
    if command -v apt >/dev/null 2>&1; then
        echo -e "${BLUE}Установка Docker через apt...${NC}"
        sudo apt update
        sudo apt install -y ca-certificates curl gnupg lsb-release
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
        if command -v docker >/dev/null 2>&1 && docker --version >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Docker установлен${NC}"
            echo -e "${YELLOW}ℹ Перезагрузите терминал или выполните 'newgrp docker' для применения группы${NC}"
            return 0
        fi
    fi

    echo -e "${RED}❌ Не удалось установить Docker автоматически${NC}"
    echo -e "${YELLOW}Установите Docker вручную:${NC}"
    echo -e "  - Скачайте Docker Desktop для Windows: https://www.docker.com/products/docker-desktop"
    echo -e "  - Или установите docker-ce в WSL: следуйте инструкциям на https://docs.docker.com/engine/install/ubuntu/"
    return 1
}

# Основная функция проверки зависимостей
check_dependencies() {
    local missing_deps=0

    if ! check_vscode; then
        ((missing_deps++))
    fi

    if ! check_docker; then
        ((missing_deps++))
    fi

    if [[ $missing_deps -gt 0 ]]; then
        echo -e "${RED}❌ Некоторые зависимости не установлены. Продолжить? (y/N)${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}👋 Выход${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✅ Все зависимости установлены${NC}"
    fi
}

# Экспорт функции для использования в других скриптах
export -f check_dependencies