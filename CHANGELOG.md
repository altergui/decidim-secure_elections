# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the module follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0]

First release. Compatible with Decidim `0.33.x`.

The Ruby namespace is `Decidim::SecureElections`. `vocdoni` is kept wherever the
thing named belongs to the Vocdoni network rather than to this module — the
database tables and columns, the `VOCDONI_*` environment variables, the
`:vocdoni` component manifest, the `/vocdoni/vote.html` voting page URL and the
`.vocdoni-*` CSS classes. See the README's "A note on two names".

### Added

- **Secure elections component** for participatory spaces, with an admin setup
  wizard (details → questions → census → schedule → publish on chain) and a
  live monitoring page. The wizard is strictly ordered — a step only opens once
  every step before it is complete, enforced in the navigation, in the
  controllers and in the permission class — and every content step stays
  reachable, read-only, once the election is on chain.
- **Questions and their options on one screen**, added, removed and reordered
  without a page reload and saved in a single submit, with draft autosave on
  the details and the ballot steps.
- **Ruby client for the Vocdoni SaaS API** (`Decidim::SecureElections::ApiClient`),
  covering processes, organizations, censuses and async jobs. There is **no
  Node.js runtime on the server** — the client talks HTTPS from Ruby.
- **In-browser voting page**: census authentication, optional one-time code,
  ephemeral key generation, ballot encoding, vote signing and relay all happen
  in the voter's browser, against the Vocdoni API. The Decidim server never
  sees a ballot and never holds a voting key. It is served at
  `/vocdoni/vote.html?v=<packed>`; `v` packs the API base, the process id and
  the optional locale and return path into one short value. That is an
  abbreviation and not a secret — everything in it is public — and the
  spelled-out `?api=…&process=…` form is still accepted, as is the address the
  page used to have (`/vocdoni/booth.html`, now a redirect).
- **Two voting links in the admin panel**: the election page, which carries the
  election's description, dates and results, and the direct link, which opens
  the ballot straight away. The direct one is what an organiser emails.
- **Background jobs** for every write to the API — `PublishElectionJob`,
  `SetQuestionStatusJob` and `SyncResultsJob`. No web request ever calls the
  SaaS API inline; the public page polls a cached, Decidim-local endpoint.
- **Results export** (`election_results`, CSV/JSON/Excel, included in the open
  data export) carrying the on-chain identifiers — the process id and each
  question's Vochain election id — so an exported tally can be verified
  independently on the Vocdoni explorer.
- **GraphQL API**: `VocdoniElections` component type with `election`/`elections`
  queries and `VocdoniElection`, `VocdoniQuestion` and `VocdoniAnswer` types.
  Census configuration and module credentials are not exposed.
- **Notification events** `Decidim::SecureElections::ElectionPublishedEvent` and
  `Decidim::SecureElections::ElectionResultsPublishedEvent`.
- **Seeds** that create local draft elections only, so `rake db:seed` works
  offline and without Vocdoni credentials.
- **Reference deployment** under `docker/` (Dockerfile and compose file with a
  mandatory background worker).

### Security

- The integrator API key is server-side only and is never sent to the browser;
  the voter path uses only public and CSP-token routes.
- `Decidim::SecureElections.validate_configuration!` raises on an incomplete
  configuration instead of falling back to a default (test) chain.
- An election with no census authentication field identifies nobody, and
  publishing one would enfranchise every member of the organization. It is
  refused by the form, by the model and again by the publish job before any
  request is made.
- The voting page talks only to an API on an allowed origin: one of the Vocdoni
  SaaS bases it ships with, its own origin, or loopback. This is what keeps a
  hand-crafted link on the installation's own domain from turning the census
  form into a credential collector.
- Nothing from a voting session is written to storage, a cookie, the URL or a
  session — no auth token, no one-time code, no ballot. Lint rules enforce it.

[0.1.0]: https://github.com/vocdoni/decidim-secure_elections/releases/tag/v0.1.0
