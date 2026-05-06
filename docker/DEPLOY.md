# SnapOtter 部署指南

## 架构说明

当前 API 使用 SQLite（`better-sqlite3`），非 PostgreSQL。生产部署使用单一容器 + 外置数据卷。

```
┌─────────────────────────────────────────┐
│           Docker Network               │
│                                         │
│  ┌──────────┐   ┌───────────────────┐  │
│  │ PostgreSQL│ ← │   SnapOtter 容器   │  │
│  │  (可选)  │   │  API (:1349)       │  │
│  └──────────┘   │  Web (静态文件)     │  │
│                 └───────────────────┘  │
│                                         │
│  ┌────────┐  ┌────────┐  ┌──────────┐  │
│  │  Redis │  │  数据卷 │  │ 工作空间  │  │
│  │ (可选) │  │(files) │  │(workspace)│ │
│  └────────┘  └────────┘  └──────────┘  │
└─────────────────────────────────────────┘
```

## 部署方式

### 方式一：单机 Docker Compose（推荐，最简）

```bash
# 克隆仓库
git clone https://github.com/snapotter-hq/snapotter.git
cd snapotter

# 复制并编辑环境配置
cp .env.example .env
nano .env   # 至少修改 DEFAULT_PASSWORD

# 启动
docker compose -f docker/docker-compose.yml up -d

# 查看状态
docker compose -f docker/docker-compose.yml ps
docker compose -f docker/docker-compose.yml logs -f
```

**访问**: `http://<服务器IP>:1349`

---

### 方式二：全量服务（可选的外部 PostgreSQL + Redis）

```bash
# 创建配置目录
mkdir -p /opt/snapotter

# 复制部署文件
cp docker/docker-compose.full.yml /opt/snapotter/docker-compose.yml
cp -r docker /opt/snapotter/

# 创建 .env
cat > /opt/snapotter/.env << 'EOF'
POSTGRES_USER=snapotter
POSTGRES_PASSWORD=your_secure_password_here
AUTH_ENABLED=true
DEFAULT_USERNAME=admin
DEFAULT_PASSWORD=your_secure_password_here
MAX_UPLOAD_SIZE_MB=100
MAX_BATCH_SIZE=50
MAX_MEGAPIXELS=100
MAX_PIPELINE_STEPS=20
MAX_CANVAS_PIXELS=50000000
MAX_SVG_SIZE_MB=10
MAX_PDF_PAGES=100
SESSION_DURATION_HOURS=168
DEFAULT_THEME=system
DEFAULT_LOCALE=en
EOF

# 启动全量服务
cd /opt/snapotter
docker compose -f docker-compose.yml up -d
```

> **注意**: `docker-compose.full.yml` 是扩展模板，实际使用方式一的 SQLite 容器即可生产运行。PostgreSQL 需要代码层改造 drizzle 配置，当前不支持。

---

### 方式三：带 GPU 加速

```bash
# 需要 NVIDIA GPU + nvidia-container-toolkit
docker compose -f docker/docker-compose-gpu.yml up -d
```

---

## 部署检查清单

### 首次部署前

- [ ] 修改 `DEFAULT_USERNAME` 和 `DEFAULT_PASSWORD`
- [ ] 确认防火墙开放端口 `1349`（API）
- [ ] 确认 `shm_size: 2gb`（容器内图片处理需要共享内存）

### 数据持久化

所有数据存在 Docker 卷：

| 卷名 | 用途 |
|------|------|
| `SnapOtter-data` | 数据库 + AI 模型 |
| `SnapOtter-workspace` | 临时处理文件（自动清理） |

**重要**: 删除容器后数据不丢，但删除卷则数据永久丢失。

```bash
# 查看卷
docker volume ls | grep SnapOtter

# 备份数据卷
docker run --rm -v snapotter_SnapOtter-data:/data -v $(pwd):/backup alpine tar czf /backup/snapotter-backup.tar.gz /data
```

---

## 运维命令

```bash
# 重启
docker compose -f docker/docker-compose.yml restart

# 更新（重新构建）
git pull
docker compose -f docker/docker-compose.yml build --no-cache
docker compose -f docker/docker-compose.yml up -d

# 查看日志
docker compose -f docker/docker-compose.yml logs -f api

# 进入容器调试
docker exec -it SnapOtter /bin/sh

# 清理未使用镜像
docker image prune -f
```

---

## HTTPS 配置（生产环境）

在 `docker-compose.yml` 前加一层 nginx reverse proxy：

```yaml
services:
  nginx:
    image: nginx:1.27-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./tls:/etc/nginx/tls:ro
    depends_on:
      - SnapOtter
    networks:
      - snapotter

  SnapOtter:
    # ... existing config ...
    expose:
      - "1349"
```

`nginx.conf`:

```nginx
worker_processing auto;
error_log /var/log/nginx/error.log warn;

events {
    worker_connections 1024;
}

http {
    upstream api {
        server SnapOtter:1349;
    }

    server {
        listen 80;
        server_name _;
        return 301 https://$host$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name _;

        ssl_certificate /etc/nginx/tls/cert.pem;
        ssl_certificate_key /etc/nginx/tls/key.pem;

        location / {
            root /usr/share/nginx/html;
            try_files $uri $uri/ /index.html;
        }

        location /api/ {
            proxy_pass http://api;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
```

---

## 资源建议

| 场景 | CPU | 内存 | 存储 |
|------|-----|------|------|
| 小型（10用户） | 2核 | 4GB | 20GB |
| 中型（50用户） | 4核 | 8GB | 50GB |
| 大型（100+用户） | 8核 | 16GB | 100GB |

AI 工具（去背景等）需要 GPU 加速，无 GPU 时使用 CPU 模式（慢 5-10x）。
