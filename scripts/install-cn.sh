#!/usr/bin/env bash
# OpenClaw CN 安装脚本 (Linux / macOS / WSL)
# 中国社区: https://open-claw.org.cn/
# 用法一（在仓库根目录执行）: bash scripts/install-cn.sh
# 用法二（一键安装，发布后可用）: curl -fsSL https://open-claw.org.cn/install-cn.sh | bash
# Windows 原生请用 install-cn.ps1；WSL 下请用本脚本 (.sh)。
# 流程与文档 docs/install/installer.md 的 Flow (install.sh) 对齐；原版脚本可参考：
# 发布 v2026.2.23-cn 后可在脚本中启用从 Gitee 克隆并安装的逻辑（见下方 Gitee 占位）
set -euo pipefail

# 发布后填写 Gitee 仓库地址，用于一键安装时克隆（当前留空，仅支持“在仓库根目录执行”）
OPENCLAW_CN_GITEE_REPO="https://gitee.com/OpenClaw-CN/openclaw-cn.git"

# 尽早检测 OS，供 Ensure Git 与后续步骤使用（与 installer.md Flow 一致）
OS="unknown"
[[ "$OSTYPE" == "darwin"* ]] && OS="macos"
[[ "$OSTYPE" == "linux-gnu"* || -n "${WSL_DISTRO_NAME:-}" ]] && OS="linux"

BOLD='\033[1m'
ACCENT='\033[38;2;255;77;77m'
INFO='\033[38;2;136;146;176m'
SUCCESS='\033[38;2;0;229;204m'
WARN='\033[38;2;255;176;32m'
ERROR='\033[38;2;230;57;70m'
NC='\033[0m'

ui_info()    { echo -e "${INFO}·${NC} $*"; }
ui_warn()    { echo -e "${WARN}!${NC} $*"; }
ui_success() { echo -e "${SUCCESS}✓${NC} $*"; }
ui_error()   { echo -e "${ERROR}✗${NC} $*"; }

# Ensure Git（与 installer.md Flow 第 3 步一致）：缺失时尝试安装
ensure_git() {
    if command -v git &>/dev/null; then
        return 0
    fi
    if [[ "$OS" == "macos" ]]; then
        if command -v brew &>/dev/null; then
            ui_info "正在通过 Homebrew 安装 Git..."
            brew install git
        else
            ui_error "需要 Git，请先安装 Homebrew 或从 https://git-scm.com 安装"
            exit 1
        fi
    elif [[ "$OS" == "linux" ]]; then
        if command -v apt-get &>/dev/null; then
            ui_info "正在通过 apt 安装 Git..."
            sudo apt-get update -qq && sudo apt-get install -y git
        elif command -v dnf &>/dev/null; then
            ui_info "正在通过 dnf 安装 Git..."
            sudo dnf install -y git
        elif command -v yum &>/dev/null; then
            ui_info "正在通过 yum 安装 Git..."
            sudo yum install -y git
        else
            ui_error "需要 Git，请使用系统包管理器或从 https://git-scm.com 安装"
            exit 1
        fi
    else
        ui_error "需要 Git: https://git-scm.com"
        exit 1
    fi
    ui_success "Git 已就绪"
}

# 确定仓库根目录
REPO_DIR="${OPENCLAW_REPO_DIR:-}"
if [[ -z "$REPO_DIR" ]]; then
    if [[ -f "scripts/install-cn.sh" ]]; then
        REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    elif [[ -f "package.json" && -f "pnpm-workspace.yaml" ]]; then
        REPO_DIR="$(pwd)"
    elif [[ -n "$OPENCLAW_CN_GITEE_REPO" ]]; then
        REPO_DIR="$HOME/openclaw-cn"
        if [[ ! -f "$REPO_DIR/package.json" ]]; then
            command -v git &>/dev/null || ensure_git
            ui_info "正在从 Gitee 克隆 OpenClaw CN..."
            git clone "$OPENCLAW_CN_GITEE_REPO" "$REPO_DIR"
        fi
    fi
fi
if [[ -z "$REPO_DIR" || ! -f "$REPO_DIR/package.json" || ! -f "$REPO_DIR/pnpm-workspace.yaml" ]]; then
    ui_error "未找到 OpenClaw 仓库根目录（需要 package.json 与 pnpm-workspace.yaml）"
    echo "请进入仓库根目录后执行: bash scripts/install-cn.sh"
    echo "或使用一键安装: curl -fsSL https://open-claw.org.cn/install-cn.sh | bash"
    exit 1
