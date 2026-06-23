"""LINE Messaging API adapter."""

from __future__ import annotations

import os
import time
from datetime import UTC, datetime
from typing import Any

import httpx

from glc.channels.base import ChannelAdapter
from glc.channels.catalogue.line.schemas import (
    LineMessageEvent,
    LineOutboundTextMessage,
    LinePushPayload,
    LineReplyPayload,
    LineWebhook,
)
from glc.channels.envelope import ChannelMessage, ChannelReply, TrustLevel


class Adapter(ChannelAdapter):
    name = "line"
    _line_api_base = "https://api.line.me/v2/bot/message"

    def __init__(self, config: dict[str, Any] | None = None) -> None:
        super().__init__(config)
        self._reply_tokens: dict[str, tuple[str, float]] = {}

    async def on_message(self, raw: Any) -> ChannelMessage:
        mock = self.config.get("mock")
        if mock is not None and hasattr(mock, "pop_disconnect"):
            mock.pop_disconnect()

        webhook = LineWebhook.model_validate(raw)
        event = self._first_message_event(webhook)
        channel_user_id = self._channel_user_id(event)
        if event.reply_token is not None:
            self._store_reply_token(channel_user_id, event.reply_token)

        pairing_store = self._pairing_store()
        pairing = pairing_store.lookup(self.name, channel_user_id)
        trust_level = self._classify(channel_user_id)
        is_public_channel = bool(
            self.config.get("is_public_channel") or event.source.type in {"group", "room"}
        )
        was_mentioned = self._was_mentioned(event)

        metadata: dict[str, Any] = {
            "line_message_id": event.message.id,
            "line_source_type": event.source.type,
            "is_public_channel": is_public_channel,
            "was_mentioned": was_mentioned,
        }
        if event.reply_token is not None:
            metadata["line_reply_token_seen"] = True

        if is_public_channel:
            owners = [record.channel_user_id for record in pairing_store.owners(channel=self.name)]
            ok, reason = self._allowed(
                self.name,
                channel_user_id,
                owner_ids=owners,
                is_public_channel=True,
                was_mentioned=was_mentioned,
            )
            metadata["allowlist_allowed"] = ok
            if not ok:
                metadata["allowlist_reason"] = reason

        return ChannelMessage(
            channel=self.name,
            channel_user_id=channel_user_id,
            user_handle=pairing.user_handle if pairing is not None else channel_user_id,
            text=event.message.text if event.message.type == "text" else None,
            trust_level=trust_level,
            arrived_at=self._arrived_at(event),
            metadata=metadata,
        )

    async def send(self, reply: ChannelReply) -> Any:
        message = LineOutboundTextMessage(text=reply.text or "")
        reply_token = self._consume_reply_token(reply.channel_user_id)
        if reply_token is not None:
            body = LineReplyPayload(replyToken=reply_token, messages=[message]).model_dump(by_alias=True)
            endpoint = "reply"
        else:
            body = LinePushPayload(to=reply.channel_user_id, messages=[message]).model_dump(by_alias=True)
            endpoint = "push"

        mock = self.config.get("mock")
        if mock is not None:
            return await mock.send(body)

        token = self.config.get("channel_access_token") or os.getenv("LINE_CHANNEL_ACCESS_TOKEN")
        if not token:
            return body

        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                f"{self._line_api_base}/{endpoint}",
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                },
                json=body,
            )
        try:
            data: Any = response.json()
        except ValueError:
            data = {"message": response.text}
        if isinstance(data, dict):
            data.setdefault("status", response.status_code)
            return data
        return {"status": response.status_code, "body": data}

    @staticmethod
    def _first_message_event(webhook: LineWebhook) -> LineMessageEvent:
        for event in webhook.events:
            if event.type == "message":
                return event
        raise ValueError("LINE webhook did not contain a message event")

    @staticmethod
    def _channel_user_id(event: LineMessageEvent) -> str:
        channel_user_id = event.source.user_id or event.source.group_id or event.source.room_id
        if channel_user_id is None:
            raise ValueError("LINE event source did not include a user, group, or room id")
        return channel_user_id

    @staticmethod
    def _arrived_at(event: LineMessageEvent) -> datetime:
        if event.timestamp is None:
            return datetime.now(UTC)
        return datetime.fromtimestamp(event.timestamp / 1000, tz=UTC)

    def _store_reply_token(self, channel_user_id: str, token: str, ttl_s: float = 60.0) -> None:
        expires_at = time.time() + ttl_s
        self._reply_tokens[channel_user_id] = (token, expires_at)
        mock = self.config.get("mock")
        if mock is not None and hasattr(mock, "set_reply_token"):
            mock.set_reply_token(channel_user_id, token, ttl_s=ttl_s)

    def _consume_reply_token(self, channel_user_id: str) -> str | None:
        mock = self.config.get("mock")
        if mock is not None and hasattr(mock, "consume_reply_token"):
            return mock.consume_reply_token(channel_user_id)

        token_item = self._reply_tokens.pop(channel_user_id, None)
        if token_item is None:
            return None
        token, expires_at = token_item
        if expires_at < time.time():
            return None
        return token

    def _was_mentioned(self, event: LineMessageEvent) -> bool:
        if "was_mentioned" in self.config:
            return bool(self.config["was_mentioned"])

        bot_user_id = self.config.get("bot_user_id")
        if not bot_user_id or not event.message.mention:
            return False

        mentionees = event.message.mention.get("mentionees", [])
        return any(mentionee.get("userId") == bot_user_id for mentionee in mentionees)

    @staticmethod
    def _pairing_store() -> Any:
        from glc.security.pairing import get_pairing_store

        return get_pairing_store()

    def _classify(self, channel_user_id: str) -> TrustLevel:
        from glc.security.trust_level import classify

        return classify(self.name, channel_user_id)

    @staticmethod
    def _allowed(*args: Any, **kwargs: Any) -> tuple[bool, str]:
        from glc.security.allowlists import allowed

        return allowed(*args, **kwargs)
