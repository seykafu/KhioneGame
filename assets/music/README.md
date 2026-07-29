# Music

Drop finished tracks in this folder and they play automatically — no code changes needed.

| Filename | Plays when | Behavior |
|---|---|---|
| `intro.mp3` (or `.ogg`/`.wav`) | Opening cinematic | Fades in with the narration, crossfades out at handoff |
| `ahalo.mp3` (or `.ogg`/`.wav`) | Island 1 exploration | Starts as gameplay begins, loops forever |

The `Music` autoload (scripts/systems/music.gd) resolves `<track>.ogg` → `.mp3` → `.wav`,
loops it, and crossfades between decks. Until a file exists, the hook no-ops and prints a
console note. Future islands just need `Music.play("<island>")` + a file here.

## Suno AI prompts

### Track 1 — `ahalo` (Island 1 exploration loop)

> Instrumental only, no vocals. Cozy tropical adventure-game exploration theme. Warm marimba and kalimba lead melody, soft nylon-string ukulele strums, gentle shakers and light hand percussion, airy pads like an ocean breeze, subtle warm upright bass. Mood: curious, peaceful, a little lonely but hopeful — a small cat exploring a beautiful empty island. Mid-tempo around 92 BPM, major key with occasional wistful minor turns, playful wooden flute answering phrases. Gentle dynamics, no big drops, loops seamlessly. Style touchstones: Animal Crossing, A Short Hike, Studio Ghibli island morning.

*Exclude styles / avoid:* vocals, lyrics, singing, EDM, drums heavy, epic orchestral

### Track 2 — `intro` (opening cinematic, ~60–90s)

> Instrumental only, no vocals. Storybook fairytale opening theme for a narrated cinematic. Begins with a delicate lone music box over faint ocean ambience, slowly joined by warm celesta, soft felt piano, and gently swelling warm strings. Mood: wonder, innocence, and quiet melancholy — a lonely little white cat, and a message in a bottle washing ashore. Slow, around 70 BPM, builds tenderly to one hopeful swell, then settles into a soft unresolved ending that hands off to gameplay. Intimate, cinematic, Ghibli-esque lullaby.

*Exclude styles / avoid:* vocals, lyrics, singing, percussion, trailer epicness

### Tips for Suno

- Toggle **Instrumental** on; paste the prompt into the style/description box.
- Generate 3–4 takes and pick; ask for extensions if the loop is too short.
- For `ahalo`, trim the file so the end flows into the start (any audio editor, or ask Claude).
- Download as MP3 is fine — Godot imports it directly.
