# Ricochet AI Assistant — Product & Engineering Plan (v5)

> **Status:** For review (build-ready spec)  
> **Branding:** **AI Assistant**  
> **Platforms:** macOS + Windows  
> **Design bar:** Figma / Notion / Linear tier — never “academic software from 2010”

---

## 1. Design philosophy

| Principle | What it means in practice |
|-----------|---------------------------|
| **Progressive disclosure** | Simple by default; advanced fields collapsed |
| **Stateful micro-interactions** | Connection, generation, streaming use animated state machines |
| **Incremental reveal** | Elapsed-time UX — not provider guessing |
| **Reversible edits** | Command diffs; pipeline ghosts with explicit accept/discard semantics |
| **Trust through transparency** | Never silent: truncation, validator failures, discard, indirect exit |
| **Local-first** | Keys on device; opt-in telemetry with explicit allow-list |

**Reuse discipline:** `getCycleConnections()`, `fitViewRequest`, `TemplateNodeDef`, `loadTemplate()` / `_saveHistoryState`.

---

## 2. Resolved product decisions

| Question | Decision |
|----------|----------|
| Default provider | Blank / Custom; Ollama first preset, not pre-filled |
| API key storage | `flutter_secure_storage` in Phase 0 |
| Pipeline preview | Slide-in side panel + ghost canvas |
| Branding | **AI Assistant** |
| Ghost editing | **Focus-only** interaction until accept (§6.4) |
| Partial accept + Discard | Accepted stay; Discard removes only remaining ghosts (§6.6) |
| Indirect exit (Settings, tab close) | **Discard-remaining** after confirm (§6.8) |
| Pipeline streaming | Cosmetic until full JSON validated (§9.2) |
| Latency UX | Elapsed-time thresholds (§9.1) |
| Pill during request | `connecting` **supersedes** idle `ready` / `readyLocal` (§4.2) |
| Command Regenerate | Same cached context + “different alternative” turn (§8.4) |
| Pipeline Regenerate | Panel-open only while `DRAFT_ACTIVE`; visible-disabled in step-by-step (§6.7) |
| Description on Regenerate | Panel field is **persistent source of truth** across regenerates (§6.7) |
| Telemetry latency | **Yes** — bucketed only, no raw ms (§12.2) |

---

## 3. Motion design tokens (`AiMotionTokens`)

Placeholder timings — **needs motion-design pass**. All durations in `lib/theme/ai_motion_tokens.dart` only.

```dart
abstract final class AiMotionTokens {
  static const testConnectionMinSuccess = Duration(milliseconds: 400);
  static const progressStepMin = Duration(milliseconds: 300);
  static const ghostNodeStagger = Duration(milliseconds: 80);
  static const panelSlide = Duration(milliseconds: 280);
  static const latencyThresholdSlow = Duration(seconds: 3);
  static const latencyThresholdVerySlow = Duration(seconds: 10);
}
```

---

## 4. Global chrome: persistent AI status

### 4.1 Status pill — state machine

| State | Visual | Enter | Exit |
|-------|--------|-------|------|
| `disconnected` | Grey pulse | AI on, untested / last fail | Test starts |
| `connecting` | Amber pulse | **Any in-flight AI request** or test | Complete / cancel / fail |
| `ready` | Indigo solid | Cloud test OK, idle | Request starts / fail |
| `readyLocal` | Green solid | Loopback test OK, idle (label only) | Request starts / fail |
| `error` | Red | Last op failed | Retry / success |

**Popover:** provider, model, URL, last test, **Open AI Settings** · **Test again** · **Disable AI**.

**Popover during requests (§4.2):** binds to the **same live pill state** — if opened mid-request, shows `connecting`, elapsed time, and **Cancel**; never a stale last-idle `readyLocal` snapshot.

### 4.2 Idle vs in-flight — no conflicting signals

**Rule:** While any AI request is active, the pill is **`connecting` (amber)** — it **visually supersedes** idle `ready` / `readyLocal` (green/indigo).

| Surface | During request |
|---------|----------------|
| Status pill | Amber `connecting` — not green “Local · Ollama” |
| In-feature UI | `Thinking… {N}s` / progress sequence (§9.1) |

User must **never** see green “Ready” on the pill and “Thinking… 45s” in the panel as simultaneous contradictory signals. On request end, pill returns to last idle state (`ready` / `readyLocal` / `error`).

