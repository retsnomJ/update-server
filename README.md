# update-server

应用自更新版本仓库，托管在 GitHub 公开仓库 `retsnomj/update-server`。

## 结构

- `version.json` — 当前最新版本信息（main 分支固定路径，永不删除，每次发版覆盖更新）
- Release Tags `v{versionName}` — 每个版本对应一个 GitHub Release，APK 作为 Asset

## version.json 字段

```json
{
  "versionCode": 2,
  "versionName": "1.0.1",
  "changelog": "修复盘点单保存异常",
  "apkUrl": "/retsnomj/update-server/releases/download/v1.0.1/fastmes-pda-1.0.1.apk",
  "apkSize": 15728640,
  "publishedAt": "2026-07-09T10:00:00Z"
}
```

- `versionCode` 必须单调递增（客户端只比 versionCode，不比 versionName）
- `apkUrl` 用相对路径，客户端拼 baseUrl（避免硬编码 owner/repo，支持镜像 fallback）
- `apkSize` 单位 byte（可选，用于进度条预估）

## 客户端镜像 fallback

JS 侧自动按以下顺序尝试拉 `version.json`，任一成功即停止：

1. `https://raw.githubusercontent.com/`
2. `https://gh-proxy.com/https://raw.githubusercontent.com/`
3. `https://ghproxy.net/https://raw.githubusercontent.com/`
4. `https://mirror.ghproxy.com/https://raw.githubusercontent.com/`

APK 下载走相同的镜像列表（base 不同）。

## 发版流程

### 前置

1. `gh auth login` 登录 GitHub CLI
2. 已经在 `retsnomj/update-server` 仓库有 push 权限
3. 已生成 release keystore（运行 `frontend-origin-vue/android/setup-keystore.sh`）

### 命令

```bash
cd /path/to/this/repo
./release.sh <versionName> <versionCode> <changelog> <apk-path>
```

例子：
```bash
./release.sh 1.0.1 2 "修复盘点单保存异常" \
  ../frontend-origin-vue/android/app/build/outputs/apk/release/app-release.apk
```

脚本会自动：
1. 在 GitHub 创建 Release `v{versionName}` 并上传 APK 作为 Asset
2. 更新 `version.json`
3. commit + push `version.json` 到 main

## 重要约定

1. **versionCode 必须单调递增**，不能回退
2. **APK 文件名固定格式**：`fastmes-pda-{versionName}.apk`（如 fastmes-pda-1.0.1.apk）
3. **不要删除历史 Release**：保留所有 tag，客户端只比对 versionCode
4. **首次发版前**：确保 `version.json` 的 versionCode 等于当前 APK 的 versionCode，否则客户端会以为是新版本

## 客户端换 owner/repo

如果换 GitHub owner/repo，只需修改前端代码一处：

`frontend-origin-vue/src/api/update.js`：
```js
const DEFAULT_REPO = import.meta.env.VITE_UPDATE_REPO || '<新 owner>/<新 repo>'
```

或在 `frontend-origin-vue/.env.mobile` 里加：
```
VITE_UPDATE_REPO=<新 owner>/<新 repo>
```