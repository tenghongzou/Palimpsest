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