`readyLocal` is a **post-success idle label only** — not a runtime performance indicator.

---

## 5. Settings: AI Assistant connectivity

### 5.1–5.3

Same card pattern as Parallel Execution; animated Test Connection; fields as in v3.

### 5.4 Preset vs manual URL

Preset autofills URL; manual edit → selector reverts to **Custom**; re-pick preset confirms overwrite if edited.

---

## 6. Feature: Generate Pipeline (Home)

### 6.1 Entry card

Native card in `_RightPanel`. Disabled / disconnected states as in v3.

### 6.2 Progress sequence

Cosmetic steps with `AiMotionTokens.progressStepMin`; elapsed-time UX while waiting (§9.1).

### 6.3 Preview — side panel + ghost canvas

Draft mode → ghosts on canvas → AI Preview panel (~380px, resizable). Initial `fitViewRequest` after ghost stagger.

### 6.4 Ghost interaction matrix

Ghosts are **not editable** but **not fully inert**. Explicit allow-list:

| Input | Allowed? | Effect |
|-------|----------|--------|
| **Hover** (canvas or panel row) | ✅ | Corresponding ghost/panel row **pulse highlight** (bidirectional) |
| **Single click** on ghost | ✅ | **Focus only** — scroll panel to that row, highlight row; no edit |
| **Single click** on panel row | ✅ | Focus ghost on canvas (pan if needed, pulse) |
| Drag | ❌ | Ignored |
| Double-click | ❌ | Ignored |
| Connect / disconnect handles | ❌ | Hidden on ghosts |
| Open parameter sidebar | ❌ | Until node accepted |
| **Summary ghost** `"+ N more nodes"` (§7.3) | ✅ click | **Scroll panel** to first hidden node (index 33+); pulse that row. Does not expand canvas layout. |

**Terminology:** ghosts are **read-only, focusable previews** — not interactive graph nodes.

### 6.5 Acceptance model — state diagram

Actions: **Accept all** · **Step-by-step** · **Regenerate** · **Discard**

```
                    ┌─────────────────┐
                    │  DRAFT_ACTIVE   │
                    └────────┬────────┘
         ┌───────────────────┼───────────────────┬──────────────┐
         ▼                   ▼                   ▼              ▼
   [Accept all]      [Step-by-step]          [Regenerate]   [Discard]
         │                   │              (§6.7)            │
         ▼                   ▼                   ▼              ▼
   … (as v3)           … (as v3)          Replace all      Discard-remaining
                                         pending ghosts     (§6.6)
```

Step-by-step: no re-fit per accept; panel scrolls to next; one undo entry per accept.

### 6.6 Discard (explicit + partial)

- **Discard** = remove **remaining** ghosts; accepted nodes **stay**
- Copy when partial: *“Remove remaining suggestions? Accepted nodes will stay.”*
- Discard ≠ Undo

### 6.7 Pipeline Regenerate

**Session rule:** **Regenerate is only available while `DRAFT_ACTIVE`** (preview panel open with a draft). Once **Accept all**, **Discard** (panel closes), or indirect exit completes, the session ends — user must invoke **Generate** again from Home. Regenerate is not available from a closed panel.

**Placement:** Preview panel primary actions — `Accept all` · `Step-by-step` · **`Regenerate`** · `Discard` (fixed order; Regenerate slot always reserved for stable layout).

| Condition | Regenerate UI | Behavior |
|-----------|---------------|----------|
| **Zero nodes accepted** | **Enabled** | Re-send **current panel description** (§ below) + system addendum: *“The user wants a different pipeline approach than your previous draft…”* Replace all ghosts after validate. |
| **Step-by-step active, ≥1 pending ghost, zero accepts so far** | **Enabled** | Same as above (user hasn’t committed any node yet). |
| **≥1 node accepted** | **Visible, disabled** | Stays in toolbar throughout step-by-step — **not hidden** (avoids layout shift). Tooltip on hover: *“Finish review or discard remaining suggestions first.”* No click action. |

**Description field (iterative refinement):** editable textarea at top of preview panel. On first Generate, seeded from Home card text. **Every edit persists as the source of truth** — each Regenerate uses the **current panel text**, not the original Home submission. Edit → Regenerate → edit → Regenerate is the intended workflow; text is never reset unless the user clears it or starts a new Generate from Home.

Cosmetic stream during regenerate (§9.2). Telemetry: `ai.generate.regenerate_clicked` then **`ai.generate.completed` with `is_regenerate: true`** (§12.2).

