# CODEX VECTORVERSE MASTER LAUNCH

## Scope
Work only inside:
`/Users/angie/Documents/SYN_HUMANITY_MASTER/VectorVerse-Godot`

Do not touch SynAtoms, SynAI, Halo, HorizonMacBridge, Nexus, `.prime`, Alien Planet, or any legacy project.

Use Terminal directly. Do not ask Angie to type commands, edit files, locate folders, or manually compare outputs.

## Authority order
1. Read the Google Drive document `READ FIRST - VectorVerse VR Universal Block System Product Authority` completely.
2. Read the local `README.md`, but treat stale statements as historical notes when they conflict with current evidence or Angie’s direct headset report.
3. Inspect the actual repository before relying on handoff claims.
4. Treat `Main.tscn`, `src/spatial_world.gd`, and `src/xr_interaction_adapter.gd` as the current spatial authority unless direct inspection proves otherwise.
5. Treat `prototypes/2d_ui_reference/` as a preserved reference, not the product basis.

## Non-negotiable integrity rules
- Preserve all current files before changing behavior.
- Do not delete, rename, move, overwrite, or reorganize unrelated files.
- Do not redesign the visual world, add marketplace, multiplayer, new languages, networking, or unrelated features.
- AI is advisory only. The graph, schemas, validator, typed IR, backend, tests, and evidence are authoritative.
- Keep graph-validity errors separate from backend-support errors.
- Unsupported behavior must fail visibly. Never guess, silently weaken behavior, or generate fake stubs that pretend success.
- GDScript is the only current backend target.
- Mark nothing proven without deterministic build and runtime evidence.
- Change one evidence-backed layer at a time.

## Current verified foundation to replay, not assume
The repository currently contains:
- Spatial Godot project and authoritative `Main.tscn`
- Compatibility-driven App Start and Log/Display placement
- Deterministic GDScript generation for the narrow App Start → Log slice
- Desktop interaction tests
- XR adapter contract tests
- Quest preflight/build/launch tooling
- Existing evidence files under `evidence/`

Angie directly confirmed that the real Quest headset displayed the world and completed the Hello World-style flow. Existing files may still contain older statements saying headset acceptance is pending. Do not overwrite user-confirmed reality with stale documentation, but independently verify preserved evidence where possible.

## PHASE 0 ONLY: Replay and integrity verification
Make no code changes during Phase 0.

### A. Repository integrity snapshot
Record:
- absolute path
- git status or absence of a repository
- hashes of `Main.tscn`, `src/spatial_world.gd`, `src/xr_interaction_adapter.gd`
- Godot version
- newest Quest APK path, size, and SHA-256
- existing checkpoint/archive paths
- list of current evidence files

Do not include `.godot/`, generated caches, APK archives, or transient logs in source-change conclusions.

### B. Replay all current headless tests
Run exactly:
- `tests/vertical_slice_test.gd`
- `tests/player_interaction_test.gd`
- `tests/xr_adapter_contract_test.gd`
- `tests/quest_smoke_preflight_test.gd`

Capture complete stdout, stderr, exit code, and resulting evidence hashes.

Expected pass markers currently include:
- `VECTORVERSE_ACCEPTANCE_PASS`
- `VECTORVERSE_SPATIAL_3D_PASS`
- `VECTORVERSE_XR_ADAPTER_PASS`
- `VECTORVERSE_QUEST_PREFLIGHT_PASS`

Do not treat marker text alone as proof. Confirm exit code, generated evidence, and the underlying assertions.

### C. Deterministic regeneration replay
Run the narrow App Start → Log pipeline twice from the same frozen graph input.
Verify:
- generated source matches byte-for-byte
- generated SHA-256 is stable
- graph save/load round trip does not change generated output
- diagnostics remain stable
- actual runtime output remains exact

Preserve the currently expected repository output string exactly as observed. Do not normalize `Hello, VectorVerse!` into a different phrase.

### D. Quest checkpoint verification
Without rebuilding or altering the project:
- inspect the newest existing APK
- verify package name and launch activity
- verify prior Quest build/launch evidence and logs
- detect whether one authorized Quest is currently connected
- do not install, rebuild, or launch unless Angie explicitly asks during this session

Clearly separate:
1. headless XR contract proof
2. APK build/install/process-launch proof
3. user-confirmed in-headset visual/interaction proof
4. any evidence that is still missing

### E. Stale-claim audit
Identify documentation or evidence that still says headset visibility or acceptance is pending despite Angie’s later confirmation. Report it, but do not edit it during Phase 0.

### F. Phase 0 output
Return one compact report containing:
- VERIFIED
- USER-CONFIRMED BUT NOT FULLY REPRODUCED THIS SESSION
- STALE OR CONTRADICTORY
- UNPROVEN
- exact hashes and test outcomes
- first proposed implementation change after Phase 0

Stop after the report. Do not modify code until Angie approves the next phase.

## Approved implementation sequence after Phase 0 approval
1. Freeze human block schemas, typed ports, and separate control/data edges.
2. Implement versioned IR serialization and graph/type/capability/backend-support validation.
3. Bring the existing Program 1 generator into full contract compliance with deterministic regeneration, source mapping, and diagnostics.
4. Add deterministic save/load and validator-driven Morphing Panel filtering.
5. Implement Program 2 only: App Start → Bool literal → Condition → two Log actions.
6. Implement Program 3 only: App Start → non-persistent State Write → State Read → Log.
7. Run desktop and Quest proof cycles and archive evidence for all three programs.

Do not begin a later item until the previous item has deterministic evidence and Angie has approved continuation.

Signed: ChatGPT (GPT-5.6 Thinking), July 17, 2026
