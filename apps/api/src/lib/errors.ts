import { z } from "zod";

const STATUS = {
  validation_failed: 400, not_signed_in: 401, not_allowed: 403, not_found: 404,
  conflict: 409, too_many_requests: 429, assistant_unavailable: 502, server_error: 500,
} as const;
export type ErrorCode = keyof typeof STATUS;

export class AppError extends Error {
  status: number;
  constructor(public code: ErrorCode, message: string, public fields?: { field: string; message: string }[]) {
    super(message);
    this.status = STATUS[code];
  }
}

/** Validates input against a schema. Unknown keys are dropped. Throws validation_failed. */
export function parse<T extends z.ZodType>(schema: T, data: unknown): z.infer<T> {
  const r = schema.safeParse(data);
  if (r.success) return r.data;
  throw new AppError("validation_failed", "Some fields are not valid.",
    r.error.issues.map((i) => ({ field: i.path.join("."), message: i.message })));
}

/** Shared list paging: limit (default 50, max 200) and offset. */
export const paging = {
  limit: z.coerce.number().int().min(1).max(200).default(50),
  offset: z.coerce.number().int().min(0).default(0),
};
