# Architecture

The reference the code is written against. Source comments cite it by section — you will
see `ARCHITECTURE §3` and the like throughout the module.

Two things are in here:

* **the invariants this module holds itself to** (§0, §5), each enforced by a lint rule,
  a spec, or both;
* **how the Vocdoni SaaS API behaves** (§1–§4), as observed against a running deployment.
  Where this disagrees with the Vocdoni SDK documentation, what is written here is what
  the API does.

## 0. Invariants

Each of these is here because getting it wrong costs somebody a ballot or their ballot
secrecy, not because it is tidy.

1. **No Node.js on the server.** Ruby talks to the SaaS REST API over HTTPS. Never shell out.
2. **No secret ever reaches the browser.** The API key is server-side only. The voter path uses
   only public/CSP-token routes.
3. **No secret in process-global state.** Never assign to `ENV` at runtime; pass config explicitly.
4. **No `console.log` in the voter path.** Ballots and keys must never hit the console. ESLint
   enforces `no-console` under `app/packs/src/decidim/secure_elections/voter/`.
5. **No SaaS call inside a web request.** All writes and all slow reads go through ActiveJob;
   the UI polls a cheap Decidim-local endpoint backed by a cached column.
6. **Fail loudly on misconfiguration.** `Decidim::SecureElections.validate_configuration!` raises rather
   than defaulting to a test chain.

## 1. Vocdoni model → Decidim model

| Decidim | Vocdoni | Column |
|---|---|---|
| `Decidim::SecureElections::Election` | process (Mongo ObjectID, 24 hex) | `vocdoni_process_id` |
| `Decidim::SecureElections::Question` | question — its own Vochain election | `vocdoni_upstream_id` |
| `Decidim::SecureElections::Answer` | choice `{title, value}` | `value` |

One process has many questions. **Each question is a separate Vochain election.** Voting casts
one transaction per question. `sign()` takes the *question's* `upstreamId` as `electionId` —
never the process id. This is the single easiest thing to get wrong.

## 2. Ruby `ApiClient` contract

`Decidim::SecureElections::ApiClient.new` reads config from `Decidim::SecureElections`. Sub-clients mirror the
SDK: `#elections`, `#organizations`, `#census`, `#jobs`.

Required methods (snake_case Ruby, hash returns with string keys):

```ruby
client.organizations.create_managed(name:, type:, website: nil, country: nil, timezone: nil)
  # POST /integrator/organizations -> { "address" => "0x…", … }
client.organizations.add_members(org_address, members)   # POST /organizations/{addr}/members
client.organizations.groups(org_address)                 # GET  /organizations/{addr}/groups

client.elections.create(payload)                # POST /processes            -> { "processId" => … }
client.elections.get(process_id)                # GET  /processes/{id}       (PUBLIC, no auth)
client.elections.validate(process_id)           # GET  /processes/{id}/validation
client.elections.publish(process_id)            # POST /processes/{id}/publish -> { "jobId" => … }
client.elections.results(process_id)            # GET  /processes/{id}/results (PUBLIC)
client.elections.bulk_set_question_status(process_id, status:, question_ids: nil)
                                                # PUT  /processes/{id}/questions/status
client.elections.participants(process_id, field:, value:)

client.jobs.get(job_id)                         # GET  /jobs/{id}
client.jobs.wait_for(job_id, timeout: …)        # poll until terminal
```

### 2.1 Payload quirks — these bite

* **Language maps are mandatory.** `POST /processes` rejects a plain string for `title`,
  `description` or a choice `title` with `{"error":"invalid JSON request body","code":40004}`.
  The JS SDK normalizes plain strings client-side; **Ruby must do the same**. Provide a private
  `localize(value)` that turns `"Hi"` into `{ "default" => "Hi" }` and passes a Decidim
  translated hash (`{"en" => "Hi"}`) through as `{ "default" => <default-locale value>, "en" => … }`.
* **The process census is inline**, not a reference:
  `census: { authFields: ["memberNumber"], groupId: "<org group id>", weighted: false }`.
  The standalone `POST /census` flow is a *different*, org-level concept — do not use it.
* **Question type strings are lowercase**: `"singlechoice"`, `"multichoice"`. camelCase is
  rejected (code 40037). `multichoice` additionally requires
  `typeSetup: { maxChoices:, minChoices:, uniqueChoices: }`.
