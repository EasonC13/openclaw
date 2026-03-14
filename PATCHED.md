# OpenClaw 2026.3.13 Patched Fork

## TL;DR

This fork is based on official OpenClaw `v2026.3.13-1` with one patch: infer the correct API type from provider when a model falls through to the generic fallback path.

Install:

```bash
curl -fsSL https://raw.githubusercontent.com/EasonC13/openclaw/release-3.13-patched/install.sh | sudo bash
```

Same command to upgrade (overwrites existing installation).

Switch back to official after upstream merges the fix:

```bash
sudo npm install -g openclaw@latest
```

---

## Investigation Timeline

### Initial Problem Report

After upgrading from OpenClaw 2.15 to newer versions (e.g. 2.24), `claude setup-token` auth stopped working. Downgrading to 2.15 appeared to fix it.

### What We Investigated

#### 1. `tokenRef` Resolution Gap (red herring for this case)

`src/agents/pi-auth-credentials.ts` (created 2026-02-22, commit `cec404225`) converts auth profiles to Pi credentials at runtime. It only reads the plaintext `cred.token` field and does NOT resolve `tokenRef` (SecretRef). Meanwhile, `src/agents/auth-profiles/store.ts:493` strips plaintext tokens when `tokenRef` is present.

- **Affects**: users who explicitly configured token storage via env var / file / vault (`tokenRef`)
- **Does NOT affect**: users who pasted tokens as plaintext (which is the common case)
- Related fix exists in `src/agents/auth-profiles/oauth.ts` (commit `6a251d8d7`) but was never ported to `pi-auth-credentials.ts`

#### 2. API Routing Fallback (the patch we applied)

`src/agents/pi-embedded-runner/model.ts` has a generic fallback for models not found in the built-in registry or forward-compat list. It hardcodes `api: "openai-responses"`, which routes requests to `/v1/responses` (OpenAI format) instead of `/v1/messages` (Anthropic format).

- **Issue**: [#19938](https://github.com/openclaw/openclaw/issues/19938) - "Anthropic setup-token auth broken after 2026.2.17 update"
- **Open PR**: [#20593](https://github.com/openclaw/openclaw/pull/20593) - "fix: route Anthropic OAT tokens to /v1/messages endpoint" (stale, not merged)
- **Affects**: models not in the built-in registry AND not handled by forward-compat (edge case for custom model IDs or very new models)
- **Does NOT affect**: known models like `claude-opus-4-6` which go through forward-compat and already get the correct API type

#### 3. The Actual Root Cause (token was invalid)

After setting up a second sandbox (port 24001) with OpenClaw 2.15 that worked, we compared the two environments:

| | Port 23001 (broken) | Port 24001 (working) |
|---|---|---|
| Profile | `anthropic:eason.tw.team` | `anthropic:eason.tw.chen` |
| Token | `sk-ant-oat01-PIDcNlm...` (82 chars) | `sk-ant-oat01-tna-PLV2...` (99 chars) |
| Status | **Invalid** (Anthropic returns 401) | **Valid** |

The two machines had **different tokens**. The broken machine's token had expired or been revoked. The "working on 2.15" observation was because 2.15 was tested on the machine with the valid token.

We verified by:
- Direct `curl` to Anthropic API with both tokens (bypassing OpenClaw entirely)
- Installing 2.15 on the broken machine — same 401 error
- Copying the valid token to the broken machine — 3.12 patched worked immediately

---

## The Patch

### What Changed

**File**: `src/agents/pi-embedded-runner/model.ts`

Added a provider-to-API-type mapping so the generic fallback doesn't blindly use `openai-responses` for every provider:

```typescript
const PROVIDER_DEFAULT_API: Partial<Record<string, Api>> = {
  anthropic: "anthropic-messages",
  "amazon-bedrock": "bedrock-converse-stream",
  google: "google-generative-ai",
  ollama: "ollama",
};

function inferApiForProvider(provider: string): Api {
  return PROVIDER_DEFAULT_API[normalizeProviderId(provider)] ?? "openai-responses";
}
```

Changed line 241 from:
```typescript
api: providerConfig?.api ?? "openai-responses",
```
to:
```typescript
api: providerConfig?.api ?? inferApiForProvider(provider),
```

### Practical Impact

For commonly used models (`claude-opus-4-6`, `claude-sonnet-4-20250514`, etc.), this patch has **no effect** because those models are resolved via the forward-compat path which already sets the correct API type.

The patch matters for:
- Custom model IDs not in the built-in registry
- Future models not yet added to forward-compat
- Any model that falls through all resolution steps to the generic fallback

### Test Results

- `model.test.ts`: 39 tests passed
- `pi-embedded-runner-extraparams.test.ts`: 67 tests passed

---

## Installation

### Why `npm install -g git+https://...` Doesn't Work

1. `dist/` is in `.gitignore` — npm needs to build from source when installing from git
2. `@whiskeysockets/baileys` has a `preinstall` script (`node ./engine-requirements.js`) that fails during npm's git install pipeline with `spawn sh ENOENT` — npm tries to run the script before the package directory is fully set up (known npm issue with nested git dependencies)
3. Using `--ignore-scripts` skips the build step AND bin linking, leaving a broken installation

### How the Install Script Works

The `install.sh` script bypasses npm's broken git install by:

1. `git clone` directly to `/usr/lib/node_modules/openclaw/` (includes pre-built `dist/`)
2. `npm install --omit=dev --ignore-scripts` (installs runtime deps without triggering baileys)
3. `ln -sf` to create the `/usr/bin/openclaw` symlink manually
4. Removes `.git/` to save space

### Branches

- `release-3.12-patched` — Based on `v2026.3.12`, patch + dist + install script
- `release-3.13-patched` — Based on `v2026.3.13-1`, same patch + dist + install script

---

## Upstream Status

| Item | Status |
|------|--------|
| Issue [#19938](https://github.com/openclaw/openclaw/issues/19938) | Open (stale) |
| PR [#20593](https://github.com/openclaw/openclaw/pull/20593) | Open (stale) |
| `pi-auth-credentials.ts` tokenRef fix | No PR exists |
| Official npm `openclaw@2026.3.13` | Does not include the patch |
