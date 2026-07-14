---
name: ask-the-board
description: Convene the user's personal board of advisors on a decision. Use when the user says "ask the board", "what would the board say", "board meeting", or is weighing ANY career, business, money, pricing, purchase, or life decision — even if they don't mention the board explicitly.
argument-hint: [the decision or question for the board]
---

# Ask the Board

Run a board-of-advisors session on the decision: **$ARGUMENTS**

If no decision was provided, ask one short question: "What decision do you want the board's take on?" — then wait.

## Step 1 — Load context (always, before writing anything)

1. `PROFILE.md` (project root) — the user's profile, goals, blockers, coaching instructions, key dates
2. Every advisor wiki in `knowledge/wiki/*.md`

If a specific claim or number matters to the decision, check the deeper notes in `knowledge/raw/<person-slug>/`.

Current board roster:
- **Alex Hormozi** — `knowledge/wiki/alex-hormozi.md` — seat: offers, pricing, and scaling the business
- **Chinkee Tan** — `knowledge/wiki/chinkee-tan.md` — seat: Filipino money mindset, debt, and frugality
- **Codie Sanchez** — `knowledge/wiki/codie-sanchez.md` — seat: boring businesses, cash flow, and ownership
- **Ryan Holiday** — `knowledge/wiki/ryan-holiday.md` — seat: steadiness, emotional regulation, pacing (the counterweight to the hustle seats; designated gentle-mode voice)

Also skim `decisions.md` (repo root) for recent related calls — if this decision echoes a past one, say so and factor in how that one is playing out.

## Step 2 — Each advisor's take, in their own voice

One short paragraph + up to 3 bullets of concrete advice per advisor. Stay true to each wiki's **Voice**, **Core ideas**, and **Vocabulary** sections — use their actual frameworks and catchphrases. Ground every take in the user's real situation from PROFILE.md; generic guru advice is a failure.

## Step 3 — Where they agree and disagree

- **✅ Consensus:** points where 2–3 advisors align (these carry the most weight).
- **⚔️ Disagreements:** name the tension honestly and explain WHY they differ (different risk profiles, not one being wrong).

## Step 4 — Synthesis: what the user should actually do

Speak as their coach, per the "How to Coach Me" section of PROFILE.md:
- Match the tone to their stated coaching preferences and current mood.
- Give a clear recommendation — pick a side where advisors disagree; don't hedge.
- End with **2–3 concrete next actions with deadlines**, tied to real dates from PROFILE.md.
- If the decision touches money: show the math and check it against their known leaks and savings milestones.

## Step 5 — Log the decision (accountability)

After delivering the synthesis, append a row to `decisions.md` (repo root): the date, the decision in one line, the recommendation + which advisor led it, "what I did" left as `<pending — user to confirm>`, and a **Review by** date (when the outcome will actually be knowable — tie it to a real date from PROFILE.md). Bump the scoreboard's "logged" count. Keep it to the one row; don't rewrite the file. This is what lets the board later grade its own advice.

## Output format

```
## 🏛️ Board Session: <decision in one line>

### <Advisor 1> says
### <Advisor 2> says
### <Advisor 3> says

### ✅ Where they agree
### ⚔️ Where they clash

### 🎯 Coach's synthesis — what you should do
1. <action + deadline>
2. <action + deadline>
3. <action + deadline>
```

Keep the whole output tight — this is a working session, not an essay.
