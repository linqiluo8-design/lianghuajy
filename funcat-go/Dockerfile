# Funcat Go 选股服务 Dockerfile
# 多阶段构建，减小镜像体积

# ============================================
# 阶段1: 构建阶段
# ============================================
FROM golang:1.21-alpine AS builder

# 设置工作目录
WORKDIR /build

# 安装构建依赖
RUN apk add --no-cache git make

# 复制go mod文件
COPY go.mod go.sum ./

# 下载依赖
RUN go mod download

# 复制源代码
COPY . .

# 编译Go程序
# -ldflags="-s -w" 减小二进制文件体积
# -trimpath 移除文件路径信息
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" -trimpath \
    -o funcat-selector \
    ./cmd/selector/main.go

# ============================================
# 阶段2: 运行阶段
# ============================================
FROM alpine:latest

# 设置标签
LABEL maintainer="Funcat Team"
LABEL version="2.0.0"
LABEL description="Funcat高性能选股服务"

# 安装运行时依赖
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone

# 创建非root用户
RUN addgroup -g 1000 funcat && \
    adduser -D -u 1000 -G funcat funcat

# 创建必要目录
RUN mkdir -p /app/config /app/logs /app/data && \
    chown -R funcat:funcat /app

# 切换工作目录
WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder --chown=funcat:funcat /build/funcat-selector .

# 切换到非root用户
USER funcat

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD pgrep funcat-selector || exit 1

# 暴露端口(如果有API服务)
# EXPOSE 8080

# 启动命令
ENTRYPOINT ["/app/funcat-selector"]
CMD ["--config=/app/config/selector.yaml"]
