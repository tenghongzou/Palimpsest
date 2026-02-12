import { setup } from '@css-render/vue3-ssr'

export default defineNuxtPlugin((nuxtApp) => {
  if (import.meta.server) {
    const { collect } = setup(nuxtApp.vueApp)
    nuxtApp.ssrContext!.head.push({
      style: () =>
        collect()
          .split('</style>')
          .filter(Boolean)
          .map((block) => {
            const id = block.match(/cssr-id="([^"]*)"/)
            return {
              'children': block + '</style>',
              'cssr-id': id?.[1],
            }
          }),
    })
  }
})
