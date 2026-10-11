#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$root/upstream" "$root/.deps/lib" "$root/reports"
vim_commit=b2b47bdf9401c865780dd4c47b1dbafb0463c75a
jit_commit=4fc236e753127081efad57cd5f91cf81c2bd3269
if [[ ! -d "$root/upstream/vim/.git" ]]; then
  git clone --depth 1 --branch v9.2.1172 https://github.com/vim/vim.git "$root/upstream/vim"
fi
if [[ ! -d "$root/upstream/vim9jit/.git" ]]; then
  git init "$root/upstream/vim9jit"
  git -C "$root/upstream/vim9jit" remote add origin https://github.com/tjdevries/vim9jit.git
  git -C "$root/upstream/vim9jit" fetch --depth 1 origin "$jit_commit"
  git -C "$root/upstream/vim9jit" checkout --detach FETCH_HEAD
fi
if [[ $(git -C "$root/upstream/vim" rev-parse HEAD) != "$vim_commit" ]]; then
  # Refuse to discard tracked local edits while moving to the pinned version.
  git -C "$root/upstream/vim" diff --exit-code HEAD --
  git -C "$root/upstream/vim" fetch --depth 1 origin "$vim_commit"
  git -C "$root/upstream/vim" checkout --detach "$vim_commit"
fi
[[ $(git -C "$root/upstream/vim" rev-parse HEAD) == "$vim_commit" ]]
[[ $(git -C "$root/upstream/vim9jit" rev-parse HEAD) == "$jit_commit" ]]
if [[ ! -x "$root/.deps/nvim-linux-x86_64/bin/nvim" ]]; then
  if [[ ! -f "$root/.deps/nvim.tar.gz" ]]; then
    curl -fL --retry 2 https://github.com/neovim/neovim/releases/download/v0.11.3/nvim-linux-x86_64.tar.gz -o "$root/.deps/nvim.tar.gz"
  fi
  (cd "$root/.deps"; echo '02b808a3ee8fc30161e07fe3c3edfb24b28bd0295323ac5dbdd8ec7012cac67d  nvim.tar.gz' | sha256sum -c -)
  tar --no-same-owner -xzf "$root/.deps/nvim.tar.gz" -C "$root/.deps"
fi
# A runtime libtinfo is sufficient on this Linux image; provide a linker name.
if [[ ! -e /usr/lib/x86_64-linux-gnu/libtinfo.so && -e /usr/lib/x86_64-linux-gnu/libtinfo.so.6 ]]; then
  ln -sf /usr/lib/x86_64-linux-gnu/libtinfo.so.6 "$root/.deps/lib/libtinfo.so"
fi
if [[ ! -x "$root/upstream/vim/src/vim" || ! -f "$root/.deps/vim-build-commit" || $(cat "$root/.deps/vim-build-commit") != "$vim_commit" ]]; then
  (cd "$root/upstream/vim"
    if [[ -f src/auto/config.mk ]]; then make distclean > "$root/reports/distclean.log" 2>&1; fi
    LDFLAGS="-L$root/.deps/lib" ./configure --with-features=huge --enable-gui=no --without-x --disable-nls --with-tlib=tinfo > "$root/reports/configure.log" 2>&1
    make -j4 > "$root/reports/build.log" 2>&1)
  echo "$vim_commit" > "$root/.deps/vim-build-commit"
fi
"$root/.deps/nvim-linux-x86_64/bin/nvim" --headless -u NONE -l "$root/scripts/m0.lua" lock
