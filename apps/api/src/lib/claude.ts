// One place for pipeline calls to Claude: a typed JSON answer, and a small worker pool.
import Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import type { z } from "zod";
import { config } from "../config";

export const HAIKU = "claude-haiku-5-5";
export const SONNET = "claude-sonnet-5-5";

let client: Anthropic | null = null;

/** Asks for an answer in the given shape. Throws if Claude declines or the answer does not fit. */
export async function askJson<T extends z.ZodType>(model: string, system: string, user: string, schema: T, opts?: { timeout?: number; maxRetries?: number }): Promise<z.infer<T>> {
  if (!config.anthropicKey) throw new Error("ANTHROPIC_API_KEY is not set.");
  client ??= new Anthropic({ apiKey: config.anthropicKey, maxRetries: 4 });
  const r = await client.messages.parse({
    model, max_tokens: 16000, system,
    messages: [{ role: "user", content: user }],
    output_config: { effort: "low", format: zodOutputFormat(schema) },
  }, opts);
  if (r.stop_reason !== "end_turn" || !r.parsed_output) throw new Error(`Claude stopped with ${r.stop_reason}`);
  return r.parsed_output;
}

/** Runs fn over items, a few at a time. A failed item is reported and skipped, so a rerun picks it up. */
export async function pool<T>(items: T[], size: number, fn: (item: T, index: number) => Promise<void>): Promise<number> {
  let next = 0, failed = 0;
  await Promise.all(Array.from({ length: size }, async () => {
    while (next < items.length) {
      const i = next++;
      try { await fn(items[i], i); } catch (e) { failed++; console.error(`  item ${i} failed: ${(e as Error).message}`); }
    }
  }));
  return failed;
}

export const chunks = <T>(items: T[], n: number): T[][] =>
  Array.from({ length: Math.ceil(items.length / n) }, (_, i) => items.slice(i * n, i * n + n));
