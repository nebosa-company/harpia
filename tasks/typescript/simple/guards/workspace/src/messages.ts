/**
 * Wire messages.
 *
 * The four shapes below are settled. The helpers under them are
 * placeholders: they compile, but they hand back plain booleans and
 * `void`, so nothing downstream is narrowed.
 */
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

export type MessageOfKind<K extends MessageKind> = Message;

export const MESSAGE_KINDS: readonly MessageKind[] = [];

export function isMessage(value: unknown): boolean {
  void value;
  throw new Error("isMessage is not implemented");
}

export function isMessageOfKind(value: unknown, kind: MessageKind): boolean {
  void value;
  void kind;
  throw new Error("isMessageOfKind is not implemented");
}

export function assertMessage(value: unknown): void {
  void value;
  throw new Error("assertMessage is not implemented");
}

export function assertMessageOfKind(value: unknown, kind: MessageKind): void {
  void value;
  void kind;
  throw new Error("assertMessageOfKind is not implemented");
}

export function describe(message: Message): string {
  void message;
  throw new Error("describe is not implemented");
}
