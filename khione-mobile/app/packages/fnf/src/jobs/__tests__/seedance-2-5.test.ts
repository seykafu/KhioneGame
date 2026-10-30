import type { MediaRef } from '../../types'
import { describe, expect, it } from 'vitest'
import { buildWireParams, parseGeneration } from '../../spec'
import { seedance2_5, SEEDANCE25_MAX_IMAGES, SEEDANCE25_MAX_VIDEOS } from '../seedance-2-5'

function ref(id: string, meta?: MediaRef['meta']): MediaRef {
  return { id, type: 'media_input', url: `https://cdn/${id}`, ...(meta ? { meta } : {}) }
}

function issuesOf(fn: () => unknown): string[] {
  try {
    fn()
    return []
  }
  catch (err) {
    const issues = (err as { data?: { issues?: Array<{ msg: string }> } }).data?.issues ?? []
    return issues.map(i => i.msg)
  }
}

function wireFor(input: Parameters<typeof buildWireParams>[0]): Record<string, unknown> {
  return buildWireParams(input, seedance2_5)
}

describe('seedance2_5 wire shape', () => {
  it('builds the default-model wire: canonical names, table dims, wrapped medias', () => {
    const wire = wireFor({
      model: 'seedance_2_5',
      prompt: { instruction: 'a cat walking' },
      media: { image: [ref('i1')], audio: ref('a1', { durationSec: 10 }) },
      settings: { duration: 8, resolution: '1080p', aspectRatio: '9:16', batchSize: 2 },
    })

    expect(wire.prompt).toBe('a cat walking')
    expect(wire.duration).toBe(8)
    expect(wire.resolution).toBe('1080p')
    expect(wire.aspect_ratio).toBe('9:16')
    expect(wire.batch_size).toBe(2)
    expect(wire.model).toBe('default')
    // camelCase settings never leak to the wire
    expect(wire).not.toHaveProperty('aspectRatio')
    expect(wire).not.toHaveProperty('batchSize')
    // 1080p × 9:16 from the size table
    expect(wire.width).toBe(1080)
    expect(wire.height).toBe(1920)
    expect(wire.medias).toEqual([
      { role: 'image', data: { id: 'i1', type: 'media_input', url: 'https://cdn/i1' } },
      { role: 'audio', data: { id: 'a1', type: 'media_input', url: 'https://cdn/a1' } },
    ])
  })

  it('applies the product defaults (720p / 16:9 / high bitrate / audio on)', () => {
    const wire = wireFor({ model: 'seedance_2_5', prompt: { instruction: 'x' }, settings: {} })
    expect(wire.resolution).toBe('720p')
    expect(wire.aspect_ratio).toBe('16:9')
    expect(wire.bitrate_mode).toBe('high')
    expect(wire.generate_audio).toBe(true)
    expect(wire.duration).toBe(5)
    expect(wire.batch_size).toBe(1)
    expect(wire.width).toBe(1280)
    expect(wire.height).toBe(720)
  })

  it('video_edit sends neither duration nor aspect_ratio (both come from the source clip)', () => {
    const wire = wireFor({
      model: 'seedance_2_5',
      prompt: { instruction: 'make it night' },
      media: { video: ref('v1', { durationSec: 120 }) },
      settings: { model: 'video_edit', duration: 8, aspectRatio: '9:16' },
    })
    expect(wire.model).toBe('video_edit')
    expect(wire).not.toHaveProperty('duration')
    expect(wire).not.toHaveProperty('aspect_ratio')
    expect(wire).not.toHaveProperty('extension_mode')
    // the box still ships, derived from resolution × ratio
    expect(wire.width).toBe(720)
    expect(wire.height).toBe(1280)
  })

  it('video_extension sends duration + extension_mode but no aspect_ratio', () => {
    const wire = wireFor({
      model: 'seedance_2_5',
      prompt: { instruction: 'keep going' },
      media: { video: ref('v1', { durationSec: 6 }) },
      settings: { model: 'video_extension', extensionMode: 'forward', duration: 10 },
    })
    expect(wire.model).toBe('video_extension')
    expect(wire.duration).toBe(10)
    expect(wire.extension_mode).toBe('forward')
    expect(wire).not.toHaveProperty('aspect_ratio')
  })
})

