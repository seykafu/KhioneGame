import type { MediaIssue } from '../groups/media'
import type { MediaInput } from '../types'
import { defineJob } from '../define-job'
import { z } from '../z'
import { oneOf, promptMax, promptRequired } from './checks'
import { closestRatioBySize, lookupSize } from './dimensions'
import { extractReferenceElementIds, integerRange, refsFor } from './video-helpers'

/**
 * Seedance 2.5 — the multi-reference video model. Ported from fnf-web's
 * `packages/fnf/src/jobs/seedance-2-5.ts` (+ `seedance-2-5-base.ts`, which
 * upstream extracted only because CS4.0 and the two edit jobs share the
 * tables; this catalog carries the one job, so the tables live here).
 *
 * Wire surface: POST /jobs/v2/seedance_2_5 with wrapped `medias`, explicit
 * width/height, and a `model` discriminator that changes which fields ship —
 * see `finalize`.
 *
 * Not ported deliberately: upstream's `business` group (`use_unlim`,
 * `use_free_gens`, `use_generation_seconds`). Those spend a Higgsfield user's
 * unlimited/free-generation grants, which app-built surfaces do not own — the
 * backend defaults them to false. Same call as `seedance2_0` in this catalog.
 */

/** Allowed aspect ratios as a named, refactorable object enum (erased at runtime). */
export const Seedance25AspectRatio = {
  r21x9: '21:9',
  r16x9: '16:9',
  r4x3: '4:3',
  r1x1: '1:1',
  r3x4: '3:4',
  r9x16: '9:16',
} as const

export const Seedance25Resolution = {
  r480: '480p',
  r720: '720p',
  r1080: '1080p',
} as const

/**
 * The wire `model` discriminator — one job set type, three shapes:
 * `default` generates, `video_edit` rewrites one attached video, and
 * `video_extension` continues one backward/forward.
 */
export const Seedance25Model = {
  default: 'default',
  videoEdit: 'video_edit',
  videoExtension: 'video_extension',
} as const

export const Seedance25ExtensionMode = {
  backward: 'backward',
  forward: 'forward',
} as const

export const Seedance25BitrateMode = {
  standard: 'standard',
  high: 'high',
} as const

const ASPECT_RATIOS = Object.values(Seedance25AspectRatio)
const RESOLUTIONS = Object.values(Seedance25Resolution)
const MODELS = Object.values(Seedance25Model)
const EXTENSION_MODES = Object.values(Seedance25ExtensionMode)
const BITRATE_MODES = Object.values(Seedance25BitrateMode)
const MEDIA_ROLES = ['image', 'start_image', 'end_image', 'video', 'audio'] as const
const IMAGE_ROLES = ['image', 'start_image', 'end_image'] as const

export const SEEDANCE_2_5_MAX_PROMPT_LENGTH = 60_000
export const SEEDANCE25_MAX_IMAGES = 30
export const SEEDANCE25_MAX_VIDEOS = 10
export const SEEDANCE25_MAX_AUDIOS = 10
export const SEEDANCE25_MAX_INPUT_MEDIA = 50
export const SEEDANCE25_MIN_MEDIA_DURATION = 2
export const SEEDANCE25_MAX_AUDIO_DURATION = 30
export const SEEDANCE25_MAX_TOTAL_VIDEO_DURATION = 30
export const SEEDANCE25_MAX_TOTAL_AUDIO_DURATION = 30

type AspectRatio = typeof ASPECT_RATIOS[number]
type Resolution = typeof RESOLUTIONS[number]
type Model = typeof MODELS[number]
type ExtensionMode = typeof EXTENSION_MODES[number]
type BitrateMode = typeof BITRATE_MODES[number]
export type Seedance25ModelValue = Model

/**
 * The render boxes, keyed `resolution × ratio`. Mirrors fnf-web's
 * SEEDANCE_2_5_SIZE_MAP; 1080p rows follow the same ratios at 1080 base.
 */