* **`ballotProtocol` comes back `null`** for singlechoice questions. Never assume it is present.

### 2.2 Async jobs

`publish`, `bulk_set_question_status` and the vote relay all return `{"jobId": …}`.
Poll `GET /jobs/{id}` until `status` is `completed` or `failed`.

⚠️ The job body contains a **nested `result.status`** (e.g. `"READY"`) that is *not* the job
status. Parse `body["status"]` at the top level only — a naive regex/`sed` grabs the wrong one.

A successful publish looks like:
`{"jobId":"…","type":"publish_voting_process","status":"completed","result":{"status":"READY"}}`

### 2.3 A complete request

```json
POST /processes
{
  "orgAddress": "0x0000000000000000000000000000000000000001",
  "title":       { "default": "…" },
  "description": { "default": "…" },
  "endDate": "2026-07-29T14:51:08Z",
  "census": { "authFields": ["memberNumber"], "groupId": "000000000000000000000001", "weighted": false },
  "questions": [{
    "title": { "default": "…" },
    "type": "singlechoice",
    "choices": [{ "title": { "default": "Yes" }, "value": 0 },
                { "title": { "default": "No" },  "value": 1 }]
  }]
}
```
`startDate` may be omitted — the process then starts as soon as it is published.

## 3. Voter flow (browser only)

The sequence implemented in `app/packs/src/decidim/secure_elections/voter/`.

```
1. client.elections.get(processId)              → chainId  (PUBLIC; never use client.info())
2. client.processes.authStep0(processId, {...}) → authToken
     census.twoFaFields null/empty ⇒ auth-only: token is already verified, SKIP authStep1
     otherwise                     ⇒ authStep1(processId, { authToken, authData: [otp] })
3. client.processes.check(processId, { authToken })
     → { belongsToProcess, weight, questions: [{ questionId, upstreamId, canVote, hasVoted }] }
       Ineligible is belongsToProcess=false with HTTP 200 — not an error. Handle it as UI state.
4. per question: client.processes.getQuestion(processId, questionId)  (PUBLIC)
5. const signer = new EphemeralSigner()          // fresh per vote, never reused
   client.processes.sign(processId, { authToken, electionId: upstreamId, payload: signer.address })
     → { signature, weight }        // a question's signing slot is consumed on success
6. votingClient.vote({ processId: upstreamId, chainId, choices, signer,
                       cspSignature, cspWeight })            → jobId
7. client.jobs.waitFor(jobId)                    → job.result.voteID   // the nullifier
```

Ballot encoding — `ballotProtocol` may be absent, so branch on question type:
* `singlechoice` → `[selectedIndex]`
* `multichoice`  → one element per choice, `1` selected / `0` not

For `secretUntilTheEnd` questions, `question.encryptionKeys` is **absent until the keykeepers
publish**. Poll until present and only then build the ballot — never cast cleartext as a fallback.

## 4. Values read from a deployment

| Key | Value |
|---|---|
| API base | `https://saas-api-stg.vocdoni.net` |
| Frontend (not the API) | `app-stg.vocdoni.io` — returns HTML for every path, so it is not the API |
| orgAddress | `0x…` — one per integrator, from `organizations.create_managed` |
| chainId | `vocdoni/LTS/1.2` (read from the process, not `/info`) |
| Auto member group | every organization gets an "All members" group on creation |

The whole voter flow was walked end to end against staging, including a real vote whose
nullifier was returned.

## 4b. Database schema

`decidim_vocdoni_elections`
| column | type | notes |
|---|---|---|
| `decidim_component_id` | integer, indexed | |
| `title`, `description` | jsonb | translatable |
| `start_time`, `end_time` | datetime | `start_time` null ⇒ starts on publish |
| `published_at`, `deleted_at` | datetime | `Publicable`, `SoftDeletable` |
| `vocdoni_process_id` | string, indexed | Mongo ObjectID; null until pushed on-chain |
| `vocdoni_chain_id` | string | cached from the process read |
| `census_auth_fields` | jsonb, default `[]` | e.g. `["memberNumber"]` |
| `census_two_fa_fields` | jsonb, default `[]` | empty ⇒ auth-only |
| `census_group_id` | string | Vocdoni org member-group id |
| `census_size` | integer, default 0 | |
| `status` | string, default `"draft"` | `draft/publishing/ready/paused/ended/results/canceled` |
| `results_cache` | jsonb, default `{}` | last tally read; what the UI polls |
| `results_synced_at` | datetime | |
| `votes_count` | integer, default 0 | denormalized from `results_cache` |
| `reference` | string | `HasReference` |

