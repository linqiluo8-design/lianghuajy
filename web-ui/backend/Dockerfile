# ============================================
# Funcat Web UI - Dockerfile
# ============================================

FROM golang:1.21-alpine AS builder

# 设置工作目录
WORKDIR /build

# 设置Go代理（解决国内网络问题，添加多个备选镜像）
ENV GOPROXY=https://goproxy.cn,https://mirrors.aliyun.com/goproxy/,https://goproxy.io,direct
ENV GO111MODULE=on
ENV GOSUMDB=off

# 安装依赖
RUN apk add --no-cache git

# 【优化】先复制 go.mod 和 go.sum（如果存在），利用 Docker 缓存层
COPY go.mod ./
# 可选复制 go.sum（使用通配符避免文件不存在时报错）
COPY go.su[m] ./

# 【智能处理】如果 go.sum 不存在则首次生成，之后就会利用缓存
# 注意：一旦 go.sum 生成并提交到 git，此层就会被完美缓存
RUN if [ ! -f go.sum ]; then \
        echo "首次构建：生成 go.sum..." && go mod tidy; \
    fi && \
    go mod download

# 【优化】之后再复制源代码（代码变化不会导致重新下载依赖）
COPY . .

# 编译（添加并行编译优化）
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

# 复制静态文件（包括下载的CDN资源）
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
