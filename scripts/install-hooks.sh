#!/usr/bin/env bash
# Cài gitleaks + pre-commit hook cho máy dev.
#
# Vì sao cần script: `.git/hooks/` KHÔNG theo repo, nên clone mới (hoặc máy mới) là mất hook —
# đúng thứ đã xảy ra một lần trên máy này (2026-09-21). Hook nay ở scripts/hooks/ (theo repo).
# CI vẫn quét, nhưng lúc đó secret đã nằm trong commit.
#
# Chạy: bash scripts/install-hooks.sh
set -euo pipefail

GITLEAKS_VERSION=8.30.1 # ghim trùng .github/workflows/ci.yml — nâng cấp là một PR riêng
BIN_DIR="$HOME/.local/bin"
REPO_ROOT="$(git rev-parse --show-toplevel)"

if command -v gitleaks >/dev/null 2>&1; then
	echo "gitleaks da co: $(gitleaks version)"
else
	echo "cai gitleaks ${GITLEAKS_VERSION} vao ${BIN_DIR} (khong can sudo)..."
	mkdir -p "$BIN_DIR"
	tmp="$(mktemp -d)"
	curl -sSL -o "$tmp/gitleaks.tar.gz" \
		"https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"
	tar -xzf "$tmp/gitleaks.tar.gz" -C "$tmp" gitleaks
	install "$tmp/gitleaks" "$BIN_DIR/gitleaks"
	rm -rf "$tmp"
	echo "da cai: $("$BIN_DIR/gitleaks" version)"
	case ":$PATH:" in
	*":$BIN_DIR:"*) ;;
	*) echo "LUU Y: $BIN_DIR chua nam trong PATH — them vao ~/.bashrc" >&2 ;;
	esac
fi

# Review 30/09 #10: bản cũ đòi `.git/hooks/pre-commit` có sẵn → clone mới LUÔN exit 1, đúng lúc
# cần hook nhất. Giờ hook nằm trong repo (scripts/hooks/) và git được trỏ tới thư mục đó.
hook="$REPO_ROOT/scripts/hooks/pre-commit"
if [ ! -f "$hook" ] || ! grep -q gitleaks "$hook"; then
	echo "LOI: thieu $hook trong repo" >&2
	exit 1
fi
chmod +x "$hook"
git -C "$REPO_ROOT" config core.hooksPath scripts/hooks
echo "core.hooksPath = $(git -C "$REPO_ROOT" config --get core.hooksPath)"
echo "xong. Kiem thu: tao file chua secret gia roi 'git add' + 'git commit' — phai bi chan."
