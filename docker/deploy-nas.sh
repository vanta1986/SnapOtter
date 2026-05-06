#!/bin/bash
# ═══════════════════════════════════════════════════════
# SnapOtter NAS 一键部署脚本
# 适用于：威联通（QNAP）、绿联（UGREEN）、其他 Linux NAS
#
# 使用方法（复制整行到终端执行）：
#   curl -sL https://raw.githubusercontent.com/snapotter-hq/snapotter/i18n/zh/docker/deploy-nas.sh | bash -s -- --data-root /share/Container/snapotter
#
# 或者先下载脚本再运行：
#   curl -sO https://raw.githubusercontent.com/snapotter-hq/snapotter/i18n/zh/docker/deploy-nas.sh
#   chmod +x deploy-nas.sh
#   ./deploy-nas.sh --data-root /share/Container/snapotter
# ═══════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_ROOT="${DATA_ROOT:-}"
FORCE_REBUILD=false

# ── 参数解析 ──
while [[ $# -gt 0 ]]; do
  case $1 in
    --data-root)
      DATA_ROOT="$2"
      shift 2
      ;;
    --force-rebuild)
      FORCE_REBUILD=true
      shift
      ;;
    --help)
      echo "用法: $0 --data-root <NAS数据目录>"
      echo ""
      echo "示例（威联通）:"
      echo "  $0 --data-root /share/Container/snapotter"
      echo ""
      echo "示例（绿联）:"
      echo "  $0 --data-root /mnt/storage/snapotter"
      echo ""
      echo "选项:"
      echo "  --data-root       数据存储根目录（必须）"
      echo "  --force-rebuild  强制重新构建镜像（不清除缓存）"
      echo "  --help           显示此帮助"
      exit 0
      ;;
    *)
      echo "未知参数: $1"
      echo "使用 --help 查看帮助"
      exit 1
      ;;
  esac
done

# ── 前置检查 ──
if [[ -z "$DATA_ROOT" ]]; then
  echo "错误: 必须指定 --data-root"
  echo "使用 --help 查看帮助"
  exit 1
fi

# 检测是否在 NAS 上运行
IS_NAS=false
if [[ -d /share ]] || [[ -d /mnt/storage ]] || grep -q "QNAP" /etc/issue 2>/dev/null; then
  IS_NAS=true
  echo "[检测] 识别为 NAS 环境"
fi

# ── 创建目录 ──
echo "[1/5] 创建数据目录..."
mkdir -p "${DATA_ROOT}/snapotter/data"
mkdir -p "${DATA_ROOT}/snapotter/workspace"
echo "      数据根目录: ${DATA_ROOT}/snapotter"

# ── 下载 compose 文件 ──
echo "[2/5] 下载 docker-compose.yml..."
COMPOSE_URL="https://raw.githubusercontent.com/snapotter-hq/snapotter/i18n/zh/docker/docker-compose.nas.yml"
ENV_URL="https://raw.githubusercontent.com/snapotter-hq/snapotter/i18n/zh/docker/.env.nas.example"

cd "${DATA_ROOT}/snapotter"
if [[ ! -f docker-compose.nas.yml ]]; then
  curl -sL "$COMPOSE_URL" -o docker-compose.nas.yml
fi
if [[ ! -f .env ]]; then
  curl -sL "$ENV_URL" -o .env.nas.example
  cp .env.nas.example .env
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  请编辑 .env 文件，设置密码："
  echo "  nano ${DATA_ROOT}/snapotter/.env"
  echo "  找到 DEFAULT_PASSWORD=你的强密码"
  echo "  改为你的强密码后保存退出"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi

# ── 生成 .env from DATA_ROOT ──
sed -i "s|^DATA_ROOT=.*|DATA_ROOT=${DATA_ROOT}|" .env 2>/dev/null || true

# ── 构建并启动 ──
echo "[3/5] 构建 Docker 镜像（首次约 5-10 分钟）..."
BUILD_CMD="docker compose -f docker-compose.nas.yml build"
if [[ "$FORCE_REBUILD" == true ]]; then
  BUILD_CMD="$BUILD_CMD --no-cache"
fi
eval "$BUILD_CMD"

echo "[4/5] 启动容器..."
docker compose -f docker-compose.nas.yml up -d

echo "[5/5] 等待服务就绪..."
sleep 10

# ── 状态检查 ──
CONTAINER_STATUS=$(docker inspect -f '{{.State.Health.Status}}' SnapOtter 2>/dev/null || echo "unknown")
if [[ "$CONTAINER_STATUS" == "healthy" ]] || docker ps --format '{{.Names}}' | grep -q "^SnapOtter$"; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ✓ SnapOtter 部署成功！"
  echo ""
  echo "  访问地址：http://$(hostname -I | awk '{print $1}'):1349"
  echo "  默认账号：admin / admin（请立即修改密码）"
  echo ""
  echo "  常用命令："
  echo "    docker compose -f ${DATA_ROOT}/snapotter/docker-compose.nas.yml logs -f"
  echo "    docker compose -f ${DATA_ROOT}/snapotter/docker-compose.nas.yml restart"
  echo "    docker compose -f ${DATA_ROOT}/snapotter/docker-compose.nas.yml down"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
  echo ""
  echo "[错误] 容器启动失败，查看日志："
  docker compose -f docker-compose.nas.yml logs
  exit 1
fi
