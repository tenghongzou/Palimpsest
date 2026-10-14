export function formatWordCount(count: number): string {
  if (count >= 10000) {
    return `${(count / 10000).toFixed(1)} 萬字`
  }
  return `${count} 字`
}

export function formatViewCount(count: number): string {
  if (count >= 100000000) {
    return `${(count / 100000000).toFixed(1)} 億`
  }
  if (count >= 10000) {
    return `${(count / 10000).toFixed(1)} 萬`
  }
  return count.toString()
}

export function formatRelativeTime(date: string | Date): string {
  const now = new Date()
  const target = new Date(date)
  const diffMs = now.getTime() - target.getTime()
  const diffMins = Math.floor(diffMs / 60000)
  const diffHrs = Math.floor(diffMs / 3600000)
  const diffDays = Math.floor(diffMs / 86400000)

  if (diffMins < 1) return '剛剛'
  if (diffMins < 60) return `${diffMins} 分鐘前`
  if (diffHrs < 24) return `${diffHrs} 小時前`
  if (diffDays < 30) return `${diffDays} 天前`
  return target.toLocaleDateString('zh-TW')
}

export const NOVEL_STATUS: Record<string, { label: string, type: 'success' | 'warning' | 'info' }> = {
  ongoing: { label: '連載中', type: 'success' },
  completed: { label: '已完結', type: 'info' },
  hiatus: { label: '暫停', type: 'warning' },
}

/** Seconds as "N 小時 M 分鐘" / "M 分鐘". */
export function formatDuration(seconds: number): string {
  const s = Math.max(0, Math.floor(seconds || 0))
  const hours = Math.floor(s / 3600)
  const minutes = Math.floor((s % 3600) / 60)
  if (hours > 0) return minutes ? `${hours} 小時 ${minutes} 分鐘` : `${hours} 小時`
  return `${minutes} 分鐘`
}

export function formatDateTime(date: string | Date | null | undefined): string {
  if (!date) return ''
  const d = new Date(date)
  if (Number.isNaN(d.getTime())) return ''
  return d.toLocaleString('zh-TW', { hour12: false, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })
}

const NUMBERED_TITLE = /^\s*第\s*[0-9０-９零〇一二兩三四五六七八九十百千萬]+\s*[章回節卷]/

/** A chapter's label in lists: "第3章 標題", unless the title already carries its own number. */
export function chapterLabel(number: number, title: string): string {
  if (NUMBERED_TITLE.test(title)) return title
  return title ? `第${number}章 ${title}` : `第${number}章`
}
