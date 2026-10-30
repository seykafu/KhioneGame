/**
 * Room behaviour, exercised through real WebSockets in workerd.
 *
 * These tests are the safety net for the whole games migration: every existing
 * game speaks the wire protocol asserted here, so a regression in this file is a
 * regression in every migrated game. They deliberately drive the PUBLIC surface
 * (connect, send frames, read frames) rather than poking at internals.
 */

import { SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";

/** Open a socket to a room and collect frames as they arrive. */
async function open(room = "main") {
  const res = await SELF.fetch(`https://game.test/ws/${room}`, {
    headers: { Upgrade: "websocket" },
  });
  expect(res.status).toBe(101);
  const ws = res.webSocket;
  if (!ws) throw new Error("no webSocket on the upgrade response");
  ws.accept();

  const frames: unknown[] = [];
  ws.addEventListener("message", (event: MessageEvent) => {
    const data = typeof event.data === "string" ? event.data : "";
    // Keepalive auto-responses are not protocol traffic.
    if (data === "__pong") return;
    try {
      frames.push(JSON.parse(data));
    } catch {
      frames.push(data);
    }
  });

  /** Wait for the next frame matching `pred` (frames can arrive out of step). */
  const next = async (pred: (f: any) => boolean, label: string) => {
    for (let i = 0; i < 100; i++) {
      const hit = frames.find(pred);
      if (hit) return hit as any;
      await scheduler.wait(10);
    }
    throw new Error(`timed out waiting for ${label}; got ${JSON.stringify(frames)}`);
  };

  return {
    ws,
    frames,
    next,
    send: (msg: unknown) => ws.send(JSON.stringify(msg)),
    state: () => next((f) => f?.type === "state", "a state frame"),
    error: () => next((f) => f?.type === "error", "an error frame"),
  };
}

/**
 * A fresh room name per call. Durable Object state persists across tests in the
 * pool, so reusing a literal name would inherit the previous test's seats and
 * make the suite order-dependent.
 */
let seq = 0;
function uniq(label: string): string {
  seq += 1;
  return `${label}-${seq}-${crypto.randomUUID().slice(0, 6)}`;
}

describe("routing", () => {
  it("rejects a non-upgrade request to /ws instead of waking a room", async () => {
    const res = await SELF.fetch("https://game.test/ws");
    expect(res.status).toBe(426);
  });

  it("rejects a room name that isn't a short safe label", async () => {
    const res = await SELF.fetch("https://game.test/ws/../../etc/passwd", {
      headers: { Upgrade: "websocket" },
    });
    expect(res.status).not.toBe(101);
  });

  it("404s a non-asset, non-ws path for a non-HTML request", async () => {
    const res = await SELF.fetch("https://game.test/api/nope");
    expect(res.status).toBe(404);
  });
});

describe("cloud save slot", () => {
  it("seats the single traveller and starts with an empty save", async () => {
    const room = uniq("fresh");
    const a = await open(room);
    a.send({ type: "join", playerId: "khione" });
    const s = await a.next((f) => f?.type === "state" && f.status === "playing", "playing");
    expect(s.meta.game).toBe("Khione");
    expect(s.seats).toEqual(["khione"]);
    expect(s.view).toEqual({ save: null, rev: 0, mine: true });
    a.ws.close();
  });

  it("stores a save and returns it to the same traveller on another device", async () => {
    const room = uniq("roundtrip");
    const phone = await open(room);
    phone.send({ type: "join", playerId: "khione" });
    await phone.next((f) => f?.type === "state" && f.status === "playing", "playing");
    phone.frames.length = 0;
    phone.send({ type: "action", action: { type: "save", data: '{"v":1,"island":"eaton"}', rev: 3 } });
    const saved = await phone.next((f) => f?.type === "state" && f.view?.rev === 3, "the save to land");
    expect(saved.view.save).toBe('{"v":1,"island":"eaton"}');
    phone.ws.close();

    const tablet = await open(room);
    tablet.send({ type: "join", playerId: "khione" });
    const restored = await tablet.state();
    expect(restored.view.save).toBe('{"v":1,"island":"eaton"}');
    expect(restored.view.rev).toBe(3);
    tablet.ws.close();
  });

  it("refuses a stale save so an old device never overwrites newer progress", async () => {
    const room = uniq("stale");
    const a = await open(room);
    a.send({ type: "join", playerId: "khione" });
    await a.next((f) => f?.type === "state" && f.status === "playing", "playing");
    a.send({ type: "action", action: { type: "save", data: "{}", rev: 5 } });
    await a.next((f) => f?.type === "state" && f.view?.rev === 5, "rev 5");
    a.frames.length = 0;
    a.send({ type: "action", action: { type: "save", data: "{}", rev: 4 } });
    expect((await a.error()).error).toBe("stale save");
    a.ws.close();
  });

  it("rejects malformed saves", async () => {
    const room = uniq("malformed");
    const a = await open(room);
    a.send({ type: "join", playerId: "khione" });
    await a.next((f) => f?.type === "state" && f.status === "playing", "playing");
    a.frames.length = 0;
    a.send({ type: "action", action: { type: "save", data: 42, rev: 1 } });
    expect((await a.error()).error).toBe("save must be a string");
    a.frames.length = 0;
    a.send({ type: "action", action: { type: "teleport" } });
    expect((await a.error()).error).toBe("unknown action");
    a.ws.close();
  });

  it("does not let a second traveller read or write someone else's journey", async () => {
    const room = uniq("owner");
    const a = await open(room);
    a.send({ type: "join", playerId: "khione" });
    await a.next((f) => f?.type === "state" && f.status === "playing", "playing");
    a.send({ type: "action", action: { type: "save", data: '{"secret":1}', rev: 1 } });
    await a.next((f) => f?.type === "state" && f.view?.rev === 1, "saved");

    const b = await open(room);
    b.send({ type: "join", playerId: "stranger" });
    const seen = await b.state();
    expect(seen.view.save).toBeNull();
    expect(seen.view.mine).toBe(false);
    b.frames.length = 0;
    b.send({ type: "action", action: { type: "save", data: "{}", rev: 9 } });
    expect((await b.error()).error).toBe("spectators cannot act");
    a.ws.close();
    b.ws.close();
  });

  it("refuses to act before joining", async () => {
    const a = await open(uniq("no-join"));
    a.send({ type: "action", action: { type: "save", data: "{}", rev: 1 } });
    expect((await a.error()).error).toBe("join first");
    a.ws.close();
  });
});

describe("untrusted input", () => {
  it("rejects a non-JSON frame", async () => {
    const a = await open(uniq("bad-json"));
    a.ws.send("not json at all");
    expect((await a.error()).error).toBe("invalid json");
    a.ws.close();
  });

  it("rejects an unknown message type", async () => {
    const a = await open(uniq("bad-type"));
    a.send({ type: "definitely-not-a-thing" });
    expect((await a.error()).error).toMatch(/unknown message type/);
    a.ws.close();
  });

  it("refuses an oversized frame instead of persisting it", async () => {
    const a = await open(uniq("too-big"));
    a.send({ type: "join", playerId: "khione" });
    await a.state();
    a.frames.length = 0;
    a.send({ type: "action", action: { type: "save", data: "x".repeat(20_000), rev: 1 } });
    expect((await a.error()).error).toBe("message too large");
    a.ws.close();
  });

  it("refuses an oversized action payload", async () => {
    const a = await open(uniq("big-action"));
    a.send({ type: "join", playerId: "khione" });
    await a.state();
    a.frames.length = 0;
    // Under the 16 KiB frame cap, over the 14 KiB action cap.
    a.send({ type: "action", action: { type: "save", data: "x".repeat(15_000), rev: 1 } });
    expect((await a.error()).error).toBe("action too large");
    a.ws.close();
  });
});
