"""LINE Messaging API wire-format types used by the adapter.

The canonical gateway envelope lives in :mod:`glc.channels.envelope`;
these models cover only the LINE-specific inbound webhook and outbound
message payload shapes.
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class LineSource(BaseModel):
    type: str
    user_id: str | None = Field(default=None, alias="userId")
    group_id: str | None = Field(default=None, alias="groupId")
    room_id: str | None = Field(default=None, alias="roomId")

    model_config = ConfigDict(extra="allow", populate_by_name=True)


class LineMessageObject(BaseModel):
    id: str
    type: str
    text: str | None = None
    mention: dict | None = None

    model_config = ConfigDict(extra="allow")


class LineMessageEvent(BaseModel):
    type: str
    timestamp: int | None = None
    source: LineSource
    reply_token: str | None = Field(default=None, alias="replyToken")
    message: LineMessageObject

    model_config = ConfigDict(extra="allow", populate_by_name=True)


class LineWebhook(BaseModel):
    destination: str | None = None
    events: list[LineMessageEvent] = Field(default_factory=list)

    model_config = ConfigDict(extra="allow")


class LineOutboundTextMessage(BaseModel):
    type: Literal["text"] = "text"
    text: str

    model_config = ConfigDict(extra="forbid")


class LineReplyPayload(BaseModel):
    reply_token: str = Field(alias="replyToken")
    messages: list[LineOutboundTextMessage]

    model_config = ConfigDict(extra="forbid", populate_by_name=True)


class LinePushPayload(BaseModel):
    to: str
    messages: list[LineOutboundTextMessage]

    model_config = ConfigDict(extra="forbid")
