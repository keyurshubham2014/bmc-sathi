// Writes a short plain-language summary for every ward and contractor, in English and Marathi.
// A summary is rewritten only when the figures behind it have changed (facts_hash).
import { z } from "zod";
import { askJson, pool, SONNET } from "../lib/claude";
import { db } from "../lib/db";
import { factsHash } from "../modules/ask";

const SYSTEM = `You write a short summary of road repair spending for a Mumbai ward or a contractor, for a public dashboard read by ward staff, auditors and citizens.
Use only the JSON facts given. Write two or three plain sentences, at most 60 words, saying what a reader should notice first: for a ward, where it stands against its budget and where the largest amounts in question are; for a contractor, how speed, durability and cost compare with similar jobs.
Rates in the facts are fractions: write them as percentages. Write rupee amounts in lakh or crore (for example ₹63.2 lakh), not as long numbers.
The audit rules have already decided what is flagged. A flag or a gap from similar jobs is a reason to look, not proof of wrongdoing: do not accuse, rank or grade anyone, and do not guess at causes the facts do not show.
Return the same summary twice: "en" in English and "mr" in natural Marathi (Devanagari), keeping names of wards, roads and contractors as given.`;
const Answer = z.object({ en: z.string(), mr: z.string() });

const subjects = [
  ...(await db.ward.findMany({ select: { ward_code: true } })).map((w) => ({ type: "ward" as const, id: w.ward_code })),
  ...(await db.contractor.findMany({ select: { contractor_id: true } })).map((c) => ({ type: "contractor" as const, id: c.contractor_id })),
];
let written = 0, unchanged = 0;
const failed = await pool(subjects, 4, async (s) => {
  // The citizen view of the facts: summaries are shown to every role.
  const { facts, hash: facts_hash } = await factsHash(s.type, s.id);
  const have = await db.summary.findMany({ where: { subject_type: s.type, subject_id: s.id } });
  if (have.length === 2 && have.every((h) => h.facts_hash === facts_hash)) return void unchanged++;
  const out = await askJson(SONNET, SYSTEM, facts, Answer);
  for (const lang of ["en", "mr"] as const) {
    const data = { body: out[lang].trim(), facts_hash, generated_at: new Date() };
    await db.summary.upsert({
      where: { subject_type_subject_id_lang: { subject_type: s.type, subject_id: s.id, lang } },
      update: data, create: { subject_type: s.type, subject_id: s.id, lang, ...data },
    });
  }
  written++;
});
console.log(`summaries: ${written} written, ${unchanged} unchanged, ${failed} failed`);
await db.$disconnect();
