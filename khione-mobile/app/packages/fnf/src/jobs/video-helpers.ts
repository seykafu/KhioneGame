import type { MediaIssue } from '../groups/media'
import type { GenerationInput, MediaInput, MediaRef } from '../types'

export interface Size {
  width: number
  height: number
}

export function refsFor(media: MediaInput | undefined, role: string): MediaRef[] {
  const value = media?.[role]
  return Array.isArray(value) ? value : value ? [value] : []
}

export function firstMetaSize(media: MediaInput | undefined, roles: readonly string[]): Size | undefined {
  for (const role of roles) {
    for (const ref of refsFor(media, role)) {
      const { width, height } = ref.meta ?? {}
      if (width != null && height != null && height > 0)
        return { width, height }
    }
  }
  return undefined
}

export function firstMetaDuration(media: MediaInput | undefined, roles: readonly string[]): number | undefined {
  for (const role of roles) {
    for (const ref of refsFor(media, role)) {
      const seconds = ref.meta?.durationSec
      if (seconds != null)
        return seconds
    }
  }
  return undefined
}

export function integerRange(field: string, value: number | null | undefined, min: number, max: number): MediaIssue[] {
  if (value == null)
    return []
  if (Number.isInteger(value) && value >= min && value <= max)
    return []
  return [{ loc: ['settings', field], msg: `${field} must be an integer between ${min} and ${max}` }]
}

export function requiredPromptOrRole(input: GenerationInput, role: string, message: string): MediaIssue[] {
  const prompt = (input.prompt?.instruction ?? '').trim()
  if (prompt.length > 0 || refsFor(input.media, role).length > 0)
    return []
  return [{ loc: ['prompt'], msg: message }]
}

export function extractAngleRefIds(text: string): string[] {
  const ids = new Set<string>()
  for (const match of text.matchAll(/<<<([^>]+)>>>/g)) {
    const value = match[1]?.trim()
    // `movement:<uuid>` are camera-movement tokens the backend expands itself —
    // not reference elements, so they must not eat a model's media budget
    // (parity with fnf-web's isInternalNonElementMention). `movement--` is the
    // pre-rename namespace still found in old prompt strings.
    if (!value || /^(image|video|audio|cast)_/.test(value) || value.startsWith('movement:') || value.startsWith('movement--'))
      continue
    if (value.startsWith('element_')) {
      const id = value.slice('element_'.length)
      if (id && !/^\d+$/.test(id))
        ids.add(id)
      continue
    }
    ids.add(value)
  }
  return [...ids]
}

/**
 * Every reference element a prompt mentions: the `<<<...>>>` angle form plus
 * the bare `@<uuid>` mention the product's prompt editor also emits. Models
 * that count elements against a media budget (seedance 2.5) must use this,
 * not `extractAngleRefIds` alone, or an @-mentioned element slips the cap.
 */
export function extractReferenceElementIds(text: string): string[] {
  const ids = new Set(extractAngleRefIds(text))
  for (const match of text.matchAll(/(^|[^\w-])@([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})(?=$|[^\w-])/gi))
    ids.add(match[2])
  return [...ids]
}

export function batch(settings: Record<string, unknown>, fallback = 1): number {
  return typeof settings.batchSize === 'number' ? settings.batchSize : fallback
}
