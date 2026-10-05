# greeter — PRD

## Problem Statement

Teams building services on this platform need a small, known-good reference
service to validate platform conventions (project layout, build/verify steps,
API contracts) against. Without one, each new service has to rediscover those
conventions from scratch.

## Solution

Greeter is a minimal Go HTTP service that returns a JSON greeting for a given
name. It exists to demonstrate and validate the platform's conventions for a
plain backend service, following the patterns in `app-factory-kaj/e2e-reference`.

## Actors

- **API Caller** — another internal service or a developer integrating
against the platform, calling greeter programmatically to get a greeting or
to validate the platform's service conventions. *assumed*

## User Stories

1. As an API Caller, I want to GET /hello with a `name` query parameter, so
 that I receive a JSON greeting addressed to that name.
2. As an API Caller, I want GET /hello to still succeed with a sensible
 default greeting when I omit the `name` parameter, so that the endpoint
 never fails on missing input.

## Product Decisions

- Follows the conventions established in `app-factory-kaj/e2e-reference` for
project layout and service structure.
- GET /hello is an open, unauthenticated endpoint — no sign-in is required to
call it. *assumed*
- When `name` is missing or empty, the service returns a generic greeting
(e.g. "Hello, World!") rather than an error. *assumed*
- No external services or persistence are required; greeter is stateless.

## Out of Scope

- No user interface — greeter is an API-only service.
- No persistence or storage of any kind.
- No authentication, authorization, or per-caller rate limiting.
- No support for greetings in multiple languages or formats beyond a single
JSON greeting message.

## Open Questions

None at this time.

## Further Notes

Project layout and build/verify conventions should follow
`app-factory-kaj/e2e-reference`; this is an engineering-level concern to be
carried into the design, not a product decision.