#!/usr/bin/env bash
# Deploy / restart layanan Docker (backend, frontend, atau keduanya)
# Jalankan dari root repo: ./deploy.sh help

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

COMPOSE=(docker compose)

usage() {
  cat <<'EOF'
Penggunaan:
  ./deploy.sh deploy [backend|frontend|all]   Build image + jalankan container (-d)
  ./deploy.sh restart [backend|frontend|all]  Restart container yang sudah jalan
  ./deploy.sh stop [backend|frontend|all]     Stop container
  ./deploy.sh logs [backend|frontend]         Tail log (Ctrl+C keluar)
  ./deploy.sh ps                              Status semua service

Contoh:
  ./deploy.sh deploy backend
  ./deploy.sh restart frontend
  ./deploy.sh deploy all
EOF
}

service_arg() {
  local s="${1:-}"
  case "$s" in
    backend|frontend|all) echo "$s" ;;
    *) echo "Service tidak dikenal: ${s:-kosong}. Pakai: backend, frontend, atau all." >&2; exit 1 ;;
  esac
}

cmd_deploy() {
  local svc
  svc="$(service_arg "${1:-}")"
  if [[ "$svc" == all ]]; then
    "${COMPOSE[@]}" build
    "${COMPOSE[@]}" up -d
  else
    "${COMPOSE[@]}" build "$svc"
    "${COMPOSE[@]}" up -d "$svc"
  fi
  echo "Selesai: deploy $svc"
  "${COMPOSE[@]}" ps
}

cmd_restart() {
  local svc
  svc="$(service_arg "${1:-}")"
  if [[ "$svc" == all ]]; then
    "${COMPOSE[@]}" restart backend frontend
  else
    "${COMPOSE[@]}" restart "$svc"
  fi
  echo "Selesai: restart $svc"
  "${COMPOSE[@]}" ps
}

cmd_stop() {
  local svc
  svc="$(service_arg "${1:-}")"
  if [[ "$svc" == all ]]; then
    "${COMPOSE[@]}" stop
  else
    "${COMPOSE[@]}" stop "$svc"
  fi
  echo "Selesai: stop $svc"
}

cmd_logs() {
  local svc="${1:-}"
  case "$svc" in
    backend|frontend) "${COMPOSE[@]}" logs -f "$svc" ;;
    *) echo "Pakai: ./deploy.sh logs backend   atau   ./deploy.sh logs frontend" >&2; exit 1 ;;
  esac
}

main() {
  case "${1:-}" in
    deploy)   cmd_deploy "${2:-}" ;;
    restart)  cmd_restart "${2:-}" ;;
    stop)     cmd_stop "${2:-}" ;;
    logs)     cmd_logs "${2:-}" ;;
    ps)       "${COMPOSE[@]}" ps ;;
    help|-h|--help|"") usage ;;
    *) echo "Perintah tidak dikenal: $1" >&2; usage; exit 1 ;;
  esac
}

main "$@"
