#!/usr/bin/env bash
# Deploy / clean-restart layanan Docker (backend, frontend, atau keduanya)
# Jalankan dari root repo: ./deploy.sh help

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

COMPOSE=(docker compose)

# Warna (opsional, tanpa emoji agar aman di semua terminal)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[info]${NC} $*"; }
print_ok() { echo -e "${GREEN}[ok]${NC} $*"; }
print_warn() { echo -e "${YELLOW}[warn]${NC} $*"; }

usage() {
  cat <<'EOF'
Penggunaan:
  ./deploy.sh deploy [backend|frontend|all]      Build image + jalankan container (-d)
  ./deploy.sh restart [backend|frontend|all]      Clean restart: stop, hapus container & image,
                                                   prune ringan, rebuild, up --force-recreate
  ./deploy.sh restart-quick [backend|frontend|all] Restart cepat (docker compose restart saja)
  ./deploy.sh clean-restart [backend|frontend|all] Sama seperti restart
  ./deploy.sh stop [backend|frontend|all]         Stop container
  ./deploy.sh logs [backend|frontend]             Tail log (Ctrl+C keluar)
  ./deploy.sh ps                                  Status semua service

Contoh:
  ./deploy.sh deploy backend
  ./deploy.sh restart frontend
  ./deploy.sh restart all
EOF
}

service_arg() {
  local s="${1:-}"
  case "$s" in
    backend|frontend|all) echo "$s" ;;
    *) echo "Service tidak dikenal: ${s:-kosong}. Pakai: backend, frontend, atau all." >&2; exit 1 ;;
  esac
}

# Ambil image id untuk service (sebelum container dihapus lebih aman)
compose_image_id() {
  local svc="$1"
  "${COMPOSE[@]}" images -q "$svc" 2>/dev/null | head -n1 || true
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

# Restart cepat tanpa hapus image
cmd_restart_quick() {
  local svc
  svc="$(service_arg "${1:-}")"
  if [[ "$svc" == all ]]; then
    "${COMPOSE[@]}" restart backend frontend
  else
    "${COMPOSE[@]}" restart "$svc"
  fi
  print_ok "restart-quick selesai: $svc"
  "${COMPOSE[@]}" ps
}

# Satu service: stop → rm → rmi (urutan mirip core-gateaway)
clean_restart_one() {
  local s="$1"
  local id
  id="$(compose_image_id "$s")"

  print_info "Stop & hapus: $s"
  "${COMPOSE[@]}" stop "$s" || print_warn "Service $s mungkin tidak jalan"
  "${COMPOSE[@]}" rm -f "$s" || print_warn "Container $s mungkin sudah tidak ada"

  if [[ -n "$id" ]]; then
    if docker rmi -f "$id" 2>/dev/null; then
      print_ok "Image dihapus: $s ($id)"
    else
      print_warn "Tidak bisa hapus image $s (mungkin sudah tidak ada)"
    fi
  else
    print_warn "Tidak ada image id tercatat untuk $s — lewati rmi"
  fi
}

# Clean restart: mirip core-gateaway — stop, rm container, hapus image lokal, prune, rebuild, up
cmd_clean_restart() {
  local svc
  svc="$(service_arg "${1:-}")"

  echo ""
  print_info "Clean restart — target: $svc"
  echo ""

  print_info "1/6 Stop, hapus container, hapus image per service..."
  if [[ "$svc" == all ]]; then
    clean_restart_one backend
    echo ""
    clean_restart_one frontend
  else
    clean_restart_one "$svc"
  fi
  print_ok "Langkah 1–3 selesai"
  echo ""

  print_info "4/6 Prune resource tidak terpakai (docker system prune -f)..."
  docker system prune -f
  print_ok "Prune selesai"
  echo ""

  print_info "5/6 Rebuild --no-cache & up -d --force-recreate..."
  if [[ "$svc" == all ]]; then
    "${COMPOSE[@]}" build --no-cache
    "${COMPOSE[@]}" up -d --force-recreate
  else
    "${COMPOSE[@]}" build --no-cache "$svc"
    "${COMPOSE[@]}" up -d --force-recreate "$svc"
  fi
  print_ok "Build & up selesai"
  echo ""

  print_info "6/6 Tunggu sebentar agar proses siap..."
  sleep 3
  print_ok "Selesai: clean-restart $svc"
  echo ""
  "${COMPOSE[@]}" ps
  echo ""

  print_info "Log terakhir (30 baris per service):"
  if [[ "$svc" == all ]]; then
    echo "--- backend ---"
    "${COMPOSE[@]}" logs --tail=30 backend 2>/dev/null || true
    echo ""
    echo "--- frontend ---"
    "${COMPOSE[@]}" logs --tail=30 frontend 2>/dev/null || true
  else
    echo "--- $svc ---"
    "${COMPOSE[@]}" logs --tail=30 "$svc" 2>/dev/null || true
  fi
  echo ""
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
    deploy)         cmd_deploy "${2:-}" ;;
    restart)        cmd_clean_restart "${2:-}" ;;
    restart-quick)  cmd_restart_quick "${2:-}" ;;
    clean-restart)  cmd_clean_restart "${2:-}" ;;
    stop)           cmd_stop "${2:-}" ;;
    logs)           cmd_logs "${2:-}" ;;
    ps)             "${COMPOSE[@]}" ps ;;
    help|-h|--help|"") usage ;;
    *) echo "Perintah tidak dikenal: $1" >&2; usage; exit 1 ;;
  esac
}

main "$@"