describe('seedance2_5 validate', () => {
  const base = { model: 'seedance_2_5', prompt: { instruction: 'x' } } as const

  it('requires a prompt', () => {
    expect(issuesOf(() => wireFor({ model: 'seedance_2_5', media: { image: ref('i1') }, settings: {} })))
      .toContain('Prompt is required')
  })

  it('rejects a duration outside 4–30 and a batch outside 1–4', () => {
    const issues = issuesOf(() => wireFor({ ...base, settings: { duration: 45, batchSize: 9 } }))
    expect(issues).toContain('duration must be an integer between 4 and 30')
    expect(issues).toContain('batchSize must be an integer between 1 and 4')
  })

  it('video_edit needs exactly one video; video_extension needs a video and a mode', () => {
    expect(issuesOf(() => wireFor({ ...base, settings: { model: 'video_edit' } })))
      .toContain('Seedance 2.5 video edit requires exactly one video reference')
    expect(issuesOf(() => wireFor({ ...base, media: { video: [ref('v1'), ref('v2')] }, settings: { model: 'video_edit' } })))
      .toContain('Seedance 2.5 video edit requires exactly one video reference')

    const extension = issuesOf(() => wireFor({ ...base, settings: { model: 'video_extension' } }))
    expect(extension).toContain('Seedance 2.5 video extension requires a video reference')
    expect(extension).toContain('extensionMode is required for video extension')
  })

  it('video_extension caps duration at 30 with its own message', () => {
    expect(issuesOf(() => wireFor({
      ...base,
      media: { video: ref('v1') },
      settings: { model: 'video_extension', extensionMode: 'backward', duration: 40 },
    }))).toContain('Seedance 2.5 video extension supports at most 30 seconds')
  })

  it('video_edit skips the duration checks the reference budget would apply', () => {
    // a 2-minute source clip is the SUBJECT of an edit, not a reference
    expect(issuesOf(() => wireFor({
      ...base,
      media: { video: ref('v1', { durationSec: 120 }) },
      settings: { model: 'video_edit', duration: 99 },
    }))).toEqual([])
    // the same clip attached to a default generation is over the budget
    expect(issuesOf(() => wireFor({ ...base, media: { video: ref('v1', { durationSec: 120 }) }, settings: {} })))
      .toContain('Each reference video must be at least 2 seconds and no more than 30 seconds')
  })

  it('enforces the per-role media caps', () => {
    const videos = Array.from({ length: SEEDANCE25_MAX_VIDEOS + 1 }, (_, i) => ref(`v${i}`, { durationSec: 2 }))
    expect(issuesOf(() => wireFor({ ...base, media: { video: videos }, settings: {} })))
      .toContain(`You can add a maximum of ${SEEDANCE25_MAX_VIDEOS} videos`)
  })

  it('counts prompt reference elements against the image budget', () => {
    const images = Array.from({ length: SEEDANCE25_MAX_IMAGES }, (_, i) => ref(`i${i}`))
    // 30 images alone is exactly the cap
    expect(issuesOf(() => wireFor({ ...base, media: { image: images }, settings: {} }))).toEqual([])
    // one element mentioned in the prompt pushes it over
    expect(issuesOf(() => wireFor({
      model: 'seedance_2_5',
      prompt: { instruction: 'with <<<element_abc-1>>>' },
      media: { image: images },
      settings: {},
    }))).toContain(`You can add a maximum of ${SEEDANCE25_MAX_IMAGES} images`)
  })

  it('bounds each audio reference and the combined audio budget', () => {
    expect(issuesOf(() => wireFor({ ...base, media: { audio: ref('a1', { durationSec: 45 }) }, settings: {} })))
      .toContain('Each reference audio file must be at least 2 seconds and no more than 30 seconds')
    expect(issuesOf(() => wireFor({
      ...base,
      media: { audio: [ref('a1', { durationSec: 20 }), ref('a2', { durationSec: 20 })] },
      settings: {},
    }))).toContain('The total audio duration limit is 30 seconds')
  })
})

describe('seedance2_5 round-trip', () => {
  it('a default generation resubmits to the same wire', () => {
    const wire = wireFor({
      model: 'seedance_2_5',
      prompt: { instruction: 'a cat' },
      media: { start_image: ref('s1') },
      settings: { duration: 12, resolution: '480p', aspectRatio: '4:3', generateAudio: false, bitrateMode: 'standard' },
    })
    const gen = parseGeneration({ id: 'j1', status: 'completed', result_url: 'https://x/v.mp4', params: wire }, seedance2_5)
    expect(gen.input.settings).toMatchObject({
      duration: 12,
      resolution: '480p',
      aspectRatio: '4:3',
      generateAudio: false,
      bitrateMode: 'standard',
      model: 'default',
    })
    expect(buildWireParams(gen.input, seedance2_5)).toEqual(wire)
  })

  it('restore recovers a video_edit ratio from the stored dims, not the 16:9 default', () => {
    const wire = wireFor({
      model: 'seedance_2_5',
      prompt: { instruction: 'recolor' },
      media: { video: ref('v1', { durationSec: 9 }) },
      settings: { model: 'video_edit', resolution: '720p', aspectRatio: '9:16' },
    })
    expect(wire).not.toHaveProperty('aspect_ratio') // finalize dropped it

    const gen = parseGeneration({ id: 'j2', status: 'completed', result_url: 'https://x/v.mp4', params: wire }, seedance2_5)
    expect(gen.input.settings).toMatchObject({ model: 'video_edit', aspectRatio: '9:16' })
    // the resubmitted box matches the original, not 1280×720
    expect(buildWireParams(gen.input, seedance2_5)).toEqual(wire)
  })
})
