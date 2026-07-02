# 🏛️ Board of Advisors — a personal AI coaching system built on Claude Code

> Interview yourself once. Pick the experts you wish you could call. Get coached by all of them, in their own voices, every time you face a decision.

Built with [Claude Code](https://claude.com/claude-code) using context engineering, persistent memory, a knowledge-base pipeline, and a custom skill. No app, no database, no server — just markdown files and one well-designed prompt system.

**I was my own first client.** I built this to make better career and business decisions (and as a portfolio piece demonstrating what a Claude Specialist actually does). I use it daily — my real profile and advisor data stay private on my machine; this repo is the reusable template.

---

## How it works

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────────┐
│  1. INTERVIEW   │────▶│  2. PROFILE       │────▶│  3. KNOWLEDGE BASE   │
│  10 questions,  │     │  PROFILE.md       │     │  raw/   source notes │
│  one at a time  │     │  who you are,     │     │  wiki/  synthesized  │
│                 │     │  goals, blockers, │     │  per-advisor pages   │
└─────────────────┘     │  coaching style   │     └──────────┬──────────┘
                        └──────────────────┘                │
                                 │                          │
                                 ▼                          ▼
                        ┌────────────────────────────────────────┐
                        │  4. /ask-the-board  (custom skill)      │
                        │  each advisor's take, in voice          │
                        │  → agreements & clashes                 │
                        │  → coach's synthesis + dated actions    │
                        └────────────────────────────────────────┘
```

### The six components

1. **Interview protocol** ([docs/interview-protocol.md](docs/interview-protocol.md)) — 10 questions asked one at a time, covering current situation, vision, strengths, blockers, money habits, trusted people, coaching-style preferences, and early warning signs. The back-and-forth matters: follow-ups surface things a form never would.
2. **Profile file** ([templates/PROFILE.template.md](templates/PROFILE.template.md)) — the interview distilled into a structured document Claude reads before giving any advice. Includes explicit *coaching instructions* ("push me with fear when I need it, be gentle when I'm down, remind me of my goals — I forget").
3. **Knowledge pipeline** — for each advisor you choose (authors, YouTubers, coaches):
   - `knowledge/raw/<person-slug>/` — source notes per piece of content (articles, interview notes, book summaries), each with URL + retrieval date in frontmatter. Kept **private** — these are personal research notes on copyrighted material.
   - `knowledge/wiki/<person-slug>.md` — a synthesis page: core ideas, vocabulary, stances, recurring stories, a "voice" guide for persona emulation, and a "how this maps to me" section.
4. **The `/ask-the-board` skill** ([.claude/skills/ask-the-board/SKILL.md](.claude/skills/ask-the-board/SKILL.md)) — loads profile + wikis, renders each advisor's take in their own voice, flags consensus and disagreements, then synthesizes a decisive recommendation with dated next actions. Auto-triggers on any decision-shaped question.
5. **Integrations** — Claude Code's persistent memory (so every future session knows the system exists) and Google Calendar via MCP (board decisions become dated reminders with the reasoning embedded in the event description).
6. **The drift watchdog** ([watchdog/](watchdog/)) — the accountability layer. A scheduled PowerShell script checks when Claude Code was last used (session-transcript file mtimes); if you've gone silent past your self-declared warning threshold (48h), it emails you your advisors' get-back-on-track letter via Gmail SMTP. Reminders handle your tasks; this handles your *disappearing* — and it only speaks when you've actually gone dark.

## Repo structure

```
board-of-advisors/
├── README.md
├── docs/
│   └── interview-protocol.md      # the 10-question interview
├── templates/
│   ├── PROFILE.template.md        # profile schema with placeholders
│   └── advisor-wiki.template.md   # advisor synthesis page schema
├── examples/                      # FICTIONAL data — format demos only
│   ├── PROFILE.example.md
│   └── knowledge/wiki/lena-cruz.md
├── .claude/skills/ask-the-board/
│   └── SKILL.md                   # the custom skill (generalized)
└── watchdog/                      # drift detection → email via Gmail SMTP
    ├── claude-watchdog.ps1
    ├── setup-watchdog.ps1
    ├── letter.template.txt
    └── README.md
```

## Quick start

1. Clone this repo (or copy it into an existing Claude Code project).
2. Open Claude Code in the project and say:
   > *"Run the interview in docs/interview-protocol.md, one question at a time, then fill out templates/PROFILE.template.md as PROFILE.md."*
3. Ask Claude to recommend advisors for **your** specific situation, or name your own.
4. For each advisor: *"Ingest their publicly available content as notes under knowledge/raw/<slug>/, then synthesize knowledge/wiki/<slug>.md using templates/advisor-wiki.template.md."*
5. Customize the advisor roster inside `.claude/skills/ask-the-board/SKILL.md`.
6. Restart the session and run:
   > `/ask-the-board should I spend this month's budget on X or Y?`

## Example session (fictional data, abridged)

> `/ask-the-board should I take the agency retainer or keep freelancing?`
>
> **🎨 Lena says:** "A retainer is a boring business — recurring revenue, one client relationship to manage. Take it, but cap it at 60% of your hours so you're renting out time, not selling all of it…"
>
> **⚔️ Where they clash:** Lena optimizes for cashflow stability; Marcus says retainers cap your upside and you should raise project prices instead…
>
> **🎯 Synthesis:** Take the retainer for 6 months as a cash floor, use the stability to raise your project rates 30%… 1) Reply to the agency by Friday. 2) …

## Privacy by design

The system's real value comes from brutally honest inputs — which is exactly why the real data can never be public:

- `PROFILE.md` and `knowledge/` are **gitignored by default** in this template.
- Only templates and fictional examples ship in the repo.
- Raw content notes stay local: summarizing articles for personal study is fine; republishing them is not.

## What I'd improve next

- A re-interview cadence (quarterly diff of the profile: what changed?)
- Advisor disagreement scoring — track whose advice you followed and what happened
- ~~Automatic session-gap detection ("you've been quiet for 2+ days" — my own early-warning signal from the interview)~~ **Shipped** → [watchdog/](watchdog/)
- Cross-platform watchdog (currently Windows Task Scheduler; cron/launchd ports welcome)

## License

MIT — see [LICENSE](LICENSE).

---

*Built by [Kitz Rulona](https://rulona.vercel.app) with Claude Code.*
