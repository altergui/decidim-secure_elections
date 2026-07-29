# Security policy

`decidim-secure_elections` runs elections. A vulnerability here can cost somebody their
vote or their ballot secrecy, so please report one privately rather than in a
public issue.

## Reporting a vulnerability

**Do not open a public issue.** Use either of:

1. [GitHub's private vulnerability reporting][advisories] on this repository
   (Security → Report a vulnerability).
2. Email **security@vocdoni.io**.

Please include the affected version, what an attacker can do, and the smallest
reproduction you have. You will get an acknowledgement within three working
days and an assessment within ten.

If the issue is in Decidim itself rather than in this module, report it to
[Decidim's security team](https://github.com/decidim/decidim/blob/develop/SECURITY.md)
instead. If it is in the Vocdoni protocol or the SaaS API, report it to
[Vocdoni](https://github.com/vocdoni/vocdoni-node/security).

## Supported versions

The latest minor release receives security fixes.

| Version | Supported          |
|---------|--------------------|
| 0.1.x   | :white_check_mark: |

## What this module's threat model assumes

These are the properties the design is meant to guarantee. A report that any of
them does not hold is a security issue, not a bug report.

- **The integrator API key never reaches a browser.** It is read server-side
  only, from Rails encrypted credentials or the environment, and is used only
  for organiser operations. The voter path uses public and CSP-token routes
  exclusively.
- **Decidim never sees a ballot.** Ballots are encoded, signed and submitted by
  the voter's browser directly to the Vocdoni API. The Rails application has no
  route that accepts one.
- **A voter's identity is never linked to their vote.** Census credentials
  authenticate against the CSP, which returns a blind signature; the vote is
  cast with an ephemeral key generated in the browser and discarded.
- **Nothing from the voting session is persisted in the browser.** No auth
  token, one-time code or ballot is written to storage, a cookie, the URL or a
  session. This is enforced by lint rules in CI.
- **Census data is personal data.** Names, emails, phone numbers and national
  IDs entered into a census are stored in the host application's database and
  sent to the Vocdoni API to build the census. Operators are responsible for the
  lawful basis and retention; the module does not delete them for you.

## Known limitations

- The module trusts the Vocdoni SaaS API it is configured against. An operator
  who points `VOCDONI_API_URL` at a host they do not control has no protection
  from this module.
- Results shown in Decidim are a cached read of the tally. The chain, not
  Decidim, is the record.

[advisories]: https://github.com/vocdoni/decidim-secure_elections/security/advisories/new
