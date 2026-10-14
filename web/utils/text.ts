/** Splits chapter text into the paragraphs the reader shows (blank lines dropped). */
export function splitParagraphs(content: string | null | undefined): string[] {
  if (!content) return []
  return content.split(/\r?\n/).map(p => p.trim()).filter(Boolean)
}
