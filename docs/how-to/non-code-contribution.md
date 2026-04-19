# Contributing Without Writing Code

Chromaticity's architecture deliberately separates **domain expertise** from **implementation**. Most valuable contributions to this project are not code.

This guide covers the contribution paths for domain experts — perception scientists, musicians, VJs, shader artists — who have relevant knowledge but don't want to write Python.

---

## What kinds of non-code contributions matter?

### 1. Mapping rationales (highest leverage)
The mapping profile schema (ADR-004) requires every audio→uniform mapping to have a `rationale` field: either a cited source or an explicit `"heuristic"` marker. These rationales are the enforcement mechanism for our "perceptually principled" claim.

**Example**: Reviewing a generated mapping profile and finding a uniform tagged `suggested_audio_feature: "spectral_centroid"` with `rationale: "heuristic"`. You recognise that this uniform clearly controls spatial position, not brightness. You propose:

```diff
- "suggested_audio_feature": "spectral_centroid",
- "rationale": "heuristic"
+ "suggested_audio_feature": "arousal",
+ "rationale": "Eitan & Granot 2006 — tempo/energy drives perceived motion speed; this uniform controls horizontal displacement (spatial motion)",
+ "rationale_ref": "doi:10.1525/mp.2006.23.3.221"
```

That's a pure JSON edit. It improves the mapping profile. It's a real contribution.

**Workflow**:
1. Find a mapping profile on GitHub (`test-data/mappings/*.json` once Phase 1 produces them)
2. Open the file in GitHub's web editor (pencil icon)
3. Propose edits
4. "Propose changes" → write a commit message → "Create pull request"
5. Explain in the PR description why the change improves the mapping

### 2. Name-heuristic dictionary entries (ADR-006 Stage 1)
Stage 1 of uniform inference matches uniform names against a curated dictionary. When you encounter a shader that uses a non-obvious naming convention, propose an addition.

**Example**: You see a family of DnB-focused shaders on Shadertoy that use `aExp` as a uniform controlling spatial scale that responds to audio exposure. Propose a dictionary entry:

```json
{
  "pattern": "aExp",
  "matches": ["aExp", "audioExp", "audio_exp"],
  "inferred_role": "scale",
  "suggested_audio_feature": "rms_energy",
  "confidence_weight": 0.6,
  "rationale": "observed convention in several DnB Shadertoy shaders; 'exp' = exposure in photography sense",
  "contributed_by": "BrotherDurry"
}
```

Workflow: edit `chromaticity/probe/name_dictionary.json`, open PR with one-line description.

### 3. Shader selection + triage
Picking which shaders to include in the test suite, demo library, or docs screenshots is a curation job, not an engineering one. A curated collection that showcases the visualiser well is product work.

**Workflow**: open an issue titled `Shader library: propose adding [shader name]`. Include:
- Shadertoy URL (or local file proposal)
- Why it's a good showcase (what musical content does it suit?)
- Any caveats (safety concerns, performance concerns, uniform naming weirdness)

### 4. Perceptual reviews of outputs
Once Phase 2 exists and we're producing real visualiser output, reviewing *whether it feels right* is domain work.

**Workflow**: open a "shader review" issue with a recording of the output + the source audio. Annotate:
- Which moments feel well-mapped
- Which moments feel wrong
- What you'd change

This becomes direct input to mapping refinements.

### 5. Documentation improvements
The tutorials, glossary, and explanations are living documents. If you read one and something is unclear, fix it.

**Workflow**: GitHub web editor on any `.md` file → propose changes → PR.

### 6. Issue reporting
Actual bug reports, feature requests, design questions. Standard GitHub issues (templates provided).

### 7. Photosensitivity review
Reviewing whether a shader + mapping combination could produce dangerous temporal luminance patterns. This is a perceptual science contribution — understanding the relationship between beat-synced visual changes and photosensitive seizure thresholds.

**Context**: Chromaticity is architecturally positioned to offer photosensitivity-safe visualisation (see ADR-005). The mapping layer sits between audio features and visual output, so we can attenuate dangerous temporal patterns without destroying a shader's aesthetic. Most visualiser software can't do this.

**Contributions in this space**: reviewing shader profiles for safety edge cases, proposing adjustments to the flicker-rate limiting algorithm, surfacing individual-difference considerations (some photosensitive users are triggered by specific colours or patterns, not just rates), helping draft the user-facing accessibility mode specification.

---

## GitHub workflow for non-developers

### If you've never used GitHub for editing before

1. **Create a GitHub account** if you don't have one (free)
2. **Go to the repo**: https://github.com/prometheus-exists/chromaticity
3. **For simple edits** (one file at a time):
   - Navigate to the file in your browser
   - Click the pencil icon ("Edit this file")
   - Make your changes
   - Scroll down, write a commit message (one line describing what you changed)
   - Click "Propose changes"
   - Click "Create pull request"
   - Write a short description of what and why
   - Submit
4. **We'll review** — this isn't an autonomous merge. Xavier or Prometheus will look at it, discuss if needed, and merge (or request changes).

### For multi-file edits
Use GitHub Desktop (https://desktop.github.com/) — it's a GUI, no command line needed. Follow its "Clone a repository" flow.

---

## What NOT to do

- **Don't propose code changes** if you're uncomfortable with the codebase. Open an issue instead; someone else will implement.
- **Don't rewrite large sections of docs** in a single PR — smaller PRs are easier to review and less likely to get bogged down.
- **Don't refactor without discussing first** — ping Xavier or open an issue to propose major changes.
- **Don't commit binary files** (audio, video, images) without checking — they bloat the repo. The `.gitignore` handles most cases but ask if unsure.

---

## What happens to your contribution?

Every merged PR gets credited:
- In the commit author field (GitHub tracks this automatically)
- In CHANGELOG.md under the relevant release
- In README.md contributors list for significant contributions

Your contributions are licensed MIT, same as the rest of the project (CONTRIBUTING.md covers this).

---

## When to ping whom

- **Licensing, scope, architectural decisions**: Xavier
- **Perceptual science, evaluation, CMC mappings**: Fletcher
- **Implementation, research synthesis, writing, coordination**: Prometheus (via Discord #lab or `@prometheus-exists` mention in issues)

For most non-code contributions, just open the PR or issue — we'll route from there.

---

## Roadmap of contribution surfaces

| Surface | Status | When ready |
|---------|--------|-----------|
| **Docs + glossary review** | ✅ **Ready now** | **Start here** |
| **Issues** | ✅ **Ready now** | Anytime |
| **Photosensitivity review** | ✅ Ready now | Anytime |
| Mapping profile schema (ADR-004) | ✅ Ready | Now |
| Audio features reference | 🔲 Not yet | Phase 2 |
| Name-heuristic dictionary | 🔲 Not yet | Phase 1, week 1 |
| Shader library | 🔲 Not yet | Phase 1 |
| Generated mapping profiles | 🔲 Not yet | Phase 1 |
| Perceptual review of outputs | 🔲 Not yet | Phase 2 |

### Concrete first task

Read `docs/reference/vocabulary.md`. Does anything in the perception-science column strike you as wrong, imprecise, or missing? Open an issue titled `vocabulary: [term]` with your proposed change and why. That's a meaningful contribution on day one, and your domain expertise is load-bearing for the whole project from that point on.

If you want to get started *now*, the surfaces marked ✅ above are live. Everything else becomes ready as Phase 1 lands.
