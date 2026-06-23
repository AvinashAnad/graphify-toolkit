# LINE Messaging API

This is a **group assignment** in Session 11. Implement the line adapter
to make the test suite at `tests/channels/test_line.py` pass.

## What you build

Two files under this directory:

- `adapter.py` — subclass `glc.channels.base.ChannelAdapter` and implement
  `on_message(raw) -> ChannelMessage` and `send(reply) -> Any`.
- `schemas.py` — any channel-specific Pydantic types you need.

## Required environment variables

- `LINE_CHANNEL_ACCESS_TOKEN`
- `LINE_CHANNEL_SECRET`

## Free-tier limits

Developer trial: 500 free push messages/month; reply messages within the 1-hour reply token are unlimited.

## Wire-format quirks to expect

Reply tokens are one-shot and expire fast — push messages cost against the monthly quota. Signed webhook validation uses the channel secret.

## Group 10 architecture note

This adapter translates LINE webhook `message` events into the canonical
`ChannelMessage` envelope and translates `ChannelReply` back to LINE text
message payloads. Inbound messages are parsed with LINE-specific Pydantic
schemas, classified through `glc.security.trust_level.classify()`, and
annotated with metadata for public-channel allowlist checks.

The main LINE quirk is the `replyToken`: it is one-shot, short-lived, and
should be preferred over push messages because push counts against the free
monthly quota. The adapter stores the token on inbound events, sends the
first outbound reply through the reply endpoint payload
`{replyToken, messages}`, and falls back to push payloads `{to, messages}`
when no token is available.

The tests exercise both translation directions and the trust boundary:
owner and stranger webhooks produce the expected trust levels, public-channel
stranger input records the allowlist decision, rate-limit responses propagate
as 429s, and the LINE-specific smoke test proves reply-token-first then push
fallback behavior against `tests/channels/mocks/line_mock.py`.

## Tests you need to pass

The failing tests live at `tests/channels/test_line.py`. They cover:

1. `on_message` builds a valid `ChannelMessage` for owner and stranger inputs.
2. Trust level resolves to `owner_paired` / `user_paired` / `untrusted` correctly.
3. `send` produces a valid wire-format payload and reaches the mock.
4. The adapter handles forced disconnects without raising.
5. Rate-limit responses propagate to the caller as a 429.
6. In public channels with the default `mention_only_in_public: true`, the
   adapter consults the allowlist before processing strangers.

The mock-API fake at `tests/channels/mocks/line_mock.py` is your contract
surface. Do **not** edit the mock or the test file — they are fixed.

## Submission

Open a PR that:

- Adds your `adapter.py` and `schemas.py`.
- Passes `pytest tests/channels/test_line.py`.
- Updates `CLAIMS.md` if you have not already claimed this channel.

CI gates merge through branch protection. A TA reviews before merge.
