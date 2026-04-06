.PHONY: dev dev-backend dev-frontend install

# Go 路径（如不在 PATH 中，需指定）
GO ?= $(shell which go 2>/dev/null || echo /usr/local/go/bin/go)

# 同时启动后端和前端，Ctrl+C 一起退出
dev:
	@echo "==> 启动后端 (localhost:8080) + 前端 (localhost:3000)"
	@echo "    Ctrl+C 停止所有服务"
	@echo ""
	@trap 'kill 0; exit 0' INT TERM; \
	(cd backend && $(GO) run ./cmd/server) & \
	(cd frontend && npx vite --port 3000) & \
	wait

# 仅启动后端
dev-backend:
	cd backend && $(GO) run ./cmd/server

# 仅启动前端
dev-frontend:
	cd frontend && npx vite --port 3000

# 安装前端依赖
install:
	cd frontend && npm install
