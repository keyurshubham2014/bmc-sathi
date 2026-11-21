# Master Index

**Project:** BMC Sathi (Module 1: Roads)
**Version:** 1.0
**Last Updated:** 2026-11-21
**Status:** Draft

BMC Sathi shows where each Mumbai ward's road repair money went, whether the repairs lasted, and where the next rupee should go. This is a lean specification for a same-day build of 6 to 10 hours.

## Documents

| # | Document | Read it for |
|---|---|---|
| | [PRD](../PRD-bmc-sathi.md) | Scope, roles, features F1 to F7, design character, demo script, cut list |
| 01 | [Project Overview & Architecture](./01-project-overview.md) | System shape, technology, repository layout, configuration, security, testing, build order |
| 04 | [Database Design](./04-database-design.md) | Tables, the views that compute flags, scorecards and the plan, and how issues are derived |
| 03 | [Backend Specification](./03-backend-spec.md) | API routes, roles, errors, the Claude pipeline, the Ask endpoint |
| 02 | [Frontend Specification](./02-frontend-spec.md) | Routes, layouts, each screen, state, theme, language |

Read in the order listed: the database defines the rules, the backend exposes them, the frontend shows them.

## Not written as separate documents

Folded into the documents above to fit the build window.

| Topic | Where it is |
|---|---|
| Security | [01 §7](./01-project-overview.md#7-security), [03 §3](./03-backend-spec.md#3-authentication-and-roles) |
| Testing | [01 §8](./01-project-overview.md#8-testing) |
| Hosting and environments | [01 §6](./01-project-overview.md#6-environments-and-configuration) |
| Build order and cut list | [01 §10](./01-project-overview.md#10-build-order), PRD §11 |

## Numbers the build must reproduce

From the supplied data, checked by the `verify` script.

| Figure | Value |
|---|---|
| Work orders | 2,499 |
| City spend | ₹13.43 crore |
| Over-billed flags (above 1.5x) | 109 |
| Possible double-billing flags | 45 |
| Billed under DLP | 493 jobs, ₹2.62 crore |
| Watch tier (1.3x to 1.5x) | 5 |
| Wards over budget | 6 |
| Complaints | 6,501, of which 896 open or in progress |

## Open items

| Item | Owner |
|---|---|
| Judges' answer key is unpublished; thresholds are inferred and adjustable in `setting` | Keyur |
| Palette values need the contrast test to pass before they are final | Build |
| Anthropic SDK request details to be confirmed against current documentation | Build |
| Local Postgres fallback to be restored and tried before the demo | Keyur |

## Version History

| Version | Date | Author | Changes |
|---|---|---|---|
| 1.0 | 2026-11-21 | Keyur Patel with Claude | Initial draft |