### 6.8 Indirect exit — panel close, navigation, tab close

**Not covered by Discard button alone.** Rules:

| User action | Behavior |
|-------------|----------|
| **Panel close (×)** or **Escape** | If pending ghosts exist → confirm: *“Leave review? Accepted nodes stay; remaining suggestions will be removed.”* On confirm → **Discard-remaining** (§6.6). If all accepted or no ghosts → close silently. |
| **Navigate Home / Settings** | Same confirm if `DRAFT_ACTIVE` with pending ghosts |
| **Close pipeline tab** | Same confirm if draft active on that tab |
| **Switch to another tab** | Draft **persists on original tab** (ghosts remain); no confirm. User can return and continue review. |

**No silent persistence forever:** ghosts do not outlive tab lifetime. On tab close (confirmed) → Discard-remaining. **No background draft session** across app restart.

Indirect exit ≡ Discard-remaining (after confirm), not “pause and resume later” except tab switching within the same session.

### 6.9 AI output schema

Structured JSON → `TemplateNodeDef`. No coordinates from AI.

---

## 7. Technical: validation & layout

### 7.1 Validator — reuse `getCycleConnections()`

As v3. No second cycle detector.

### 7.2 Unknown Docker image UX

Suggestion chips + Swap / Search Hub / Remove. Never silent.

### 7.3 Auto-layout + overflow

Grid from **(25000, 25000)**; `maxNodesPerColumn = 8`; sub-column offset `+140px` X.

**Sub-column cap (MVP):** max **4 sub-columns** per level (= 32 positioned ghosts).

**Beyond 32 nodes in one level** (rare — e.g. parallel QC across many samples):

- Position first 32 normally  
- Render **one summary ghost**: `"+ {N} more nodes"` — see §6.4 for click behavior (panel scroll to node 33+)
- Panel lists **full** node set with scroll  
- Explicit MVP punt — not silent clip  

One `fitViewRequest` after layout.

---

## 8. Feature: Command suggestion (Editor)

### 8.1 Placement

`✦ Suggest` chip on command fields.

### 8.2 Diff-first insertion

Stream → diff → **Accept** · **Discard** · **Regenerate**

### 8.3 Context caps + truncation

Caps as v3. When truncated: prompt footer + UI chip *“Limited context — large pipeline”*. Never silent.

### 8.4 Command Regenerate — prompt & cache rules

| Aspect | Rule |
|--------|------|
| **Context** | Reuse **cached `AiPromptBundle`** from initial Suggest (same caps, same truncation footer) — do not recompute pipeline walk unless node/upstream changed |
| **API messages** | Resend same system + user context; **append** assistant turn (previous suggestion) + user turn: *“Provide a different command alternative. Do not repeat the previous suggestion.”* |
| **Temperature** | User setting unchanged (default 0.2); diversity from explicit instruction, not random nonce |
| **Regenerate count** | Track in session UI (*“Alternative 2”*); no hard cap in v1 |
| **Invalidation** | Cache clears if user changes node, upstream graph, or navigates away from parameter sidebar |

---

## 9. Latency, streaming & cancel

### 9.1 Elapsed-time UX (provider-agnostic)

| Elapsed | UI |
|---------|-----|
| `< 3s` | Standard spinner / progress step |
| `3s – 10s` | `Thinking… {N}s` + cancel |
| `≥ 10s` | Above + rotating hints |

Pill shows `connecting` throughout (§4.2).

### 9.2 Streaming vs validation

| Feature | Streaming | Apply |
|---------|-----------|-------|
| Command suggest | Semantic | Diff on complete; Accept only |
| **Generate / Regenerate pipeline** | **Cosmetic** — “Receiving…” | Parse + validate + ghosts **after full JSON** |
| Error explain | Cosmetic | Phase 3 |
| Test connection | None | Immediate |

**v1: no incremental JSON parsing.** Partial JSON unsafe for cycle detection.

### 9.3–9.4

Cancel anytime. Error copy as v3.

---

## 10. Additional surfaces (phased)

Tier 2: Error explain · NL Docker search · Template match  
Tier 3: Pipeline review · Pre-flight · Parameter explain

---

## 11. Architecture

```
lib/theme/ai_motion_tokens.dart
lib/models/ai_prompt_bundle.dart      # Cached context + truncation footer
lib/models/ai_draft_session.dart        # DRAFT_ACTIVE, accept count, description
lib/controllers/ai_draft_controller.dart
… (as v3)
```

