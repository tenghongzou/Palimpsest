// Paragraph comments (段落評論). Paragraph indexes are positions in
// splitParagraphs(content) — the same list the reader renders as [data-p] and
// that bookmarks and reading progress use (blank lines are not paragraphs; the
// Flutter app splits on '\n', trims and drops empty lines the same way).
import type { ApiParagraphCount } from '~/types/models'
import { splitParagraphs } from '~/utils/text'

export type ParagraphCounts = Record<number, number>

/**
 * Turns GET /chapters/{id}/comments/paragraph-counts into an index → count
 * map. Entries outside the chapter's paragraphs (e.g. after the text was
 * edited) or without comments are dropped; duplicates are summed.
 */
export function paragraphCountMap(list: ApiParagraphCount[] | null | undefined, paragraphTotal?: number): ParagraphCounts {
  const out: ParagraphCounts = {}
  for (const entry of list ?? []) {
    const index = Number(entry?.paragraph_index)
    const count = Number(entry?.count)
    if (!Number.isInteger(index) || index < 0) continue
    if (paragraphTotal !== undefined && index >= paragraphTotal) continue
    if (!Number.isFinite(count) || count <= 0) continue
    out[index] = (out[index] ?? 0) + Math.floor(count)
  }
  return out
}

/** Total comments across paragraphs. */
export function totalParagraphComments(counts: ParagraphCounts): number {
  return Object.values(counts).reduce((sum, n) => sum + n, 0)
}

/**
 * Whether `displayed` text has the same paragraphs as `original`, so indexes
 * from the original chapter can be shown on it (e.g. on a translation).
 */
export function paragraphsAligned(original: string | null | undefined, displayed: string | null | undefined): boolean {
  if (displayed == null || displayed === original) return true
  return splitParagraphs(original).length === splitParagraphs(displayed).length
}

export type ThreadPanel = { kind: 'paragraph', index: number } | { kind: 'chapter' }

/**
 * Which comments panel shows a thread (GET /comments/{id}): its paragraph's
 * panel when it is a paragraph comment that exists in the shown text,
 * otherwise the whole-chapter comments.
 */
export function threadPanel(
  thread: { paragraph_index?: number | null } | null | undefined,
  paragraphTotal: number,
  aligned = true,
): ThreadPanel {
  const index = thread?.paragraph_index
  if (aligned && typeof index === 'number' && Number.isInteger(index) && index >= 0 && index < paragraphTotal) {
    return { kind: 'paragraph', index }
  }
  return { kind: 'chapter' }
}

/** A short excerpt of a paragraph for the comment drawer heading. */
export function paragraphExcerpt(text: string | null | undefined, max = 80): string {
  const s = (text ?? '').trim()
  return s.length > max ? `${s.slice(0, max)}…` : s
}
