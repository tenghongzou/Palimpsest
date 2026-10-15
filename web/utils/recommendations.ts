// Personalized recommendations (GET /recommendations) and similar novels
// (GET /novels/{id}/similar): response normalization and the reason line.
import type { components } from '~/types/api'
import type { Novel } from '~/types/novel'
import type { Translate } from '~/utils/format'

export type ApiRecommendations = components['schemas']['Recommendations']
export type ApiRecommendation = components['schemas']['Recommendation']
export type RecommendationReason = components['schemas']['RecommendationReason']
export type RecommendationReasonType = RecommendationReason['type']

export interface RecommendedNovel {
  novel: Novel
  reason: RecommendationReason
}

export interface RecommendationList {
  personalized: boolean
  items: RecommendedNovel[]
}

const REASON_TYPES: readonly RecommendationReasonType[] = ['category', 'tag', 'author', 'popular']

function isNovel(value: unknown): value is Novel {
  const n = value as Partial<Novel> | null | undefined
  return !!n && typeof n.id === 'string' && !!n.id && typeof n.title === 'string'
}

/** Coerces an unknown reason (older or newer servers) into one the UI can phrase. */
export function normalizeReason(reason: Partial<RecommendationReason> | null | undefined): RecommendationReason {
  const type = REASON_TYPES.includes(reason?.type as RecommendationReasonType) ? reason!.type! : 'popular'
  const value = typeof reason?.value === 'string' ? reason.value.trim() : ''
  // A category/tag/author reason without a name cannot be phrased: say "popular".
  if (type !== 'popular' && !value) return { type: 'popular', value: '' }
  return { type, value: type === 'popular' ? '' : value }
}

/** Drops malformed and duplicate entries from GET /recommendations. */
export function normalizeRecommendations(data: Partial<ApiRecommendations> | null | undefined): RecommendationList {
  const seen = new Set<string>()
  const items: RecommendedNovel[] = []
  for (const item of Array.isArray(data?.items) ? data.items : []) {
    const novel = (item as Partial<ApiRecommendation> | null)?.novel as unknown
    if (!isNovel(novel) || seen.has(novel.id)) continue
    seen.add(novel.id)
    items.push({ novel, reason: normalizeReason((item as ApiRecommendation).reason) })
  }
  return { personalized: data?.personalized === true && items.length > 0, items }
}

/** Similar novels without malformed entries, duplicates or the novel itself. */
export function normalizeSimilar(data: unknown, selfId: string): Novel[] {
  const seen = new Set<string>([selfId])
  const out: Novel[] = []
  for (const novel of Array.isArray(data) ? data as unknown[] : []) {
    if (!isNovel(novel) || seen.has(novel.id)) continue
    seen.add(novel.id)
    out.push(novel)
  }
  return out
}

/** The small "why" line under a recommended novel, in the UI language. */
export function recommendationReasonText(t: Translate, reason: Partial<RecommendationReason> | null | undefined): string {
  const r = normalizeReason(reason)
  return r.type === 'popular'
    ? t('recommend.reason.popular')
    : t(`recommend.reason.${r.type}`, { name: r.value })
}
