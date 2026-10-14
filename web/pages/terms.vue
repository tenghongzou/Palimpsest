<template>
  <article class="max-w-3xl mx-auto space-y-6 leading-relaxed">
    <h1 class="text-2xl font-bold">服務條款</h1>
    <n-alert type="warning" :show-icon="false">
      本頁為草稿，正式上線前須經法務審閱並補上營運主體、聯絡方式與適用法律。
    </n-alert>

    <section class="space-y-2">
      <h2 class="text-lg font-semibold">帳號</h2>
      <p>註冊時請提供正確的電子郵件，並妥善保管密碼。透過你的帳號進行的操作視為你本人的行為。</p>
    </section>

    <section class="space-y-2">
      <h2 class="text-lg font-semibold">使用者內容</h2>
      <p>你在書評與留言中發表的內容由你負責。請勿張貼違法、騷擾、仇恨、垃圾訊息或侵害他人權利（包括著作權）的內容，也請避免未加提示的劇透。</p>
      <p>其他讀者可以檢舉內容；管理員可依檢舉或本條款隱藏、刪除內容，或停用違規帳號。</p>
    </section>

    <section class="space-y-2">
      <h2 class="text-lg font-semibold">作品著作權</h2>
      <p>平台上的作品著作權屬於原作者或權利人。作品僅供個人閱讀，請勿未經授權重製或散布。離線下載的章節僅能在本服務中閱讀。</p>
    </section>

    <section class="space-y-2">
      <h2 class="text-lg font-semibold">翻譯</h2>
      <p>繁簡轉換與機器翻譯的結果僅供參考，可能與原文有出入。</p>
    </section>

    <section class="space-y-2">
      <h2 class="text-lg font-semibold">使用限制</h2>
      <p>為維持服務穩定，系統會限制每分鐘的請求次數。請勿以自動化程式大量擷取內容。</p>
    </section>
  </article>
</template>

<script setup lang="ts">
import { NAlert } from 'naive-ui'

useHead({ title: '服務條款 — Palimpsest' })
</script>
