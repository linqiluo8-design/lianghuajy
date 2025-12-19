# ============================================
# Funcat Web UI - Dockerfile
# ============================================

FROM golang:1.21-alpine AS builder

# 设置工作目录
WORKDIR /build

# 安装依赖
RUN apk add --no-cache git

# 复制 go.mod 和 go.sum
COPY go.mod go.sum* ./

# 下载依赖
RUN go mod download

# 复制源代码
COPY . .

# 编译
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags="-s -w" -o funcat-web-ui .

# ============================================
# 运行阶段
# ============================================

FROM alpine:latest

# 安装必要的包
RUN apk --no-cache add ca-certificates tzdata curl

# 设置时区
ENV TZ=Asia/Shanghai

# 创建非root用户
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# 设置工作目录
WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /build/funcat-web-ui .

# 复制静态文件
COPY --from=builder /build/static ./static

# 修改所有权
RUN chown -R appuser:appuser /app

# 切换到非root用户
USER appuser

# 暴露端口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/api/v1/health || exit 1

# 启动服务
CMD ["./funcat-web-ui"]
