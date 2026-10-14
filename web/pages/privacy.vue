<template>
  <article class="max-w-3xl mx-auto space-y-6 leading-relaxed">
    <h1 class="text-2xl font-bold">隱私政策</h1>
    <n-alert type="warning" :show-icon="false">
      本頁為草稿，依目前系統實際蒐集與處理的資料撰寫；正式上線前須經法務審閱，並補上營運主體與聯絡方式。
    </n-alert>

    <section class="space-y-2">
      <h2 class="text-lg font-semibold">我們保存的資料</h2>
      <ul class="list-disc pl-6 space-y-1">
        <li><strong>帳號資料：</strong>帳號名稱、電子郵件、暱稱、個人簡介、頭像，以及經過雜湊處理的密碼（我們無法得知你的密碼原文）。</li>
        <li><strong>閱讀資料：</strong>書架、閱讀進度、閱讀紀錄與閱讀時間、書籤、閱讀設定，用於跨裝置同步與閱讀統計。</li>
        <li><strong>社群內容：</strong>你發表的書評、留言、按讚與檢舉。書評與留言會公開顯示你的帳號名稱、暱稱與頭像，不會顯示電子郵件。</li>
        <li><strong>技術資料：</strong>為了限制請求頻率，系統會短暫記錄 IP 位址與帳號的請求次數（約一分鐘後失效）。伺服器日誌可能包含 IP 位址與請求路徑。</li>
      </ul>
    </section>

    <section class="space-y-2">
      <h2 class="text-lg font-semibold">儲存在你裝置上的資料</h2>
      <p>網頁版以 Cookie 保存登入狀態，並把讀過的章節、進度與書籤存在瀏覽器（IndexedDB）中以便離線閱讀；App 則存在裝置的本機資料庫。登出時會清除屬於該帳號的本機資料。</p>
    </section>

    <section class="space-y-2">
      <h2 class="text-lg font-semibold">第三方服務</h2>
      <p>當你使用英文翻譯時，章節或選取的文字會傳送給 Google Cloud Translation 進行翻譯。重設密碼時，我們會透過電子郵件服務寄送重設連結。</p>
    </section>

    <section class="space-y-2">
      <h2 class="text-lg font-semibold">你的權利</h2>
      <p>你可以隨時在「設定」中修改個人資料與閱讀設定、刪除書籤、書評與留言。如需刪除帳號或取得資料副本，請聯絡我們。</p>
    </section>
  </article>
</template>

<script setup lang="ts">
import { NAlert } from 'naive-ui'

useHead({ title: '隱私政策 — Palimpsest' })
</script>
