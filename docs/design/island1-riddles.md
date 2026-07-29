# Island 1 — Ahalo · Riddle Chain (Draft 1)

**Theme:** *The island is listening.*
**Job:** Teach every core verb (move, jump, swim, interact, carry, meow) through play, never through tutorial text — and plant the first Oreo foreshadowing without the player realizing it.

Ahalo is the only "wild" island, so its puzzles use only nature: stones, tides, shadows, wind, animals.

---

## Beat 0 — The Bottle *(implemented)*
The torn letter washes ashore. Teaches interact. The player leaves with a question, not an instruction — the only goal Ahalo ever states is implicit: *get off the island.*

## Beat 1 — The Three Hollow Stones *(teaches: meow)*
Near a small **Echo Cove** cave, three cracked hollow stones hum in the wind, each at a different pitch. Inside the cave mouth, a weathered carving: three spiral shells, small → medium → large. Meowing at a stone makes it "answer" with an echo at its pitch. Meow at the stones in the carving's order (small = highest pitch first) and the tide pool below drains with a groan, revealing a cache: a **Rusty Locket** — engraved with a pawprint *too big for a cat*. (Foreshadow #1. It has no use on Ahalo. Players will carry it the whole game.)

- Wrong order: crabs pop out and reshuffle nothing — gentle, funny failure.
- Design rule established: *sounds are keys.*

## Beat 2 — The Driftwood Seesaw *(teaches: inventory & weight)*
A driftwood plank balances across a wedge rock, one end pinned under a woven-vine gate in the hillside. Coconuts lie under the palms. Carry coconuts (one slot each) and place them on the free end — at **three coconuts** the gate lifts. Inside the burrow: an **Old Oar**, smooth with use, and scratch marks on the walls... low, like something that dug. (Foreshadow #2.)

- Subtlety: player has 5 slots; carrying 3 coconuts + locket + shell forces the first "my pockets are full" moment — teaching inventory pressure for later islands.

## Beat 3 — The Sundial Reef *(synthesis: climb + item + swim)*
On the hill summit stands a crude sundial missing its gnomon. The **Sun Shell** (golden, found atop the summit tier) slots into it. Its shadow falls across the water — pointing at one specific **sea rock** offshore. Swim out (Space to climb the rock), and meow from its top: gulls burst upward, and where they rose, a **raft frame** floats loose from the reef and drifts to the beach.

- The shadow only points somewhere when the shell is placed — observation, not text.
- Backtracking beat: you saw the sea rocks while exploring; now one matters.

## Beat 4 — Rig the Raft *(escape gate — uses everything)*
The raft frame beaches itself near the bottle (full circle). It needs three things:
1. **Old Oar** — Beat 2.
2. **Palm-frond sail** — the tallest palm has one huge dry frond; jump from the neighboring bent palm's crown to knock it down (platforming test).
3. **Vine rope** — vines hang in Echo Cove, guarded by a big crab. The tide pool from Beat 1 left a **stranded fish**; offer it (inventory) and the crab snips the vines for you. (Kindness > confrontation — a tone-setter for the whole game.)

Rig the raft → final interact → Khione pushes off. As the island shrinks behind her, the camera holds on the beach a beat too long: a line of **pawprints in the sand that are not hers**. (Foreshadow #3.)

## Beat 5 — Letter fragment
Tucked in the raft's knotwork, a scrap in the same handwriting: only the words *"…one final…"* are legible. Slots silently into the letter UI — the letter screen becomes the game's mystery board, gaining fragments island by island.

---

## Design rules (apply to all 10 islands)
1. **No lock is text.** Every answer is observable in the world (carvings, pitch, shadow, weight).
2. **Each island teaches one new verb**, then re-tests old ones. Ahalo: meow. Island 2 (Eaton Centre): hiss (scatter the pigeons?).
3. **Failure is funny, never punishing.** Crabs, gulls, wobbles — no death on Ahalo.
4. **Every island plants one Oreo artifact** the player can't decode yet.
5. **Backtracking must pay** — later islands' items reopen Ahalo's "unsolvable" bits (e.g., the locket's clasp).

## Implementation backlog (Ahalo)
- [ ] Echo Cove geometry + 3 hollow stones (pitch audio, meow-response Area3D)
- [ ] Carving prop + readable close-up UI
- [ ] Tide pool drain animation + cache (Locket, stranded fish)
- [ ] Seesaw physics-lite gate (slot-count trigger, no ragdoll physics needed)
- [ ] Sundial socket + shadow-pointer (a baked light beam, not real shadow math)
- [ ] Raft frame interactable + 3-part quest flags via `GameState`
- [ ] Gull burst particles, crab NPC, letter-fragment UI hook
- [ ] Pawprint decals on beach for the departure shot
