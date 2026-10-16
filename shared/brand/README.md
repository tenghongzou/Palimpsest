# Palimpsest 品牌素材

Logo 的意象是「重寫本」：一張米色紙頁疊在淡藍色的舊 P 上，右上角折起。

## 檔案

| 檔案 | 用途 |
|------|------|
| `logo-mark.svg` | 方形圖示（App 圖示、favicon 的來源） |
| `logo-horizontal.svg` / `logo-horizontal-dark.svg` | 橫式 logo：網站 header、App 標題列、桌面側欄。`-dark` 用於深色背景 |
| `logo-stacked.svg` / `logo-stacked-dark.svg` | 直式 logo：登入頁、啟動畫面、宣傳素材 |
| `wordmark.svg` | 只有「Palimpsest」字標，填色為 `currentColor`，內嵌時跟隨文字顏色 |
| `png/` | 以上 SVG 的透明背景 PNG（檔名後綴為高度 px） |
| `concepts/` | 以 Grok 產生的圖示概念草圖與比較圖（採用候選 E 的概念） |
| `source/` | 字標外框資料與產生 SVG 的腳本 |

各平台實際使用的檔案：

- App 圖示：`mobile/assets/icon/`（由 `flutter_launcher_icons` 產生 Android／iOS 圖示，`mobile/tool/gen_desktop_icons.py` 產生桌面版圖示）
- 網站圖示：`web/public/favicon.*`、`apple-touch-icon.png`、`icon-*.png`

## 規範

- **顏色**
  - 品牌藍 `#1890FF` → `#0E7BE8`（漸層）
  - 紙頁米色 `#F5F0E0`、折角 `#DDD2B4`
  - 舊 P 淡藍 `#5FAFF5`
  - 字標：淺色背景用 `#1F2937`，深色背景用 `#F5F0E0`
- **字型**：字標為 [Libre Baskerville](https://fonts.google.com/specimen/Libre+Baskerville) Bold（SIL Open Font License），已轉成外框路徑，使用時不需要安裝字型。
- **留白**：logo 四周至少保留圖示高度的 1/4。
- **最小尺寸**：橫式 logo 高度不小於 20px；更小時只用方形圖示。
- 不要改變圖示與字標的比例、顏色，或替字標套用其他字型。

## 重新產生

需要 Python（`fonttools`）與 Libre Baskerville 的可變字型檔：

```bash
cd shared/brand/source
python wordmark.py LibreBaskerville[wght].ttf '{"wght":700}' 0 wordmark-libre-baskerville.json
# 再以 compose.py 的 horizontal()/stacked()/wordmark() 組出 SVG
```
