# 負載測試（k6）

| 腳本 | 情境 |
|------|------|
| `browse.js` | 未登入讀者：首頁 → 小說詳情、目錄、相似作品、書評 → 連讀三章 → 排行、推薦，含閱讀停頓 |
| `reader.js` | 登入讀者：書架、未讀通知數、個人化推薦、閱讀章節、讀取與回報閱讀進度、閱讀統計 |
| `stress.js` | 不停頓地逐步提高每秒請求數（預設到 1000 rps），找出 API 的容量上限 |

## 執行

API 的限流以 IP 計算，k6 的所有虛擬使用者共用一個 IP，壓測時要另外啟動一個關閉限流的 API：

```bash
# 另開一個 API（release 模式需要至少 32 字元的 JWT_SECRET）
SERVER_PORT=18082 RATE_LIMIT_ENABLED=false GIN_MODE=release JWT_SECRET=<32+ 字元> ./server

# 從 repo 根目錄執行（Git Bash 需加 MSYS_NO_PATHCONV=1）
docker run --rm -i -v "$PWD/deploy/loadtest:/scripts" \
  -e BASE_URL=http://host.docker.internal:18082 \
  grafana/k6:1.3.0 run /scripts/browse.js
```

環境變數：

- `BASE_URL`：API 位址，預設 `http://host.docker.internal:18080`
- `VUS`、`DURATION`：`browse.js`／`reader.js` 的虛擬使用者數與穩定期長度
- `LOGIN`、`PASSWORD`：`reader.js` 使用的帳號，預設是 seed 的 `lighthouse01`
- `PEAK_RPS`、`STAGE`：`stress.js` 的最高每秒請求數與每階段長度

章節一律帶 `count_view=false`，壓測不會影響觀看數排行。

## 門檻

- 失敗率 < 1%
- 全部請求 p95 < 300ms
- 首頁、章節 p95 < 200ms
- 回報進度 p95 < 250ms

## 2026-10-16 開發機實測

環境：Windows 11 開發機，API、PostgreSQL、Redis 與 k6（Docker Desktop）都在同一台機器上，資料為 seed 的 6 本小說。

| 腳本 | 負載 | 結果 |
|------|------|------|
| `browse.js` | 50 VUs、1 分鐘 | 6,227 個請求、0 失敗，p95 7.9ms（首頁 13.0ms、章節 12.8ms） |
| `reader.js` | 30 VUs、1 分鐘 | 3,599 個請求，p95 6.9ms（回報進度 12.1ms）；發現並修正同時第一次回報進度會回 500 的問題 |
| `stress.js` | 最高 1,500 rps | 69,006 個請求、0 失敗，p95 3.1ms、p99 5.1ms |
| `stress.js` | 最高 5,000 rps | 227,880 個請求、0 失敗，平均 2,841 rps，p95 104ms、p99 174ms；k6 有 2,118 次來不及送出，表示這台機器約在 3,000 rps 達到上限 |

結論：熱門的公開端點都由 Redis 快取，瓶頸是單機 CPU（k6 與 API 共用），API 本身沒有出現錯誤。正式環境應在獨立的壓測機上，對部署後的 API 重新測量。
