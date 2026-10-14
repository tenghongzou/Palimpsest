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
            // `children` is the CSS only; head renders the <style> tag itself.
            return {
              'children': block.replace(/^\s*<style[^>]*>/, ''),
              'cssr-id': id?.[1],
            }
          }),
    })
  }
})