const SIZE_MAP: Record<Resolution, Record<AspectRatio, [number, number]>> = {
  '480p': { '21:9': [896, 384], '16:9': [854, 480], '4:3': [640, 480], '1:1': [480, 480], '3:4': [480, 640], '9:16': [480, 854] },
  '720p': { '21:9': [1344, 576], '16:9': [1280, 720], '4:3': [960, 720], '1:1': [720, 720], '3:4': [720, 960], '9:16': [720, 1280] },
  '1080p': { '21:9': [2016, 864], '16:9': [1920, 1080], '4:3': [1440, 1080], '1:1': [1080, 1080], '3:4': [1080, 1440], '9:16': [1080, 1920] },
}

// ── media budgets ──
//
// These live in `validate` rather than in the media declaration's
// `counts`/`rules` because both inputs the product counts are outside a
// MediaRule's reach: reference elements embedded in the PROMPT eat the image
// and total budgets, and the video-duration rules are switched off in
// `video_edit` mode (the attached video is the subject, not a reference).

export type Seedance25MediaLimitCode = 'seedance-2-5-media-limit' | 'seedance-2-5-image-limit' | 'seedance-2-5-video-limit' | 'seedance-2-5-audio-limit'
export type Seedance25MediaDurationCode = 'seedance-2-5-audio-duration' | 'seedance-2-5-video-duration' | 'seedance-2-5-video-duration-budget' | 'seedance-2-5-audio-duration-budget'
export type Seedance25ValidationCode = Seedance25MediaLimitCode | Seedance25MediaDurationCode

export interface Seedance25MediaCounts {
  imageCount: number
  videoCount: number
  audioCount: number
  totalCount: number
  referenceElementCount?: number
}

/**
 * Pydantic-shaped issue with the product's stable `code` alongside — surfaces
 * key on the code to render a targeted message; `checkMedia`/`validate`
 * consumers that only read `loc`/`msg` are unaffected.
 */
export interface Seedance25ValidationIssue extends MediaIssue {
  code: Seedance25ValidationCode
}

export function getSeedance25MediaLimitIssues({
  imageCount,
  videoCount,
  audioCount,
  totalCount,
  referenceElementCount = 0,
}: Seedance25MediaCounts): Seedance25ValidationIssue[] {
  const issues: Seedance25ValidationIssue[] = []
  if (imageCount + referenceElementCount > SEEDANCE25_MAX_IMAGES)
    issues.push({ code: 'seedance-2-5-image-limit', loc: ['media', 'image'], msg: `You can add a maximum of ${SEEDANCE25_MAX_IMAGES} images` })
  if (videoCount > SEEDANCE25_MAX_VIDEOS)
    issues.push({ code: 'seedance-2-5-video-limit', loc: ['media', 'video'], msg: `You can add a maximum of ${SEEDANCE25_MAX_VIDEOS} videos` })
  if (audioCount > SEEDANCE25_MAX_AUDIOS)
    issues.push({ code: 'seedance-2-5-audio-limit', loc: ['media', 'audio'], msg: `You can add a maximum of ${SEEDANCE25_MAX_AUDIOS} audios` })
  if (totalCount + referenceElementCount > SEEDANCE25_MAX_INPUT_MEDIA)
    issues.push({ code: 'seedance-2-5-media-limit', loc: ['media'], msg: `You can add a maximum of ${SEEDANCE25_MAX_INPUT_MEDIA} input media items, including Elements` })
  return issues
}

export interface Seedance25DurationRef {
  durationSec?: number | null
}

/**
 * Per-ref and combined duration bounds. A ref whose duration is unknown is
 * skipped — meta is local knowledge (populate it from app data or
 * `resolveMediaMeta`), and the backend re-validates regardless.
 */