fi

NO_ONBOARD="${OPENCLAW_NO_ONBOARD:-0}"
DRY_RUN="${OPENCLAW_DRY_RUN:-0}"
SHARP_IGNORE_GLOBAL_LIBVIPS="${SHARP_IGNORE_GLOBAL_LIBVIPS:-1}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-onboard) NO_ONBOARD=1; shift ;;
        --dry-run)    DRY_RUN=1; shift ;;
        --help|-h)
            echo "用法: bash scripts/install-cn.sh [--no-onboard] [--dry-run]"
            echo "环境变量: OPENCLAW_REPO_DIR, OPENCLAW_CN_GITEE_REPO, OPENCLAW_NO_ONBOARD=1, OPENCLAW_DRY_RUN=1"
            exit 0
            ;;
        *) shift ;;
    esac
done

echo ""
echo -e "${ACCENT}${BOLD} OpenClaw CN - 安装${NC}"
echo -e "${INFO} 中国社区 https://open-claw.org.cn/${NC}"
echo ""
ui_success "仓库根目录: $REPO_DIR"

if [[ "$OS" == "unknown" ]]; then
    ui_error "不支持的操作系统，仅支持 macOS 与 Linux（含 WSL）"
    exit 1
fi
ui_success "系统: $OS"

ensure_git

if [[ "$DRY_RUN" == "1" ]]; then
    ui_success "仅预览（Dry run），不执行安装"
    exit 0
fi

# 下载文件（供 NodeSource 等使用）
download_file() {
    local url="$1" output="$2"
    if command -v curl &>/dev/null; then
        curl -fsSL --retry 3 -o "$output" "$url"
    elif command -v wget &>/dev/null; then
        wget -q --https-only -O "$output" "$url"
    else
        ui_error "需要 curl 或 wget 以下载安装脚本"
        exit 1
    fi
}

is_root() { [[ "$(id -u)" -eq 0 ]]; }

# Linux 下自动安装需 sudo 时提示
require_sudo() {
    [[ "$OS" != "linux" ]] && return 0
    is_root && return 0
    if ! command -v sudo &>/dev/null; then
        ui_error "Linux 下自动安装 Node 需要 sudo，请先安装 sudo 或以 root 重试"
        exit 1
    fi
    if ! sudo -n true 2>/dev/null; then
        ui_info "需要管理员权限，请输入密码"
        sudo -v
    fi
}

node_major() {
    local v
    v="$(node -v 2>/dev/null || true)"
    v="${v#v}"; v="${v%%.*}"
    [[ "$v" =~ ^[0-9]+$ ]] && echo "$v" || return 1
}

check_node() {
    if ! command -v node &>/dev/null; then
        ui_info "未检测到 Node.js，将尝试自动安装"
        return 1
    fi
    local major
    major="$(node_major || true)"
    if [[ -n "$major" && "$major" -ge 22 ]]; then
        ui_success "已检测到 Node.js $(node -v)"
        return 0
    fi
    ui_info "需要 Node.js 22+，当前: $(node -v 2>/dev/null || echo '未知')，将尝试安装 Node 22"
    return 1
}

install_node() {
    if [[ "$OS" == "macos" ]]; then
        if command -v brew &>/dev/null; then
            ui_info "正在通过 Homebrew 安装 Node.js 22..."
            brew install node@22
            brew link node@22 --overwrite --force 2>/dev/null || true
            export PATH="$(brew --prefix node@22 2>/dev/null)/bin:$PATH"
        else
            ui_error "请先安装 Homebrew 或从 https://nodejs.org 安装 Node.js 22+"
            exit 1
        fi
    elif [[ "$OS" == "linux" ]]; then
        ui_info "正在通过 NodeSource 安装 Node.js 22..."
        require_sudo
        local tmp
        tmp="$(mktemp)"
        if command -v apt-get &>/dev/null; then
            download_file "https://deb.nodesource.com/setup_22.x" "$tmp"
            if is_root; then
                bash "$tmp" && apt-get install -y -qq nodejs
            else
                sudo -E bash "$tmp" && sudo apt-get install -y -qq nodejs
            fi
        elif command -v dnf &>/dev/null; then
            download_file "https://rpm.nodesource.com/setup_22.x" "$tmp"
            if is_root; then
                bash "$tmp" && dnf install -y -q nodejs
            else
                sudo bash "$tmp" && sudo dnf install -y -q nodejs
            fi
        elif command -v yum &>/dev/null; then
            download_file "https://rpm.nodesource.com/setup_22.x" "$tmp"
            if is_root; then
                bash "$tmp" && yum install -y -q nodejs
            else
                sudo bash "$tmp" && sudo yum install -y -q nodejs
            fi
        else
            rm -f "$tmp" 2>/dev/null || true
            ui_error "未检测到 apt/dnf/yum，请手动安装 Node.js 22+：https://nodejs.org"
            exit 1
        fi
        rm -f "$tmp" 2>/dev/null || true
    else
        ui_error "请先安装 Node.js 22+：https://nodejs.org"
        exit 1
    fi
    ui_success "Node.js 已安装"
}