`decidim_vocdoni_questions`
| column | type | notes |
|---|---|---|
| `decidim_vocdoni_election_id` | fk, indexed | |
| `title`, `description` | jsonb | translatable |
| `question_type` | string, default `"singlechoice"` | `singlechoice` \| `multichoice` |
| `max_choices`, `min_choices` | integer, null | multichoice only |
| `secret_until_the_end` | boolean, default false | |
| `position` | integer | |
| `vocdoni_question_id` | string | question id inside the process |
| `vocdoni_upstream_id` | string, indexed | **Vochain election id — used for sign/vote** |
| `vocdoni_status` | string | mirrors QuestionStatus |
| `answers_count` | integer, default 0 | counter cache |

`decidim_vocdoni_answers`
| column | type | notes |
|---|---|---|
| `decidim_vocdoni_question_id` | fk, indexed | |
| `title` | jsonb | translatable |
| `value` | integer, not null | 0-based; the on-chain choice value |
| `position` | integer | |
| `votes_count` | integer, default 0 | from `results_cache` |

Elections are `Publicable`, `SoftDeletable`, `Traceable`, `Loggable`, `Resourceable`,
`HasComponent`, `TranslatableResource`, `Searchable`, `HasReference`, `FilterableResource`.

`Election#editable?` ⇒ `vocdoni_process_id.blank?` (nothing on chain yet).
`Election#on_chain?` ⇒ `vocdoni_process_id.present?`.

## 4c. Census creation — Decidim owns it

The admin must **never** see or type a Vocdoni id. Decidim collects voters, then
builds the whole upstream chain itself. Verified endpoints, in order:

```
1. POST /organizations/{orgAddress}/members
     { members: [{ name, surname, email, phone, memberNumber, nationalId, birthDate, weight }] }
     → { added, errors[], jobId? }   ← poll jobId when present
2. POST /organizations/{orgAddress}/groups
     { title, description?, memberIds: [...] }        → { id }
3. POST /organizations/{orgAddress}/groups/{groupId}/validate
     { authFields, twoFaFields }                      → { valid } | 400 with detail
4. POST /census                 { orgAddress }        → { id }
5. POST /census/{censusId}/group/{groupId}/publish
     { authFields, twoFaFields, weighted }            → { root, size, uri }
6. POST /processes ... census: { authFields, twoFaFields, groupId, weighted }
```

Step 3 is what catches "you asked to authenticate on `email` but 12 members have
none" *before* anything is written on chain. Surface its errors per member.

### What `PublishElectionJob` actually issues, and when it skips

The list above is the full path. Most publications are shorter, because each
call is conditional — which is also what makes a retry after a mid-way failure
safe rather than duplicative.

| # | Call | Skipped when |
|---|------|--------------|
| 1 | `POST /organizations/{org}/members` | no local voter is missing a `vocdoni_member_id` |
| 2 | `GET /jobs/{jobId}` | step 1 answered synchronously (no `jobId`) |
| 3 | `GET /organizations/{org}/members?page=N` | every local voter already has an upstream id — the import does not return them, so they have to be read back; paginated, capped at 200 |
| 4 | `POST /organizations/{org}/groups` | the census already points at a group Decidim did not build |
| 5 | `POST …/groups/{gid}/validate` | never |
| 6 | `POST /census` | never |
| 7 | `POST /census/{cid}/group/{gid}/publish` | never |
| 8 | `POST /processes` | `vocdoni_process_id` is already set |
| 9 | `GET /processes/{pid}` | never — the read-back *before* publishing is what makes a retry safe |
| 10 | `POST /processes/{pid}/publish` | step 9 reports the process already published |
| 11 | `GET /jobs/{jobId}` | never |
| 12 | `GET /processes/{pid}` | never — second read; persists per-question `upstreamId`, chain id, census size, status |

The whole census phase (1–7) is skipped once `vocdoni_process_id` is set: a
published process carries a frozen census, so there is nothing left to build.

Two consequences worth knowing:

- **A 400 from step 5 is an answer, not a failure.** It is recorded with the
  member ids it names and the job stops cleanly; nothing is written on chain.
- **Step 4 rebuilds the group on every attempt**, leaving superseded groups
  behind upstream. Harmless, but it means group count is not a useful signal.

