#!/usr/bin/env bash
# ============================================================
# EverMade Bank — установочный скрипт
# ============================================================
# Ученик запускает одну команду:
#   curl -sSL https://raw.githubusercontent.com/SaniOneOne/evermade-bank/main/install.sh | bash
# ============================================================

set -e

REPO_URL="https://github.com/SaniOneOne/evermade-bank.git"
INSTALL_DIR="${EMBANK_DIR:-$HOME/evermade-bank}"

echo "╔════════════════════════════════════════════╗"
echo "║   EverMade Bank — установка                ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# --- проверки окружения ---
if ! command -v docker &> /dev/null; then
  echo "❌ Docker не установлен."
  echo "   Установи Docker Desktop (Windows/macOS) или Docker Engine (Linux)."
  exit 1
fi

if ! docker compose version &> /dev/null; then
  echo "❌ Docker Compose (v2) не найден."
  echo "   Обнови Docker Desktop или установи плагин docker-compose-plugin."
  exit 1
fi

if ! command -v git &> /dev/null; then
  echo "❌ Git не установлен."
  echo "   Linux/WSL: sudo apt update && sudo apt install -y git"
  exit 1
fi

# --- клонирование/обновление ---
if [ -d "$INSTALL_DIR" ]; then
  echo "📂 Папка $INSTALL_DIR уже существует. Обновляю..."
  cd "$INSTALL_DIR"
  git pull
else
  echo "📥 Клонирую репозиторий в $INSTALL_DIR..."
  git clone "$REPO_URL" "$INSTALL_DIR"
  cd "$INSTALL_DIR"
fi

# --- .env ---
if [ ! -f .env ]; then
  echo "📝 Создаю .env..."
  cat > .env << 'ENV_END'
PROJECT_NAME=evermade-bank
DOCKER_ID=emschool

UI_PORT=2010
API_PORT=2020
PG_PORT=2030
KAFKA_PORT=2040
PROM_PORT=2050
GRAFANA_PORT=2060
KAFKA_EXPORTER_PORT=2070
CADVISOR_PORT=2080
PG_EXPORTER_PORT=2090

POSTGRES_USER=evermade
POSTGRES_PASSWORD=evermade
POSTGRES_DB=evermade_bank

GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin
ENV_END
fi

# --- запуск ---
echo ""
echo "🚀 Запускаю контейнеры (может занять 1-3 минуты при первом запуске)..."
docker compose up -d

# --- ждём UI ---
echo ""
echo "⏳ Жду готовности UI..."
READY=0
for i in $(seq 1 60); do
  if curl -s -o /dev/null -w "%{http_code}" http://localhost:2010 2>/dev/null | grep -qE "200|301|302|304"; then
    READY=1
    break
  fi
  sleep 2
done

# --- финальный отчёт ---
echo ""
if [ "$READY" = "1" ]; then
  echo "╔════════════════════════════════════════════╗"
  echo "║   ✅  EverMade Bank запущен!               ║"
  echo "╚════════════════════════════════════════════╝"
else
  echo "⚠  UI не ответил за 120 секунд. Проверь логи:"
  echo "   cd $INSTALL_DIR && docker compose logs --tail=50"
fi

echo ""
echo "  🌐 UI:           http://localhost:2010   (alice / alice)"
echo "  📚 Swagger:      http://localhost:2020/docs"
echo "  📊 Grafana:      http://localhost:2060   (admin / admin)"
echo "  📈 Prometheus:   http://localhost:2050"
echo "  🗄  Postgres:     localhost:2030          (evermade / evermade)"
echo "  🎯 Kafka:        localhost:2040"
echo ""
echo "  Папка:           $INSTALL_DIR"
echo "  Остановить:      cd $INSTALL_DIR && docker compose down"
echo "  Сбросить БД:     cd $INSTALL_DIR && make reset-db"
echo "  Логи:            cd $INSTALL_DIR && make logs"
echo ""
