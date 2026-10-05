# Greeter — Edge Cases, Failure Modes &amp; Test Ideas

This document reviews every endpoint and schema in `openapi.yaml` for the
boundary conditions, failure modes, and concrete test ideas the build and its
tests should account for. It is a review artifact, not a contract change.

## Endpoint: `GET /hello`

Edge cases center on the shape and encoding of the `name` query parameter and
on how the handler reacts when that parameter is absent, empty, overlong,
non-ASCII, or adversarial. A missing `name` key and a present-but-empty
`name=` must both resolve to the same generic greeting per the PRD, so a test
should assert both paths independently rather than assuming one implies the
other; a parameter supplied only with whitespace (`name=%20%20`) is an
additional boundary the PRD does not explicitly settle and should be treated
as "empty" rather than greeted as literal whitespace. Overlong input (a
multi-kilobyte or multi-megabyte `name` value) is a denial-of-service and
resource-exhaustion concern since the service has no documented request-size
limit — a test should confirm the server either rejects or safely truncates
rather than allocating unbounded memory or crashing. Values containing HTML,
script tags, or JSON-breaking characters (`"`, `\`, newlines, null bytes) must
be safely encoded into the JSON response body rather than corrupting the
JSON structure or enabling injection in a downstream consumer that renders
`message` as HTML; a test should round-trip a name like `Robert"); DROP TABLE--` and confirm the response remains valid, parseable JSON. Unicode and
emoji names (e.g. "明", "🎉") exercise encoding correctness end-to-end
(URL-decoding, UTF-8 handling, JSON string escaping) and should be included
as a positive test, not just an edge case, since the service is advertised as
general-purpose. Repeated `name` query parameters (`?name=A&name=B`) are
undefined by the spec and the handler's behavior (first wins, last wins, or
400) should be pinned down by a test so it is deterministic rather than an
artifact of the underlying Go query-parsing library's default. Finally, the
endpoint should be tested under wrong HTTP methods (`POST /hello`, `PUT /hello`) and under a request with an unexpected body or unexpected headers
(e.g. `Content-Type: application/json` on a GET) to confirm the service
either ignores extraneous input gracefully or returns a clean 404/405 rather
than a 500.

Failure modes to test deliberately include: the handler panicking on nil or
malformed query-string parsing and whether that panic is recovered into a
clean JSON 5xx `Error` body rather than crashing the process or leaking a Go
stack trace to the caller; the server's behavior under malformed percent-
encoding in the query string (`?name=%zz`) which a naive decoder may reject
with a low-level parse error rather than the service's own `Error` shape;
and the service's behavior when the `name` parameter is supplied as an
array-like bracket syntax (`name[]=X`) which some frameworks parse
differently than a bare string, potentially producing an unexpected type
error. Concurrency/load is also a failure mode worth a test idea: a burst of
simultaneous requests should not cause shared-state corruption (the service
should have none, but this is the test that verifies statelessness is real,
not just asserted) and should not cause goroutine leaks or unbounded
connection growth under sustained concurrent load.

## Endpoint: `GET /health`

The primary edge cases are less about input (health takes none) and more
about what "healthy" means and when the endpoint might legitimately diverge
from a simple constant. A test should confirm the endpoint always returns
`200` with `status` populated even immediately after process startup (no
false negative during a brief warm-up window) and should confirm the
response shape remains stable under concurrent load alongside `/hello`
traffic, since a shared router misconfiguration could cause health checks to
queue behind slow greeting requests and start timing out under load — a
load test that measures `/health` latency while `/hello` is saturated is a
good test idea given this is a reference service meant to validate platform
conventions like readiness/liveness probing. A failure mode worth testing
explicitly is what the platform's orchestrator sees if the process is
mid-shutdown (SIGTERM received): the health check should ideally flip to a
non-200 status during graceful drain rather than reporting healthy while
refusing new connections, and a test should drive a shutdown signal and
assert the health endpoint's behavior during that window rather than only
testing the steady-state case. Wrong-method and unexpected-header tests
(`POST /health`, `HEAD /health`) mirror `/hello` and should confirm clean
404/405 behavior rather than a 500.

## Schema: `Greeting`

The schema's edge cases are mostly about the optional/nullable `name` field
and its relationship to `message`. A test should assert that when `name` was
omitted or empty in the request, the response's `name` field is either
absent or explicitly `null` (the schema marks it `nullable`, so the handler
must not silently coerce it to an empty string — a test should pin down
exactly which of the two the implementation does, since schema-level
"nullable" and "absent" are different wire shapes and a strict consumer
could reject one or the other). Another edge case is whether `message` ever
echoes unescaped user input verbatim in a way that could break a consumer
expecting plain text — a test should assert `message` is well-formed UTF-8
JSON text regardless of what was supplied as `name`, including names at the
boundary of valid UTF-8 (malformed byte sequences in the raw query string)
where the server must not produce invalid JSON or crash the encoder. A
fuzz-style test idea generating random Unicode, control characters, and
very long strings as `name` and asserting the response always parses as
valid JSON against this schema would give strong coverage here. Finally, a
contract test should confirm the schema's `required: [message]` is honored
under every code path — including any future error-recovery path that might
accidentally return a partial object — so that no caller ever receives a
`Greeting` object missing `message`.

## Schema: `Health`

The only required field is `status`, so the key edge case is whether its
value is a stable, documented enumeration (e.g. always exactly `"UP"` or
`"ok"`) or an open string that could vary across deploys — since the schema
leaves this as an undescribed free-form string, a test should assert the
exact literal value the implementation commits to, so that any future change
to that literal is caught as a breaking change for monitoring dashboards or
orchestrator probes that may pattern-match on it. A secondary test idea is
confirming the `Health` object never includes extra undocumented fields that
a strict consumer-side schema validator would reject, and that the object
is returned with a stable `Content-Type: application/json` header so
automated health-check tooling can parse it reliably.

## Schema: `Error`

This schema is referenced by neither operation's `responses` block today,
which is itself worth flagging as a design gap: without an explicit error
response entry, it is undocumented whether `/hello` or `/health` ever
actually return this shape (for a 4xx/5xx), or whether failures surface as a
bare framework-default error page instead. A test idea is to deliberately
provoke every failure mode enumerated above (oversized input, wrong method,
malformed query encoding, mid-shutdown health check) and assert that
whatever error body is returned conforms to this `Error` schema — code,
message, and optionally description/moreInfo — rather than leaking a raw Go
panic trace, a framework's default HTML error page, or an empty body. Edge
cases within the schema itself include: whether `code` is an HTTP status
code, an internal application error code, or conflated use of both inconsist-
ently across endpoints (a test should assert a single, documented
convention); whether `message` is safe to display to an end user versus
being an internal diagnostic string that should not leak implementation
details (e.g. file paths, stack frames) to an external caller; and whether
`moreInfo`, when present, is ever an untrusted or user-influenced URL that
a consumer might automatically follow, which would be a minor but real
concern if any input ever flows into that field. Given the schema is defined
but currently orphaned from both operations' `responses`, resolving that gap
— wiring `Error` into explicit `4xx`/`5xx` response entries for both
endpoints — is itself a recommended follow-up to this review.