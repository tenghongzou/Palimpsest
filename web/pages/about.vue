<template>
  <article class="max-w-3xl mx-auto space-y-6 leading-relaxed">
    <h1 class="text-2xl font-bold">關於 Palimpsest</h1>
    <p>
      Palimpsest 是一個中文小說閱讀平台。你可以在書城瀏覽與搜尋作品、依分類與排行榜找書，
      在可自訂字體、行距與主題的閱讀器中閱讀，並在網頁與 App 之間同步書架、閱讀進度與書籤。
    </p>
    <h2 class="text-lg font-semibold">特色</h2>
    <ul class="list-disc pl-6 space-y-1">
      <li>繁體與簡體中文即時轉換，英文翻譯（需平台啟用翻譯服務）</li>
      <li>離線閱讀：讀過的章節會保存在裝置上，沒有網路也能繼續讀，恢復連線後自動同步進度與書籤</li>
      <li>書評、章節留言與按讚，和其他讀者交流</li>
    </ul>
    <p class="text-sm text-gray-500">
      使用前請參閱<NuxtLink to="/terms" class="text-primary">服務條款</NuxtLink>與<NuxtLink to="/privacy" class="text-primary">隱私政策</NuxtLink>。
    </p>
  </article>
</template>

<script setup lang="ts">
useHead({ title: '關於 — Palimpsest' })
</script>
