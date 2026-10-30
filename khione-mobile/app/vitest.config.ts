import { cloudflareTest } from "@cloudflare/vitest-pool-workers";
import { defineConfig } from "vitest/config";

/**
 * Tests run in workerd — the real runtime — not a mock. That matters here: the
 * room's correctness lives in WebSocket hibernation, `ctx.storage` and Durable
 * Object addressing, none of which a fake reproduces faithfully.
 *
 * Bindings come from `wrangler.jsonc`, so the tests exercise the same DO class
 * and migration the local dev server does.
 */
export default defineConfig({
  plugins: [cloudflareTest({ wrangler: { configPath: "./wrangler.jsonc" } })],
});
