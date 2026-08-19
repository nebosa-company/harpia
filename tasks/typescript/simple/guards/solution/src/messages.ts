/** Wire messages, plus the guards that turn `unknown` into one of them. */
export interface PingMessage {
  kind: "ping";
  nonce: number;
}

export interface ChatMessage {
  kind: "chat";
  from: string;
  body: string;
}

export interface JoinMessage {
  kind: "join";
  room: string;
  members: string[];
}

export interface ErrorMessage {
  kind: "error";
  code: number;
  detail?: string;
}

export type Message = PingMessage | ChatMessage | JoinMessage | ErrorMessage;

export type MessageKind = Message["kind"];

export type MessageOfKind<K extends MessageKind> = Extract<Message, { kind: K }>;

export const MESSAGE_KINDS: readonly MessageKind[] = ["ping", "chat", "join", "error"];

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const isNonEmptyString = (value: unknown): value is string =>
  typeof value === "string" && value.length > 0;

export function isMessage(value: unknown): value is Message {
  if (!isRecord(value)) return false;
  switch (value["kind"]) {
    case "ping":
      return typeof value["nonce"] === "number" && Number.isFinite(value["nonce"]);
    case "chat":
      return isNonEmptyString(value["from"]) && typeof value["body"] === "string";
    case "join": {
      const members = value["members"];
      return (
        isNonEmptyString(value["room"]) &&
        Array.isArray(members) &&
        members.every((m) => typeof m === "string")
      );
    }
    case "error": {
      const detail = value["detail"];
      return (
        typeof value["code"] === "number" &&
        Number.isInteger(value["code"]) &&
        (detail === undefined || typeof detail === "string")
      );
    }
    default:
      return false;
  }
}

export function isMessageOfKind<K extends MessageKind>(
  value: unknown,
  kind: K,
): value is MessageOfKind<K> {
  return isMessage(value) && value.kind === kind;
}

export function assertMessage(value: unknown): asserts value is Message {
  if (!isMessage(value)) {
    throw new TypeError("invalid message");
  }
}

export function assertMessageOfKind<K extends MessageKind>(
  value: unknown,
  kind: K,
): asserts value is MessageOfKind<K> {
  if (!isMessageOfKind(value, kind)) {
    throw new TypeError(`expected message kind "${kind}"`);
  }
}

function unreachable(value: never): never {
  throw new Error("unhandled message: " + JSON.stringify(value));
}

export function describe(message: Message): string {
  switch (message.kind) {
    case "ping":
      return `ping #${message.nonce}`;
    case "chat":
      return `${message.from}: ${message.body}`;
    case "join":
      return `${message.room} (${message.members.length} members)`;
    case "error":
      return message.detail === undefined
        ? `error ${message.code}`
        : `error ${message.code}: ${message.detail}`;
    default:
      return unreachable(message);
  }
}