ensure_pnpm() {
    if command -v pnpm &>/dev/null; then
        ui_success "已检测到 pnpm"
        return 0
    fi
    if command -v corepack &>/dev/null; then
        corepack enable 2>/dev/null || true
        corepack prepare pnpm@latest --activate 2>/dev/null || true
        if command -v pnpm &>/dev/null; then
            ui_success "已通过 corepack 启用 pnpm"
            return 0
        fi
    fi
    ui_info "正在通过 npm 安装 pnpm..."
    npm install -g pnpm
    ui_success "pnpm 已安装"
}

ensure_local_bin_on_path() {
    mkdir -p "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc" ]] && ! grep -q '.local/bin' "$rc"; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
            ui_info "已将 ~/.local/bin 加入 $rc"
        fi
    done
}

if ! check_node; then
    install_node
    if ! check_node; then
        ui_error "安装 Node 后请重新执行本脚本"
        exit 1
    fi
fi

ensure_pnpm
ensure_local_bin_on_path

cd "$REPO_DIR"

# 写入 node 目录供 bundle-a2ui.sh 使用（与 install-cn.ps1 一致，构建后删除）
NODE_DIR=""
if command -v node &>/dev/null; then
    NODE_DIR="$(dirname "$(command -v node)")"
    if [[ -n "$NODE_DIR" ]]; then
        printf '%s' "$NODE_DIR" > "$REPO_DIR/.openclaw-node-path"
        export PATH="$NODE_DIR:$PATH"
    fi
fi

ui_info "安装依赖 (pnpm install)..."
SHARP_IGNORE_GLOBAL_LIBVIPS="$SHARP_IGNORE_GLOBAL_LIBVIPS" pnpm install

ui_info "构建 UI (可选)..."
if ! SHARP_IGNORE_GLOBAL_LIBVIPS="$SHARP_IGNORE_GLOBAL_LIBVIPS" pnpm ui:build 2>/dev/null; then
    ui_warn "UI 构建失败，继续（CLI 仍可用）"
fi

ui_info "构建 OpenClaw (pnpm build)..."
pnpm build

if [[ ! -f "$REPO_DIR/dist/entry.js" ]]; then
    ui_error "构建后未找到 dist/entry.js"
    exit 1
fi

[[ -f "$REPO_DIR/.openclaw-node-path" ]] && rm -f "$REPO_DIR/.openclaw-node-path"

WRAPPER="$HOME/.local/bin/openclaw"
cat > "$WRAPPER" << WRAPEOF
#!/usr/bin/env bash
exec node "$REPO_DIR/dist/entry.js" "\$@"
WRAPEOF
chmod +x "$WRAPPER"
ui_success "已安装包装脚本: $WRAPPER"

# Post-install: doctor（与 installer.md 一致，best effort）
"$WRAPPER" doctor --non-interactive 2>/dev/null || true

if ! command -v openclaw &>/dev/null; then
    ui_warn "当前 shell 可能尚未包含 ~/.local/bin，请执行以下之一后重试 openclaw："
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo "  或重新打开终端"
fi

echo ""
ui_success "OpenClaw CN 安装完成！"
echo -e "中国社区: ${INFO}https://open-claw.org.cn/${NC}"
echo -e "源码目录: ${INFO}$REPO_DIR${NC}"
echo -e "命令: ${INFO}openclaw${NC}"
echo ""

if [[ "$NO_ONBOARD" != "1" ]]; then
    ui_info "正在启动初始化..."
    "$WRAPPER" onboard || true
else
    ui_info "已跳过初始化。需要时请运行: openclaw onboard"
fi
