# Docker 构建优化最佳实践

本文档记录项目中 Dockerfile 的所有优化历程，包括走过的"回头路"和最终的最佳实践。

**目标：避免重复犯错，确保优化不被"忘记"。**

---

## 📋 目录

1. [优化历史时间线](#优化历史时间线)
2. [核心优化原则](#核心优化原则)
3. [所有 Dockerfile 统一标准](#所有-dockerfile-统一标准)
4. [走过的"回头路"](#走过的回头路)
5. [最佳实践清单](#最佳实践清单)
6. [故障排查指南](#故障排查指南)

---

## 优化历史时间线

### 2025-12-28: 初次遇到 go.sum 问题

**提交:** `5abea57` - fix: 修改Web UI Dockerfile自动生成go.sum

**问题:**
- `web-ui/backend/go.sum` 文件为空（只有注释）
- 本地环境没有 go 命令无法手动生成
- 构建时报错：`missing go.sum entry for module`

**解决方案:**
- 删除空的 go.sum 文件
- 修改 Dockerfile：添加 `go mod tidy` 自动生成
- 构建时会在容器内自动生成完整的 go.sum

**变更:**
```dockerfile
# 之前
COPY go.mod go.sum* ./
RUN go mod download

# 之后
COPY go.mod ./
RUN go mod tidy && go mod download
```

### 2026-01-01: 构建速度优化

**提交:** `0504e4d` - perf: 优化 Dockerfile 构建速度

**问题:**
- 每次修改 `.go` 文件或 `index.html` 都重新下载依赖
- 构建时间：5 分钟（每次）

**根本原因:**
- `COPY . .` 在 `RUN go mod download` 之前
- 任何文件修改都使 Docker 缓存层失效
- `go mod tidy` 每次都重新生成 go.sum，破坏缓存

**解决方案:**
- **移除** `go mod tidy`（避免每次重新生成 go.sum）
- 先复制 `go.mod` 和 `go.sum`
- 单独执行 `go mod download`（会被 Docker 缓存）
- 最后复制源代码

**效果:**
- 首次构建：5 分钟
- 二次构建：30 秒（利用缓存）
- **只有 go.mod/go.sum 改变时才重新下载依赖**

**变更:**
```dockerfile
# 优化后的层级顺序
COPY go.mod go.sum ./        # 第1层：复制依赖文件
RUN go mod download          # 第2层：下载依赖（会被缓存！）
COPY . .                     # 第3层：复制源代码
RUN go build                 # 第4层：编译
```

### 2026-01-04: 添加 Go 代理配置

**提交:** `5410f78` - fix: 添加Go代理配置解决依赖下载失败

**问题:**
- 从 github.com 和 golang.org 下载依赖缓慢或失败
- 国内网络环境不稳定

**解决方案:**
```dockerfile
ENV GOPROXY=https://goproxy.cn,direct
ENV GO111MODULE=on
```

**效果:**
- 依赖下载速度大幅提升
- 构建成功率提高

### 2026-01-11: 全面优化（⚠️ 走了"回头路"）

**提交:** `cb0472e` - perf: 优化 Web UI 构建速度，Go 依赖下载加速（370s → 150s）

**问题:**
- **重新引入了 `go mod tidy`**（破坏了之前的优化！）
- 原因：忘记了之前的优化历史，以为需要 tidy 生成 go.sum

**错误变更:**
```dockerfile
# ❌ 错误：重新引入 go mod tidy
COPY go.mod ./
COPY go.su[m] ./
RUN go mod tidy && go mod download  # 破坏缓存！
```

**正面改进:**
- 增强 GOPROXY 配置（多镜像容错）
- 添加 `.dockerignore`
- 添加 `GOSUMDB=off`

### 2026-01-11: 修正"回头路"（本次修复）+ 构建错误修复

**问题 1:**
- 发现重新引入了 `go mod tidy`，走了"回头路"
- 需要恢复之前的优化，同时兼容 go.sum 不存在的情况

**尝试的错误方案:**
```dockerfile
# ❌ 错误：go mod tidy 在 COPY 源代码之前执行
COPY go.mod ./
COPY go.su[m] ./

RUN if [ ! -f go.sum ]; then \
        go mod tidy;  # 找不到源代码，无法生成 go.sum！
    fi && \
    go mod download

COPY . .  # 源代码在 go mod tidy 之后才复制
```

**问题 2: 构建失败**
```
ERROR: missing go.sum entry for module providing package github.com/gin-gonic/gin
```

**根本原因:**
- `go mod tidy` 需要分析源代码（main.go）中的 import 语句才能生成正确的 go.sum
- 但我们在 `COPY . .` **之前**就执行了 `go mod tidy`
- 导致 go.sum 没有正确生成，构建失败

**尝试的优化方案（失败）:**
```dockerfile
# ❌ 仍然失败：只复制 *.go 不够
COPY go.mod ./
COPY *.go ./
RUN go mod tidy && go mod download
COPY . .
```

**问题 3: go.sum 仍然不完整**
```
ERROR: missing go.sum entry for go.mod file
github.com/go-redis/redis/v8@v8.11.5: missing go.sum entry
```

**根本原因:**
- `go mod tidy` 需要访问完整的项目结构（可能有子目录、子包）
- 只复制 go.mod 和 *.go 不完整，无法正确分析所有依赖
- 间接依赖的 go.mod 文件的 hash 没有被记录到 go.sum

**最终简化方案（确保成功）:**
```dockerfile
# ✅ 简化但可靠：先复制所有文件
COPY . .
RUN go mod tidy && go mod download
RUN go build
```

**权衡:**
- ✅ 构建成功，go.sum 完整正确
- ✅ 简单可靠，不会出错
- ❌ 任何文件变更都触发依赖下载（~150 秒）
- ❌ 失去了缓存优化

**理想方案（未来）:**
```dockerfile
# 🌟 最佳实践：go.sum 提前生成并提交到 git
COPY go.mod go.sum ./
RUN go mod download  # 完美缓存！
COPY . .
RUN go build
```

提交 go.sum 后的效果：
- 代码变更：~30 秒（完美缓存）
- 依赖变更：~150 秒

### 2026-01-11: 集成 go.sum 提取到部署脚本

**改进:**
- 在 `deploy-from-scratch.sh` 中添加步骤 7.5
- 自动从构建镜像提取 go.sum 文件
- 提示用户提交以优化构建缓存

**实现:**
```bash
# 步骤 7.5: 提取并提交 go.sum（优化 Docker 缓存）
if [[ "$REBUILD_WEBUI" == true ]]; then
    if [[ ! -f "web-ui/backend/go.sum" ]]; then
        # 从构建镜像提取 go.sum
        # 提示用户提交到 git
    fi
fi
```

**优势:**
- 自动化流程：无需手动运行 extract-gosum.sh
- 友好提示：明确说明优化效果和提交命令
- 智能检测：只在需要时提取

---

## 核心优化原则

### 1. Docker 缓存层机制

Docker 按顺序执行 Dockerfile 指令，每条指令创建一个层。如果某层的输入没变，就复用缓存。

**示例:**
```dockerfile
Layer 1: FROM golang:1.21-alpine    ✓ 始终缓存（基础镜像）
Layer 2: COPY go.mod go.sum ./      ✓ go.mod/go.sum 不变时缓存
Layer 3: RUN go mod download        ✓ 依赖层缓存（关键！）
Layer 4: COPY . .                   ✗ 代码变更，此层失效
Layer 5: RUN go build               ✗ 代码变更，重新编译
```

**关键点:**
- 把不常变化的层放前面（依赖）
- 把频繁变化的层放后面（源代码）
- 避免在依赖层执行会变化的操作（如 `go mod tidy`）

### 2. go.sum 的作用和生成

**go.sum 是什么:**
- 依赖包的校验和文件
- 确保依赖包的完整性和一致性
- 由 `go mod tidy` 或 `go mod download` 生成

**最佳实践:**
- ✅ **提交 go.sum 到 git**（锁定依赖版本）
- ✅ **Dockerfile 中不执行 `go mod tidy`**（避免破坏缓存）
- ✅ **本地生成 go.sum 后提交**
- ❌ **不要删除 go.sum**（除非有充分理由）
- ❌ **不要让 Dockerfile 每次重新生成 go.sum**

### 3. GOPROXY 配置

**为什么需要:**
- 国内访问 github.com 和 golang.org 慢
- 提高构建成功率和速度

**最佳配置:**
```dockerfile
ENV GOPROXY=https://goproxy.cn,https://mirrors.aliyun.com/goproxy/,https://goproxy.io,direct
ENV GOSUMDB=off  # 可选：禁用校验和验证
```

**镜像说明:**
1. `goproxy.cn` - 七牛云，国内速度快
2. `mirrors.aliyun.com/goproxy/` - 阿里云，备用
3. `goproxy.io` - 国际镜像，备用
4. `direct` - 直连（前面都失败时）

---

## 所有 Dockerfile 统一标准

### Go 项目 Dockerfile 模板

```dockerfile
# ============================================
# 阶段1: 构建阶段
# ============================================
FROM golang:1.21-alpine AS builder

WORKDIR /build

# 【必须】设置 Go 代理（多镜像容错）
ENV GOPROXY=https://goproxy.cn,https://mirrors.aliyun.com/goproxy/,https://goproxy.io,direct
ENV GO111MODULE=on
ENV GOSUMDB=off

# 【必须】安装构建依赖
RUN apk add --no-cache git make

# 【关键】先复制依赖文件（利用 Docker 缓存）
COPY go.mod go.sum ./

# 【关键】下载依赖（这一层会被缓存！）
RUN go mod download

# 【关键】最后复制源代码
COPY . .

# 编译
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" -trimpath \
    -o your-app ./cmd/main.go

# ============================================
# 阶段2: 运行阶段
# ============================================
FROM alpine:latest

# 设置时区
RUN apk add --no-cache ca-certificates tzdata && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# 创建非root用户
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

WORKDIR /app

# 复制二进制文件
COPY --from=builder --chown=appuser:appuser /build/your-app .

USER appuser

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD pgrep your-app || exit 1

CMD ["./your-app"]
```

### .dockerignore 模板

```gitignore
# Git 相关
.git
.gitignore

# IDE
.vscode
.idea
*.swp

# 构建产物
*.exe
*.so
*.dylib
your-app

# 文档
README.md
*.md
LICENSE

# Docker
Dockerfile*
.dockerignore
docker-compose*.yml

# 测试
*.test
*.out
coverage.txt

# 临时文件
*.log
tmp/
```

---

## 走过的"回头路"

### 回头路 #1: 重新引入 go mod tidy

**时间:** 2026-01-11
**提交:** cb0472e

**问题:**
忘记了 2026-01-01 的优化（`0504e4d`），重新引入了 `go mod tidy`。

**原因:**
- 没有详细文档记录之前的优化
- 看到 go.sum 不存在，就以为需要 tidy
- 没有检查 git 历史

**教训:**
- ✅ **所有优化都必须记录到文档**
- ✅ **重大修改前先检查 git 历史**
- ✅ **在代码中添加注释说明优化原理**

### 回头路 #2: go.sum 删除又生成

**时间线:**
1. 2025-12-28: go.sum 为空 → 删除 + 添加 tidy
2. 2026-01-01: 为了优化 → 移除 tidy + 假设 go.sum 存在
3. 2026-01-11: 发现 go.sum 不存在 → 又加回 tidy
4. 现在: 智能处理（首次 tidy，之后缓存）

**问题:**
- go.sum 的生成和管理策略不清晰
- 多次在"删除"和"生成"之间反复

**教训:**
- ✅ **go.sum 应该提交到 git**
- ✅ **提供工具脚本生成 go.sum**（`extract-gosum.sh`）
- ✅ **Dockerfile 应智能处理有/无 go.sum 的情况**

### 回头路 #3: GOPROXY 配置不统一

**问题:**
- funcat-go/Dockerfile: `GOPROXY=https://goproxy.cn,direct`
- web-ui/backend/Dockerfile: 多镜像配置

**原因:**
- 分批次优化，没有统一标准
- 缺少统一的 Dockerfile 规范文档

**修复:**
- ✅ 统一所有 Go Dockerfile 的 GOPROXY 配置
- ✅ 创建本文档作为统一标准

---

## 最佳实践清单

### ✅ 开发新 Go 项目时

- [ ] 使用模板 Dockerfile（见上文）
- [ ] 本地生成 go.sum：`go mod tidy`
- [ ] 提交 go.sum 到 git
- [ ] 创建 .dockerignore
- [ ] 测试 Docker 缓存：修改 .go 文件后重新构建，应该很快

### ✅ 修改现有 Dockerfile 时

- [ ] 先检查 git 历史：`git log --oneline -- path/to/Dockerfile`
- [ ] 阅读本文档了解优化原则
- [ ] 确认修改不会破坏缓存机制
- [ ] 测试构建速度（首次 vs 二次）
- [ ] 更新本文档记录变更

### ✅ 提交代码时

- [ ] 确保 go.sum 已提交（如果是 Go 项目）
- [ ] 检查 GOPROXY 配置是否统一
- [ ] 验证 .dockerignore 是否正确
- [ ] Commit message 说明优化效果

---

## 故障排查指南

### 问题: 构建时间过长（每次都很慢）

**可能原因:**
1. 依赖层缓存失效
2. COPY . . 在 RUN go mod download 之前
3. 每次执行 go mod tidy

**解决方法:**
```bash
# 检查构建日志中的缓存命中情况
docker build --progress=plain . 2>&1 | grep -i cached

# 正确的顺序
COPY go.mod go.sum ./
RUN go mod download     # 应该显示 CACHED（二次构建）
COPY . .
```

### 问题: go.sum 不存在导致构建失败

**解决方法:**

**方法 1: 使用脚本生成**
```bash
bash deployment/scripts/extract-gosum.sh webui
git add web-ui/backend/go.sum
git commit -m "feat: 添加 go.sum 文件"
```

**方法 2: 手动从容器提取**
```bash
# 首次构建（会生成 go.sum）
docker build -t temp-build .

# 创建临时容器
docker create --name temp temp-build

# 复制 go.sum
docker cp temp:/build/go.sum ./go.sum

# 清理
docker rm temp

# 提交
git add go.sum
git commit -m "feat: 添加 go.sum 文件"
```

### 问题: 依赖下载失败

**可能原因:**
1. GOPROXY 配置缺失或错误
2. 网络问题
3. 镜像源不可用

**解决方法:**
```dockerfile
# 使用多镜像容错配置
ENV GOPROXY=https://goproxy.cn,https://mirrors.aliyun.com/goproxy/,https://goproxy.io,direct

# 构建时查看日志
docker build --no-cache . 2>&1 | grep -i "downloading\|proxy"
```

---

## 附录：工具脚本

### extract-gosum.sh

**位置:** `deployment/scripts/extract-gosum.sh`

**用途:** 从 Docker 容器或临时容器提取 go.sum 文件

**使用:**
```bash
# 提取 Web UI 的 go.sum
bash deployment/scripts/extract-gosum.sh webui

# 提取 funcat-go 的 go.sum
bash deployment/scripts/extract-gosum.sh funcat-go
```

---

## 总结

**核心原则:**
1. **依赖层优先** - COPY go.mod/go.sum → RUN go mod download → COPY . .
2. **go.sum 提交到 git** - 避免每次重新生成
3. **多 GOPROXY 镜像** - 提高成功率和速度
4. **记录所有优化** - 避免走"回头路"

**记住:**
> 每次修改 Dockerfile 前，先问自己：这会破坏 Docker 缓存吗？

**如有疑问，查看:**
1. 本文档
2. Git 历史：`git log --oneline -- path/to/Dockerfile`
3. FIXES.md 中的相关记录
