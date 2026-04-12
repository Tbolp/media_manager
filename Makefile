.PHONY: dev dev-backend dev-frontend install build release release-apk clean

# Go 路径（如不在 PATH 中，需指定）
GO ?= $(shell which go 2>/dev/null || echo /usr/local/go/bin/go)
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
BUILD_DIR = build
BINARY_NAME = media-manager

# 交叉编译目标
PLATFORMS = \
	linux/amd64 \
	linux/arm64 \
	darwin/amd64 \
	darwin/arm64 \
	windows/amd64

# 同时启动后端和前端，Ctrl+C 一起退出
dev:
	@echo "==> 启动后端 (localhost:8080) + 前端 (localhost:3000)"
	@echo "    Ctrl+C 停止所有服务"
	@echo ""
	@trap 'kill 0; exit 0' INT TERM; \
	(cd backend && DATA_DIR=./data $(GO) run ./cmd/server) & \
	(cd frontend && npx vite --port 3000) & \
	wait

# 仅启动后端
dev-backend:
	cd backend && DATA_DIR=./data $(GO) run ./cmd/server

# 仅启动前端
dev-frontend:
	cd frontend && npx vite --port 3000

# 安装前端依赖
install:
	cd frontend && npm install

# 构建当前平台二进制
build:
	@echo "==> 构建前端..."
	cd frontend && npm run build
	@echo "==> 复制前端产物到后端..."
	rm -rf backend/cmd/server/dist
	cp -r frontend/dist backend/cmd/server/dist
	@echo "==> 编译 Go 二进制..."
	mkdir -p $(BUILD_DIR)
	cd backend && CGO_ENABLED=0 $(GO) build -ldflags="-s -w" -o ../$(BUILD_DIR)/$(BINARY_NAME) ./cmd/server
	@echo ""
	@echo "  构建完成: $(BUILD_DIR)/$(BINARY_NAME)"

# 构建全平台发布包（每个平台一个 zip）
release:
	@echo "==> 构建前端..."
	cd frontend && npm run build
	@echo "==> 复制前端产物到后端..."
	rm -rf backend/cmd/server/dist
	cp -r frontend/dist backend/cmd/server/dist
	rm -rf $(BUILD_DIR)
	@for platform in $(PLATFORMS); do \
		os=$${platform%/*}; \
		arch=$${platform#*/}; \
		ext=""; \
		if [ "$$os" = "windows" ]; then ext=".exe"; fi; \
		pkg_name=MediaManager-$(VERSION)-$${os}-$${arch}; \
		pkg_dir=$(BUILD_DIR)/$${pkg_name}; \
		echo "==> 编译 $${os}/$${arch}..."; \
		mkdir -p $${pkg_dir}; \
		cd backend && CGO_ENABLED=0 GOOS=$$os GOARCH=$$arch \
			$(GO) build -ldflags="-s -w" -o ../$${pkg_dir}/$(BINARY_NAME)$${ext} ./cmd/server && cd ..; \
		printf '# MediaManager\n\n' > $${pkg_dir}/README.txt; \
		printf '## 运行\n\n  ./$(BINARY_NAME)'"$$ext"'\n\n' >> $${pkg_dir}/README.txt; \
		printf '## 依赖\n\n  ffmpeg / ffprobe 需预装并加入 PATH\n\n' >> $${pkg_dir}/README.txt; \
		printf '## 数据\n\n  数据库: ./data/ (自动创建)\n  缩略图: ./thumbnails/ (自动创建)\n\n' >> $${pkg_dir}/README.txt; \
		printf '## 端口\n\n  默认监听 :8080，可通过环境变量 LISTEN_ADDR 修改\n' >> $${pkg_dir}/README.txt; \
		cd $(BUILD_DIR) && zip -r $${pkg_name}.zip $${pkg_name}/ && cd ..; \
		rm -rf $${pkg_dir}; \
	done
	@echo ""
	@echo "  构建完成："
	@ls -lh $(BUILD_DIR)/*.zip

# 构建 Android 发布 APK
release-apk:
	@echo "==> 构建 Flutter Android 发布包..."
	cd mobile && flutter build apk --release
	@mkdir -p $(BUILD_DIR)
	@cp mobile/build/app/outputs/flutter-apk/app-release.apk $(BUILD_DIR)/MediaManager-$(VERSION).apk
	@echo ""
	@echo "  APK 构建完成: $(BUILD_DIR)/MediaManager-$(VERSION).apk"

# 清理构建产物
clean:
	rm -rf $(BUILD_DIR)
	rm -rf frontend/dist
	rm -rf backend/cmd/server/dist
	mkdir -p backend/cmd/server/dist
	echo '<!DOCTYPE html><html><body><p>前端未构建</p></body></html>' > backend/cmd/server/dist/index.html
