# Prototype Roadmap

## Scope Note

- This roadmap tracks the active branch runtime on `v2/core-refactor`.
- Older numbered patch docs are historical implementation records, not the current roadmap.
- Feature-design sequencing lives in `docs/design/roadmap.md`.

## Current Stage

The project is past the old early patch sequence and is now in the validation-and-follow-up stage for the current branch runtime.

What is already live:

- node-map flow
- combat / elite / rest / shop / boss structure
- gold pickup economy
- room-end mutation buying
- auto-fire rifle combat
- shockwave + dash skill loop
- encounter builder entry path

## Active Roadmap Order

### 1. Validation And Balance
Status: Active

- validate complete runs in `1P` and `2P`
- tune gold pacing
- tune mutation-buy costs
- tune elite difficulty and payout
- tune rifle / shockwave / dash feel
- validate shop usability and readability

### 2. Mutation Rarity Split
Status: Designed, not implemented

- room-end picks become common-only
- common mutations become upgradable
- rare mutations move to elite/shop delivery

Source of truth:
- `docs/design/roadmap.md`

### 3. Elite Reward Identity
Status: Open design question

- decide how elite rooms deliver rare mutations
- keep elite rooms meaningfully distinct from normal combat rooms

### 4. Side Objectives And Temporary Buffs
Status: Designed, not implemented

- optional room challenge layer
- room-end temporary shared buffs
- must improve positioning decisions without replacing combat

### 5. Encounter Depth Reintroduction
Status: Future

- modifiers
- better elite anchor threats
- boss redesign

### 6. Scale And Expansion
Status: Deferred

- `3-4` player support
- broader content expansion
- deeper meta systems

## Delivery Rule

One meaningful slice at a time:

- design locked first
- code implemented second
- parse clean
- live validated
- docs updated in the same slice

## Current Stop Condition

Do not widen scope casually.

The next meaningful work should come from one of these:

- live validation findings from the current loop
- Tier 1 to Tier 4 items in `docs/design/roadmap.md`

Anything outside that should be treated as deliberate expansion, not background maintenance.
