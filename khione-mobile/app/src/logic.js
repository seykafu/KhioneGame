/**
 * Khione's server side: a single-player cloud save slot.
 *
 * The game itself runs entirely in the browser (public/). A room here is one
 * player's journey backup: the client sends its save JSON after progress, and
 * any device that opens the same room (the "cloud code") with the same
 * playerId gets it back. Pure functions only — see ../AGENTS.md.
 */

export const meta = {
  game: "Khione",
  minPlayers: 1,
  maxPlayers: 1,
};

/** Upper bound for one save blob (the room caps a whole action at 14 KiB). */
const MAX_SAVE = 13000;

export function setup(players) {
  return { owner: players[0] ?? null, save: null, rev: 0 };
}

export function validateAction(state, playerId, action) {
  if (!state || state.owner !== playerId) return { ok: false, error: "not your journey" };
  if (!action || typeof action !== "object") return { ok: false, error: "bad action" };
  if (action.type !== "save") return { ok: false, error: "unknown action" };
  if (typeof action.data !== "string" || action.data.length === 0) return { ok: false, error: "save must be a string" };
  if (action.data.length > MAX_SAVE) return { ok: false, error: "save too large" };
  if (!Number.isInteger(action.rev) || action.rev < 0) return { ok: false, error: "rev must be a non-negative integer" };
  // Never let an older device overwrite newer progress.
  if (action.rev < state.rev) return { ok: false, error: "stale save" };
  return { ok: true };
}

export function applyAction(state, playerId, action) {
  return { ...state, save: action.data, rev: action.rev };
}

export function isGameOver() {
  return { over: false };
}

export function viewFor(state, playerId) {
  if (!state || state.owner !== playerId) return { save: null, rev: 0, mine: false };
  return { save: state.save, rev: state.rev, mine: true };
}
