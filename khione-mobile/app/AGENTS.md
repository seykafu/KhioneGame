# Building a game here

A multiplayer game is three files. Everything else — sockets, rooms, persistence,
deploy — is already done and you should not need to touch it.

| File | What it is | Do you edit it? |
| --- | --- | --- |
| `src/logic.js` | **The game.** Six pure functions. | **Yes — this is the game.** |
| `public/index.html` + `public/client.js` | The screen and the input. | **Yes — draw your game.** |
| `src/room.ts` | The room: sockets, state, fan-out. | Rarely (see *Real-time games*). |
| `src/worker.ts` | Routes `/ws/<room>` to a room. | Almost never. |

Start by reading `src/logic.js` — it is a complete, working tic-tac-toe and shows
every part of the contract.

## The game contract

`src/logic.js` must export exactly these six names:

```js
export const meta = { game: "My Game", minPlayers: 2, maxPlayers: 4 };
export function setup(players) { … }                          // initial state
export function validateAction(state, playerId, action) { … }  // {ok:true} | {ok:false,error}
export function applyAction(state, playerId, action) { … }     // NEW state
export function isGameOver(state) { … }                        // {over:false} | {over:true,winner}
export function viewFor(state, playerId) { … }                 // what THIS player sees
```

Hard rules, enforced by `bun run check:logic` (which runs as part of the build):

- **No imports, no `require`.** This file is rules and nothing else.
- **Pure and deterministic.** No `Date.now()`, no `Math.random()`, no `fetch`, no
  timers. The server persists and re-derives these results, so a nondeterministic
  game desynchronises its players. Need randomness? Put a seed in `setup()` and
  advance it inside `applyAction`.
- **Treat `state` as immutable.** Return a new object; copy what you change.
- **State must be JSON-serializable** — it is written to the room's storage.

Two rules the checker cannot enforce, and that matter just as much:

- **`validateAction` is your only defence.** The client is untrusted and can send
  any action at any time. Check everything there: whose turn it is, whether the
  move is in range, whether the target is legal. `applyAction` runs only after it
  returns `ok`.
- **`viewFor` is how you hide information.** Whatever it returns is the *only*
  thing that player receives. For a card game, return that player's hand and
  everyone else's card *count* — never the full state.

## The wire protocol

You get this for free; the shipped `client.js` already speaks it.

```
client → server   {type:"join", playerId}      introduce yourself (required first)
                  {type:"action", action}      make a move
                  {type:"reset"}               start a new round

server → client   {type:"state", status, seats, you, connected, view, result, meta}
                  {type:"error", error}
```

`status` is `waiting` (fewer than `minPlayers` seated) → `playing` → `over`.
Players beyond `maxPlayers` join as **spectators**: they receive state but their
actions are refused. Re-joining with the same `playerId` reclaims that seat, which
is what makes a reload or a dropped connection recover.

## Rooms

A room is `/ws/<name>`, and the name is the whole story: same name = same game.
`/ws` alone is the room `main`. The shipped client reads `?room=` from the URL, so
`?room=abc` puts two browsers in the same match.

Each room is one Durable Object with its own storage, so rooms never see each
other. Idle rooms hibernate — connections stay open, and the room costs nothing
until the next message. **Never keep game state in a field on the class**; it will
not survive hibernation. Storage is the only durable place.

## Real-time games (tick loops, countdowns)

Turn-based games need no timers. For anything that advances on its own, a handler
in `src/room.ts` may return `{ out: [...], wakeIn: 100 }` — the room is woken in
100 ms and `onWake()` runs. Return `wakeIn: null` to cancel. That is the only
supported way to make time pass; a `setInterval` cannot survive hibernation.

To go fully custom (physics, per-tick broadcast), rewrite the handlers in
`src/room.ts` and keep the class exported as `Room`.

## Commands

```bash
bun install        # once
bun run dev        # local server; open two tabs at ?room=test
bun run test       # room + protocol tests, in the real Workers runtime
bun run build      # what CI runs: logic check → typecheck → bundle
```

`bun run test` is worth using while you build: it drives real WebSockets against
the real runtime, so a broken rule shows up as a failing assertion instead of a
silent desync in front of players.

## Before you publish

- Fill in the real `og:title` / `og:description` in `public/index.html` and set a
  cover image. **An empty `og:title` makes the marketplace card invisible.**
- Play it in two tabs (`?room=x`) and confirm both sides agree after every move.
- Check a spectator (a third tab) cannot affect the game.

## Infrastructure

`app.manifest.json` declares what the platform provisions. It ships as:

```json
{ "db": false, "r2": false, "kv": false, "durableObject": "Room" }
```

`durableObject` is what gets you `env.ROOMS` — leave it unless the game is
single-player with no server state, in which case set it to `null` and delete
`src/room.ts`. Turn on `db` / `r2` / `kv` for a leaderboard or user uploads and
they arrive as `env.DB` / `env.STORAGE` / `env.KV`; add them to `src/env.ts` too.

`wrangler.jsonc` is for local dev only — the deploy generates its own
authoritative config and ignores it.