export function getSeedance25MediaDurationIssues(
  model: Model,
  videos: readonly Seedance25DurationRef[],
  audios: readonly Seedance25DurationRef[],
): Seedance25ValidationIssue[] {
  const issues: Seedance25ValidationIssue[] = []
  for (const audio of audios) {
    const duration = audio.durationSec
    if (duration != null && duration > 0 && (duration < SEEDANCE25_MIN_MEDIA_DURATION || duration > SEEDANCE25_MAX_AUDIO_DURATION))
      issues.push({ code: 'seedance-2-5-audio-duration', loc: ['media', 'audio'], msg: `Each reference audio file must be at least ${SEEDANCE25_MIN_MEDIA_DURATION} seconds and no more than ${SEEDANCE25_MAX_AUDIO_DURATION} seconds` })
  }

  // In video_edit the attached video IS the subject, priced on its own
  // duration — the reference-video budget does not apply to it.
  if (model !== Seedance25Model.videoEdit) {
    for (const video of videos) {
      const duration = video.durationSec
      if (duration != null && duration > 0 && (duration < SEEDANCE25_MIN_MEDIA_DURATION || duration > SEEDANCE25_MAX_TOTAL_VIDEO_DURATION))
        issues.push({ code: 'seedance-2-5-video-duration', loc: ['media', 'video'], msg: `Each reference video must be at least ${SEEDANCE25_MIN_MEDIA_DURATION} seconds and no more than ${SEEDANCE25_MAX_TOTAL_VIDEO_DURATION} seconds` })
    }

    const totalVideoDuration = videos.reduce((total, ref) => total + (ref.durationSec ?? 0), 0)
    if (totalVideoDuration > SEEDANCE25_MAX_TOTAL_VIDEO_DURATION)
      issues.push({ code: 'seedance-2-5-video-duration-budget', loc: ['media', 'video'], msg: `The total video duration limit is ${SEEDANCE25_MAX_TOTAL_VIDEO_DURATION} seconds` })
  }

  const totalAudioDuration = audios.reduce((total, ref) => total + (ref.durationSec ?? 0), 0)
  if (totalAudioDuration > SEEDANCE25_MAX_TOTAL_AUDIO_DURATION)
    issues.push({ code: 'seedance-2-5-audio-duration-budget', loc: ['media', 'audio'], msg: `The total audio duration limit is ${SEEDANCE25_MAX_TOTAL_AUDIO_DURATION} seconds` })
  return issues
}

function durationRefs(media: MediaInput | undefined, role: string): Seedance25DurationRef[] {
  return refsFor(media, role).map(ref => ({ durationSec: ref.meta?.durationSec }))
}