---

## 12. Security, privacy & telemetry

### 12.1 Security

Keys in secure storage; no secrets in JSON; no prompt logging in release.

### 12.2 Telemetry allow-list (opt-in, default off)

**Events:**

| Event | Properties |
|-------|------------|
| `ai.settings.opened` | — |
| `ai.connection.test_clicked` | — |
| `ai.connection.test_result` | `success: bool`, **`latency_bucket`** |
| `ai.generate.clicked` | — |
| `ai.generate.completed` | `success: bool`, `node_count: int`, `latency_bucket` (on success), **`is_regenerate: bool`** |
| `ai.generate.regenerate_clicked` | — (outcome → **`ai.generate.completed`** with `is_regenerate: true`) |
| `ai.generate.accepted` | `mode: all \| step` |
| `ai.generate.discarded` | `had_partial_accept: bool` |
| `ai.command.suggest_clicked` | — |
| `ai.command.suggest_completed` | `success: bool`, `latency_bucket` (on success), **`is_regenerate: bool`** |
| `ai.command.regenerate_clicked` | — (outcome → **`ai.command.suggest_completed`** with `is_regenerate: true`) |
| `ai.command.accepted` | — |
| `ai.error.explain_clicked` | Phase 3 |

**`latency_bucket` (deliberate yes):** coarse anonymous timing to validate §9.1 thresholds and motion tokens in the wild.

| Bucket | Condition |
|--------|-----------|
| `fast` | `< AiMotionTokens.latencyThresholdSlow` (~3s) |
| `moderate` | 3s – 10s |
| `slow` | `≥ 10s` or timeout |

**No raw milliseconds.** Aligns with UX buckets — not a privacy stretch.

**Never collected:** model name, base URL, API key, prompts, responses, pipeline content, file paths, stderr.

---

## 13. Implementation phases

### Phase 0 — Foundation ✅ (in progress / shipped in branch)

| Item | Status |
|------|--------|
| `AiMotionTokens` | ✅ |
| `AiConnectivitySettings` + `AppSettings` extension | ✅ |
| `flutter_secure_storage` (`FlutterAiSecureStorage`) | ✅ |
| `AiService.testConnection()` | ✅ |
| `AiTelemetryService` allow-list + no-op sink | ✅ |
| `AiController` pill state machine | ✅ |
| Settings → AI Assistant section + Test Connection UI | ✅ |
| `AiStatusPill` + popover (home + editor) | ✅ |
| Unit tests (models, service, controller) | ✅ |
| Motion-design pass on tokens | 🔲 follow-up |

### Phase 1 — Command assist

- [x] `AiPromptBuilder.forCommand()` + truncation footer
- [x] Streaming suggest + inline diff accept/discard/regenerate
- [x] Elapsed-time waiting UX in editor
- [x] Undo via `_saveHistoryState` (accept uses `updateNodeParameter`)

### Phase 2 — Generate pipeline

- [x] Home AI generate card + progress sequence
- [x] Cosmetic stream → parse → validate → ghosts
- [x] `AiDraftController` state machine (accept step-by-step, regenerate, discard)
- [x] Preview side panel + layout overflow rules
- [x] Hub unknown-image suggestion chips

### Phase 3 — Error explain + NL Docker search

- [x] Execution panel explain
- [x] Tool sidebar NL search assist

### Phase 4 — Advanced

- [x] Pipeline review · pre-flight · parameter explain (pre-flight + AI review sheet)
- [x] Telemetry backend (opt-in, allow-list only — local JSONL sink)

---

## 14–16

Success metrics, not-building list, provider presets — as v3.

---

## 17. Spec strengths (cumulative)

- Accept/discard state diagram with partial-accept product decision (§6.5–6.6)  
- Honest streaming table — cosmetic pipeline stream, no mid-stream ghosts (§9.2)  
- Elapsed-time latency, not URL-sniffing (§9.1)  
- Telemetry allow-list with literal events + never-collected list (§12.2)  
- `AiMotionTokens` as tunable placeholders (§3)  
- **“Never silent” enforced** across truncation, validation, discard, indirect exit (§1, §6.8, §8.3)

---

*v5 adds Regenerate visibility rules, session terminality, description persistence, regenerate telemetry pairing, summary-ghost click, and live popover state.*
