#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

ENV_FILE="${1:-.env}"
COMPOSE_FILE="${2:-docker-compose.yml}"

if [ ! -f "$ENV_FILE" ]; then
  if [ -f ".env.example" ]; then
    log_warn ".env file not found. Copying from .env.example"
    cp .env.example "$ENV_FILE"
    log_info "Please edit $ENV_FILE with your values before running"
    exit 1
  else
    log_error ".env file not found and no .env.example available"
    exit 1
  fi
fi

log_info "Loading environment from $ENV_FILE"
set -a
source "$ENV_FILE"
set +a

ENV_MODE="${ENV_MODE:-dev}"

case "$ENV_MODE" in
  prod|production)
    COMPOSE_OVERRIDE="-f ${COMPOSE_FILE} -f docker-compose.prod.yml"
    SONAR_IMAGE="${SONAR_IMAGE:-sonarqube:community}"
    ;;
  dev|development)
    COMPOSE_OVERRIDE="-f ${COMPOSE_FILE} -f docker-compose.dev.yml"
    SONAR_IMAGE="${SONAR_IMAGE:-sonarqube:community}"
    ;;
  *)
    log_error "Unknown ENV_MODE: $ENV_MODE (use: dev, production)"
    exit 1
    ;;
esac

export SONAR_IMAGE

log_info "Starting SonarQube in $ENV_MODE mode..."

docker compose $COMPOSE_OVERRIDE up -d --remove-orphans

log_info "Waiting for SonarQube to become healthy..."
RETRIES=0
MAX_RETRIES=30
until curl -sf "http://localhost:${SONAR_HTTP_PORT:-9000}/api/system/health" > /dev/null 2>&1; do
  RETRIES=$((RETRIES + 1))
  if [ $RETRIES -ge $MAX_RETRIES ]; then
    log_error "SonarQube failed to start within expected time"
    docker compose $COMPOSE_OVERRIDE logs sonarqube --tail=50
    exit 1
  fi
  sleep 10
done

log_info "SonarQube is healthy and running!"
log_info "Access: http://localhost:${SONAR_HTTP_PORT:-9000}"
log_info "Default credentials: admin / admin"
log_warn "Change the default password immediately after first login!"