export const seedance2_5 = defineJob({
  jobSetType: 'seedance_2_5',
  outputType: 'video',
  params: {
    prompt: true,
    media: {
      field: 'medias',
      format: 'wrapped',
      roles: MEDIA_ROLES,
      // Budgets are prompt-aware and mode-aware — see the note above `validate`.
    },
    settings: {
      duration: z._default(z.duration({ min: 4, max: 30 }), 5),
      resolution: z._default(z.enum(RESOLUTIONS), '720p'),
      aspectRatio: z.wire('aspect_ratio', z._default(z.aspectRatio(ASPECT_RATIOS), '16:9')),
      generateAudio: z.wire('generate_audio', z._default(z.boolean(), true)),
      // The product store's default ('high') wins over the backend schema
      // default ('standard') — every product surface sends it explicitly.
      bitrateMode: z.wire('bitrate_mode', z._default(z.enum(BITRATE_MODES), 'high')),
      // Per-model job param. Orthogonal to the client-side `count` fan-out:
      // total outputs = count × batchSize.
      batchSize: z.wire('batch_size', z._default(z.number(), 1)),
      model: z._default(z.enum(MODELS), Seedance25Model.default),
      // Required for (and only meaningful in) video_extension.
      extensionMode: z.wire('extension_mode', z.optional(z.enum(EXTENSION_MODES))),
    },
  },
  validate: ({ prompt, media, settings }) => {
    const model = (settings.model ?? Seedance25Model.default) as Model
    const videos = refsFor(media, 'video')
    const images = IMAGE_ROLES.flatMap(role => refsFor(media, role))
    const audioCount = refsFor(media, 'audio').length
    const mediaCount = MEDIA_ROLES.reduce((count, role) => count + refsFor(media, role).length, 0)
    const referenceElementCount = extractReferenceElementIds(prompt?.instruction ?? '').length

    return [
      ...promptRequired(prompt),
      ...promptMax(prompt, SEEDANCE_2_5_MAX_PROMPT_LENGTH),
      ...oneOf('resolution', settings.resolution, RESOLUTIONS),
      ...oneOf('bitrateMode', settings.bitrateMode, BITRATE_MODES),
      ...oneOf('model', model, MODELS),
      // The edit modes render into the source video's box; only `default`
      // takes a ratio from the caller.
      ...(model === Seedance25Model.default
        ? oneOf('aspectRatio', settings.aspectRatio, ASPECT_RATIOS)
        : []),
      // video_edit takes its duration from the input video, so nothing to check.
      ...(model === Seedance25Model.videoEdit
        ? []
        : model === Seedance25Model.videoExtension
          && typeof settings.duration === 'number'
          && settings.duration > 30
          ? [{ loc: ['settings', 'duration'], msg: 'Seedance 2.5 video extension supports at most 30 seconds' }]
          : integerRange('duration', settings.duration, 4, 30)),
      ...integerRange('batchSize', settings.batchSize, 1, 4),
      // Exactly one VIDEO — the subject of the edit. Images, audio and
      // reference elements are ordinary references here, so the total media
      // count is deliberately not constrained: requiring one media in total
      // rejected every edit that carried any reference at all.
      ...(model === Seedance25Model.videoEdit && videos.length !== 1
        ? [{ loc: ['media', 'video'], msg: 'Seedance 2.5 video edit requires exactly one video reference' }]
        : []),
      ...(model === Seedance25Model.videoExtension && videos.length === 0
        ? [{ loc: ['media', 'video'], msg: 'Seedance 2.5 video extension requires a video reference' }]
        : []),
      ...(model === Seedance25Model.videoExtension && !EXTENSION_MODES.includes(settings.extensionMode as ExtensionMode)
        ? [{ loc: ['settings', 'extensionMode'], msg: 'extensionMode is required for video extension' }]
        : []),
      ...getSeedance25MediaLimitIssues({
        imageCount: images.length,
        videoCount: videos.length,
        audioCount,
        totalCount: mediaCount,
        referenceElementCount,
      }),
      ...getSeedance25MediaDurationIssues(model, durationRefs(media, 'video'), durationRefs(media, 'audio')),
    ]
  },
  finalize: (wire) => {
    const resolution = wire.resolution as Resolution
    const aspectRatio = wire.aspect_ratio as AspectRatio
    // Dims always come fresh from the table — a parsed input whose resolution
    // or ratio changed re-derives instead of resubmitting stale extra dims.
    const { width, height } = lookupSize(SIZE_MAP, resolution, aspectRatio)
    const model = wire.model as Model

    const common: Record<string, unknown> = {
      ...wire,
      prompt: wire.prompt ?? '',
      width,
      height,
    }
    // The three shapes: video_edit inherits the source clip's length and box,
    // video_extension sets its own length but still inherits the box.
    delete common.aspect_ratio
    delete common.duration
    delete common.extension_mode

    if (model === Seedance25Model.videoEdit)
      return common

    if (model === Seedance25Model.videoExtension)
      return { ...common, duration: wire.duration, extension_mode: wire.extension_mode }

    return { ...common, duration: wire.duration, aspect_ratio: aspectRatio }
  },
  restore: (wire) => {
    // `finalize` drops `aspect_ratio` in both edit modes, so a fetched edit
    // would re-derive its render box from the '16:9' schema default. The
    // stored width/height encode what the box actually was — map them back.
    if (typeof wire.aspect_ratio === 'string')
      return {}
    const { width, height } = wire
    if (typeof width !== 'number' || typeof height !== 'number' || height <= 0)
      return {}
    return { aspect_ratio: closestRatioBySize(ASPECT_RATIOS, { width, height }) }
  },
})
