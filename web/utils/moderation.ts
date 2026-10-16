// Pure helpers for the admin moderation page (GET /admin/moderation/queue etc.).
import type { components } from '~/types/api'

type ModerationFlag = components['schemas']['ModerationFlag']
type Translate = (key: string, named?: Record<string, unknown>) => string

/** Flag codes the API documents; labels are `admin.moderationQueue.flags.<code>`. */
export const MODERATION_FLAG_CODES = [
  'blocked_term',
  'flagged_term',
  'link',
  'contact_info',
  'repetition',
  'shouting',
  'ai_harassment',
  'ai_hate',
  'ai_sexual',
  'ai_spam',
  'ai_violence',
  'ai_other',
] as const

export const MODERATION_QUEUES = ['pending', 'flagged'] as const
export type ModerationQueue = typeof MODERATION_QUEUES[number]
export const MODERATION_TYPES = ['review', 'comment'] as const
export type ModerationItemType = typeof MODERATION_TYPES[number]
export const MODERATION_DECISIONS = ['approved', 'rejected', 'hidden'] as const
export type ModerationDecision = typeof MODERATION_DECISIONS[number]
export const MODERATION_SEVERITIES = ['block', 'flag'] as const
export const TERM_MAX_LENGTH = 50

/** A flag code's label in the UI language; unknown codes are shown as is. */
export function flagLabel(t: Translate, code: string): string {
  return (MODERATION_FLAG_CODES as readonly string[]).includes(code)
    ? t(`admin.moderationQueue.flags.${code}`)
    : code
}

/** A flag chip's text: the label, plus the detail (e.g. the matched term) when present. */
export function flagText(t: Translate, flag: ModerationFlag): string {
  const label = flagLabel(t, flag.code)
  const detail = flag.detail?.trim()
  return detail ? t('admin.moderationQueue.flagWithDetail', { label, detail }) : label
}

/** True for flags raised by the AI review rather than the rule checks. */
export function isAiFlag(code: string): boolean {
  return code.startsWith('ai_')
}

export type RiskLevel = 'low' | 'medium' | 'high'

/** Buckets a 0..1 risk score. */
export function riskLevel(score: number | null | undefined): RiskLevel {
  const n = Number(score) || 0
  if (n >= 0.7) return 'high'
  if (n >= 0.4) return 'medium'
  return 'low'
}

/** A 0..1 score as a whole percentage, clamped. */
export function riskPercent(score: number | null | undefined): number {
  const n = Number(score)
  if (!Number.isFinite(n)) return 0
  return Math.round(Math.min(Math.max(n, 0), 1) * 100)
}

/** Naive UI tag/progress status for a risk level. */
export function riskStatus(level: RiskLevel): 'success' | 'warning' | 'error' {
  return level === 'high' ? 'error' : level === 'medium' ? 'warning' : 'success'
}

export type TermError = 'required' | 'tooLong'

/** Validates a new moderation term (1..50 characters after trimming). */
export function validateTerm(term: string | null | undefined): TermError | null {
  const value = (term ?? '').trim()
  if (!value) return 'required'
  if ([...value].length > TERM_MAX_LENGTH) return 'tooLong'
  return null
}

/** The queue key of an item, unique across reviews and comments. */
export function itemKey(item: { type: string, id: string }): string {
  return `${item.type}:${item.id}`
}

/** Items without the given keys (see itemKey). */
export function withoutItems<T extends { type: string, id: string }>(items: T[], keys: Iterable<string>): T[] {
  const drop = new Set(keys)
  return items.filter(item => !drop.has(itemKey(item)))
}

/** The page to reload after items were removed: the same one unless it no longer exists. */
export function pageAfterRemoval(page: number, pageSize: number, total: number): number {
  const last = Math.max(1, Math.ceil(Math.max(0, total) / Math.max(1, pageSize)))
  return Math.min(Math.max(1, page), last)
}