### ⚠️ `weight` must be a STRING

`POST /organizations/{addr}/members` fails when a member's `weight` is a JSON
number, even though `@vocdoni/api-types` declares `weight?: number`:

```
{"weight": 1}    → 400 {"error":"invalid JSON request body: missing members","code":40004}
{"weight": "1"}  → 200 {"added":1,"errors":[]}
{}  (omitted)    → 200
```

The error names the **wrong field**: an unmarshal failure anywhere in the member
object is reported as "missing members", which sends you hunting through the
array shape instead of the offending value. Verified against staging.

### Member fields

| id | label | 2FA-capable | usable as credential |
|---|---|---|---|
| `name` | First name | | ✓ |
| `surname` | Last name | | ✓ |
| `email` | Email | ✓ | |
| `phone` | Phone | ✓ | |
| `memberNumber` | Member number | | ✓ |
| `nationalId` | National ID | | ✓ |
| `birthDate` | Birth date | | ✓ |
| `weight` | Voting power | | never |

`authFields` (credentials) are chosen from the ✓ column, **max 3**.
`twoFaFields` derive from a single choice:
`email → ["email"]`, `sms → ["phone"]`, `voter_choice → ["email","phone"]`.

Security level, shown as a WEAK/MID/STRONG meter:
`use2FA → STRONG`; else `credentials.length == 3 → MID`; else `WEAK`.

A census with **no** `authFields` and **no** `twoFaFields` identifies nobody and
must stay refused.

## 4c-bis. Two-factor voter flow

Observed against a 2FA election (`twoFaFields: ["email"]`). These override any
assumption drawn from the SDK documentation.

1. **`authStep0` needs the contact value as well as the credentials.** Credentials
   alone fail with `400 / 40005` — *"no contact information provided (email or
   phone)"*. So the voting page's auth form must also collect the channel value:
   `authStep0(pid, { memberNumber: "2001", email: "carol@example.org" })`.
   `["email"]` → ask email; `["phone"]` → ask phone; `["email","phone"]` → let the
   voter choose a channel, then ask for that one value.
2. **`check()` succeeds *before* the OTP.** A pending token still returns
   `belongsToProcess: true` and `canVote: true`. `check()` is therefore **not** an
   authentication gate — branch on `census.twoFaFields` from the public process
   read instead. An implementation that gates on `check()` skips 2FA entirely.
3. `authStep0` returns only `{ authToken }`; a pending token is indistinguishable
   from a verified one by shape.
4. Wrong OTP → `400 / 40001` *"challenge code do not match"*. The token survives,
   so the voter retries in place — never restart the flow or auto-resend.
5. `resend` requires the contact value: `resend(pid, { authToken, email })`. With
   only the token it fails `40001` *"invalid user email"*.
6. A right-credential / wrong-contact pair is rejected at step 0 with `40029`
   *"census participant not found"* — it does not disclose census membership, so
   show a generic "we could not identify you" rather than echoing the API.

Group validation failure (`POST …/groups/{id}/validate`) returns actionable data:
`{"error":"invalid data provided","code":40037,
  "data":{"missingData":["<memberId>",…],"duplicates":[],"notFound":[]}}`
Map `missingData` ids back to census members and name them in the admin error.

## 4d. Decisions taken, and why

1. **Question type is per question, not per process.** Each question is its own
   Vochain election and the voting page encodes a ballot per question, so the
   type belongs to the question. The admin may offer one control that sets every
   question at once, which is a convenience over the same data.
2. **A vote is never linked to a voter.** The census authenticates against the
   CSP, which returns a blind signature; the ballot is then cast with an
   ephemeral key generated in the browser and discarded. Decidim stores the
   census, never a vote.
3. **The tally is a cached read, and the chain is the record.** Every figure the
   admin and the public pages show comes from `results_cache`, refreshed by a
   background job. Anything that disagrees with the chain is a stale cache, not
   a different result.

## 5. Decidim conventions that apply

* Commands validate a form then `broadcast(:ok)` / `broadcast(:invalid)`.
* Forms carry validation; models stay thin.
* English is the source language; other locales come from translators.
* JS selectors use `id` with a `js-` prefix or `data-` attributes — never CSS classes.
* All UI must satisfy WCAG 2.1 AA and Decidim's own accessibility guide.
* Prefer vanilla JS. This module deliberately does **not** use the SDK's React layer.
