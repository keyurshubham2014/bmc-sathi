// Proves the role rules and the flag workflow against the loaded database.
import request from "supertest";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { app } from "../src/app";
import { db } from "../src/lib/db";

const api = () => request(app);
const tokens: Record<string, string> = {};
const as = (who: string) => ({ Authorization: `Bearer ${tokens[who]}` });
let touched: { flag_type: string; work_order_id: string } | null = null;

beforeAll(async () => {
  for (const u of ["auditor", "officer.e", "citizen"]) {
    const r = await api().post("/api/v1/auth/login").send({ username: u, password: process.env.DEMO_PASSWORD });
    expect(r.status).toBe(200);
    tokens[u] = r.body.token;
  }
});
afterAll(async () => {
  if (touched) await db.flag_decision.deleteMany({ where: touched });
  await db.$disconnect();
});

describe("auth", () => {
  it("rejects a wrong password", async () => {
    const r = await api().post("/api/v1/auth/login").send({ username: "auditor", password: "nope" });
    expect(r.status).toBe(401);
    expect(r.body.code).toBe("not_signed_in");
  });
  it("rejects a missing token", async () => {
    expect((await api().get("/api/v1/wards")).status).toBe(401);
  });
  it("lets every role read wards, highest spend share first", async () => {
    const r = await api().get("/api/v1/wards").set(as("citizen"));
    expect(r.body.items).toHaveLength(24);
    expect(r.body.items[0].ward_code).toBe("E");
    expect(r.body.items.filter((w: any) => w.spend_share > 1)).toHaveLength(6);
  });
});

describe("flags", () => {
  it("refuses the queue to citizens", async () => {
    const r = await api().get("/api/v1/flags").set(as("citizen"));
    expect(r.status).toBe(403);
    expect(r.body.code).toBe("not_allowed");
  });
  it("shows the reference counts to the auditor", async () => {
    const count = async (q: string) => (await api().get(`/api/v1/flags?limit=1&${q}`).set(as("auditor"))).body.total;
    expect(await count("type=overbilled")).toBe(109);
    expect(await count("type=duplicate")).toBe(45);
    expect(await count("type=dlp")).toBe(493);
    expect(await count("tier=watch")).toBe(5);
  });
  it("limits a ward officer to their ward", async () => {
    const own = await api().get("/api/v1/flags?limit=200").set(as("officer.e"));
    expect(own.body.items.length).toBeGreaterThan(0);
    expect(own.body.items.every((f: any) => f.ward_code === "E")).toBe(true);
    expect((await api().get("/api/v1/flags?ward_code=L").set(as("officer.e"))).status).toBe(403);
  });
  it("shows both work orders for a double-billing flag", async () => {
    const list = await api().get("/api/v1/flags?type=duplicate&limit=1").set(as("auditor"));
    const f = list.body.items[0];
    const r = await api().get(`/api/v1/flags/duplicate/${f.work_order_id}`).set(as("auditor"));
    expect(r.body.work_order.has_complaint).toBe(false);
    expect(r.body.earlier_work_order.road_id).toBe(r.body.work_order.road_id);
    expect(r.body.earlier_work_order.contractor_id).toBe(r.body.work_order.contractor_id);
  });
  it("records a decision that persists", async () => {
    const f = (await api().get("/api/v1/flags?type=duplicate&decision=open&limit=1").set(as("auditor"))).body.items[0];
    touched = { flag_type: "duplicate", work_order_id: f.work_order_id };
    const put = await api().put(`/api/v1/flags/duplicate/${f.work_order_id}/decision`).set(as("auditor"))
      .send({ decision: "needs_explanation", note: "Please share site photos." });
    expect(put.status).toBe(200);
    const again = await api().get(`/api/v1/flags/duplicate/${f.work_order_id}`).set(as("auditor"));
    expect(again.body.flag.decision).toBe("needs_explanation");
    expect(again.body.flag.decided_by_name).toBe("City Auditor");
  });
  it("refuses a decision on a watch item and an invalid decision", async () => {
    const w = (await api().get("/api/v1/flags?tier=watch&limit=1").set(as("auditor"))).body.items[0];
    const r = await api().put(`/api/v1/flags/overbilled/${w.work_order_id}/decision`).set(as("auditor")).send({ decision: "confirmed" });
    expect(r.status).toBe(409);
    const bad = await api().put(`/api/v1/flags/overbilled/${w.work_order_id}/decision`).set(as("auditor")).send({ decision: "guilty" });
    expect(bad.status).toBe(400);
  });
});

describe("ward money", () => {
  it("drill-down totals match the tile", async () => {
    const ward = (await api().get("/api/v1/wards/E").set(as("auditor"))).body.ward;
    const list = await api().get("/api/v1/wards/E/work-orders?filter=reopened&limit=1").set(as("auditor"));
    expect(list.body.total_cost).toBe(ward.reopened_spend);
    expect(list.body.total).toBe(ward.reopened_jobs);
  });
  it("breakdown adds up to ward spend", async () => {
    const ward = (await api().get("/api/v1/wards/E").set(as("auditor"))).body.ward;
    for (const d of ["contractor", "method", "week"]) {
      const b = await api().get(`/api/v1/wards/E/breakdown?dimension=${d}`).set(as("auditor"));
      expect(b.body.items.reduce((s: number, x: any) => s + x.spend, 0)).toBe(ward.spend);
    }
  });
  it("returns 404 for an unknown ward", async () => {
    expect((await api().get("/api/v1/wards/ZZ").set(as("auditor"))).status).toBe(404);
  });
});

describe("scorecards", () => {
  it("lists contractors in name order with no score", async () => {
    const r = await api().get("/api/v1/contractors").set(as("citizen"));
    const names = r.body.items.map((c: any) => c.contractor_name);
    expect(names).toHaveLength(8);
    expect(names).toEqual([...names].sort());
    expect(Object.keys(r.body.items[0])).not.toContain("band");
  });
  it("compares a contractor with similar jobs", async () => {
    const s = (await api().get("/api/v1/contractors/CT03").set(as("citizen"))).body.scorecard;
    expect(s.measures.durability.observed).toBeCloseTo(0.376, 2);
    expect(s.measures.durability.expected).toBeLessThan(s.measures.durability.observed);
    expect(s.measures.durability.band).toBe("well_below");
    expect(s.measures.cost.band).toBe("review");
    const jobs = await api().get("/api/v1/contractors/CT03/work-orders?filter=overbilled&limit=1").set(as("citizen"));
    expect(jobs.body.total).toBe(s.measures.cost.flagged);
  });
  it("gives every ward a scorecard", async () => {
    const s = (await api().get(`/api/v1/wards/${encodeURIComponent("F/S")}/scorecard`).set(as("citizen"))).body.scorecard;
    expect(Object.keys(s.measures).sort()).toEqual(["assign_wait", "cost", "durability", "speed", "speed_fair"]);
  });
  it("judges speed only on jobs that had enough time", async () => {
    const s = (await api().get("/api/v1/contractors/CT03").set(as("citizen"))).body.scorecard;
    expect(s.measures.speed.band).toBe("well_below"); // the plain on-time figure is unchanged
    expect(s.measures.speed_fair.band).toBe("similar");
    expect(s.measures.speed_fair.observed).toBeGreaterThan(0.85);
    expect(s.measures.assign_wait.band).toBe("context");
    expect(s.measures.assign_wait.observed).toBeGreaterThan(70);
  });
  it("holds a ward to its time to assign", async () => {
    const s = (await api().get("/api/v1/wards/L/scorecard").set(as("citizen"))).body.scorecard;
    expect(s.measures.assign_wait.observed).toBeGreaterThan(s.measures.assign_wait.expected);
    expect(["below", "well_below"]).toContain(s.measures.assign_wait.band);
  });
  it("names targets shorter than the work takes", async () => {
    const s = (await api().get("/api/v1/contractors/CT03").set(as("citizen"))).body.scorecard;
    const types = s.unreachable_targets.map((t: any) => t.work_type);
    expect(types).toContain("Road cave-in");
    expect(types).toContain("Open or broken manhole");
    expect(types).not.toContain("Broken paver blocks");
    for (const t of s.unreachable_targets) expect(t.sla_hours).toBeLessThan(t.typical_hours);
  });
  it("opens the jobs behind the fair speed figure", async () => {
    const s = (await api().get("/api/v1/contractors/CT03").set(as("citizen"))).body.scorecard;
    const fair = await api().get("/api/v1/contractors/CT03/work-orders?filter=fair_chance&limit=1").set(as("citizen"));
    expect(fair.body.total).toBe(s.measures.speed_fair.n);
    const late = await api().get("/api/v1/contractors/CT03/work-orders?filter=had_time&limit=1").set(as("citizen"));
    expect(late.body.total).toBe(Math.round(s.measures.speed_fair.n * (1 - s.measures.speed_fair.observed)));
  });
  it("tells the summary writer when a job was assigned, not who was at fault", async () => {
    const { readFileSync } = await import("node:fs");
    const prompt = readFileSync(new URL("../src/pipeline/summarise.ts", import.meta.url), "utf8");
    expect(prompt).toContain("assign_wait");
    expect(prompt).not.toMatch(/ward office|prefer it/);
    expect(prompt).toContain("give both");
  });
  it("shows too few jobs, not a band, for a small ward", async () => {
    const s = (await api().get("/api/v1/wards/C/scorecard").set(as("citizen"))).body.scorecard;
    expect(s.measures.speed_fair.band).toBe("too_few");
  });
});

describe("next-rupee plan", () => {
  const planE = async (who = "auditor") => (await api().get("/api/v1/wards/E/plan").set(as(who))).body;
  const decideOne = async (decision: string, check: (before: any, after: any) => void) => {
    const before = await planE();
    // A job whose only flag is over-billing, so the whole amount moves with the decision.
    const [flag] = await db.$queryRaw<any[]>`
      SELECT work_order_id FROM v_flag f WHERE ward_code = 'E' AND flag_type = 'overbilled' AND tier = 'flag' AND decision = 'open'
        AND NOT EXISTS (SELECT 1 FROM v_flag o WHERE o.work_order_id = f.work_order_id AND o.flag_type <> 'overbilled') LIMIT 1`;
    await api().put(`/api/v1/flags/overbilled/${flag.work_order_id}/decision`).set(as("auditor")).send({ decision });
    try {
      check(before, await planE());
    } finally {
      await db.flag_decision.deleteMany({ where: { flag_type: "overbilled", work_order_id: flag.work_order_id } });
    }
  };
  it("moves recoverable money from possible to confirmed when a flag is confirmed", async () => {
    await decideOne("confirmed", (before, after) => {
      const moved = after.recoverable.confirmed_total - before.recoverable.confirmed_total;
      expect(moved).toBeGreaterThan(0);
      expect(before.recoverable.possible_total - after.recoverable.possible_total).toBe(moved);
      expect(after.items.map((i: any) => i.within_budget)).toEqual(before.items.map((i: any) => i.within_budget));
      expect(after.ward.remaining).toBe(before.ward.remaining);
    });
  });
  it("does not count a dismissed flag as recoverable", async () => {
    await decideOne("not_an_issue", (before, after) => {
      expect(after.recoverable.possible_total).toBeLessThan(before.recoverable.possible_total);
      expect(after.recoverable.confirmed_total).toBe(before.recoverable.confirmed_total);
    });
  });
  it("gives a citizen the recoverable totals and what they would fund", async () => {
    const r = await planE("citizen");
    expect(Object.keys(r.recoverable).sort()).toEqual(["confirmed_billing", "confirmed_dlp", "confirmed_total", "possible_billing", "possible_dlp", "possible_total", "ward_code"]);
    expect(r.items.every((i: any) => typeof i.within_recovered === "boolean" && typeof i.within_possible === "boolean")).toBe(true);
    expect(r.items.filter((i: any) => i.within_possible).length).toBe(26); // Ward E is overspent; recovery would fund all 26
  });
  it("ranks by risk with parts that add up and a correct budget line", async () => {
    const r = (await api().get("/api/v1/wards/B/plan").set(as("citizen"))).body;
    expect(r.items.length).toBeGreaterThan(0);
    let running = 0, sawOver = false;
    r.items.forEach((it: any, i: number) => {
      if (i) expect(it.risk_score).toBeLessThanOrEqual(r.items[i - 1].risk_score);
      const parts = it.pts_severity + it.pts_access + it.pts_safety + it.pts_traffic + it.pts_flood + it.pts_demand;
      expect(Math.abs(parts - it.risk_score)).toBeLessThan(0.35);
      running += it.estimated_cost;
      expect(it.cumulative_cost).toBe(running);
      expect(it.within_budget).toBe(running <= r.ward.remaining);
      if (!it.within_budget) sawOver = true;
      else expect(sawOver).toBe(false);
    });
  });
  it("marks nothing affordable in an overspent ward", async () => {
    const r = (await api().get("/api/v1/wards/E/plan").set(as("citizen"))).body;
    expect(r.ward.remaining).toBeLessThan(0);
    expect(r.items.some((it: any) => it.within_budget)).toBe(false);
  });
  it("recommends the longest-lasting method on high-risk pothole roads", async () => {
    const all = (await api().get("/api/v1/wards/L/plan").set(as("citizen"))).body.items;
    const hr = all.filter((it: any) => it.category === "Pothole" && it.high_risk);
    expect(hr.length).toBeGreaterThan(0);
    for (const it of hr) expect(it.recommended_method).not.toBe("Cold mix patch");
  });
});

describe("settings", () => {
  it("rejects a fair-chance share outside 0 to 1", async () => {
    const r = await api().put("/api/v1/settings").set(as("auditor")).send({ values: { fair_chance_pct: 1.5 } });
    expect(r.status).toBe(400);
    expect(JSON.stringify(r.body)).toContain("between 0 and 1");
  });
  it("is for auditors only and keeps the weights at 100", async () => {
    expect((await api().get("/api/v1/settings").set(as("officer.e"))).status).toBe(403);
    const bad = await api().put("/api/v1/settings").set(as("auditor")).send({ values: { w_traffic: 40 } });
    expect(bad.status).toBe(400);
  });
  it("re-ranks the plan when weights change", async () => {
    const order = async () => (await api().get("/api/v1/wards/L/plan").set(as("auditor"))).body.items.slice(0, 15).map((i: any) => i.issue_id).join();
    const before = await order();
    const put = await api().put("/api/v1/settings").set(as("auditor")).send({ values: { w_severity: 5, w_traffic: 40 } });
    expect(put.status).toBe(200);
    const after = await order();
    await api().put("/api/v1/settings").set(as("auditor")).send({ values: { w_severity: 30, w_traffic: 15 } });
    expect(after).not.toBe(before);
    expect(await order()).toBe(before);
  });
});

describe("trail", () => {
  it("leads from a complaint to its work order", async () => {
    const r = await api().get("/api/v1/trail/complaint/BMC25-000005").set(as("citizen"));
    expect(r.status).toBe(200);
    expect(r.body.highlight).toBe("BMC25-000005");
    expect(r.body.work_order.work_order_id).toMatch(/^WO25-/);
    expect(r.body.road.road_id).toBe(r.body.work_order.road_id);
    expect(JSON.stringify(r.body)).not.toContain("complainant_id");
  });
  it("shows an open issue as never fixed, with its plan rank", async () => {
    const plan = (await api().get("/api/v1/wards/B/plan").set(as("citizen"))).body.items[0];
    const r = (await api().get(`/api/v1/trail/issue/${plan.issue_id}`).set(as("citizen"))).body;
    expect(r.work_order).toBeNull();
    expect(r.plan.rank).toBe(1);
  });
  it("shows an unlinked work order with its flag and no complaints", async () => {
    const f = (await api().get("/api/v1/flags?type=duplicate&limit=1").set(as("auditor"))).body.items[0];
    const r = (await api().get(`/api/v1/trail/work-order/${f.work_order_id}`).set(as("citizen"))).body;
    expect(r.complaints).toHaveLength(0);
    expect(r.flags.some((x: any) => x.flag_type === "duplicate")).toBe(true);
  });
  it("searches and handles no match", async () => {
    const hit = (await api().get("/api/v1/trail/search?q=LBS%20Marg").set(as("citizen"))).body;
    expect(hit.issues.length).toBeGreaterThan(0);
    const none = (await api().get("/api/v1/trail/search?q=zzzzqq").set(as("citizen"))).body;
    expect(none.issues.length + none.complaints.length + none.work_orders.length).toBe(0);
  });
});

describe("intake", () => {
  it("is for ward officers, in their own ward", async () => {
    expect((await api().get("/api/v1/intake/options").set(as("auditor"))).status).toBe(403);
    const outside = (await api().get("/api/v1/wards/B/plan").set(as("auditor"))).body.items[0].road_id;
    const r = await api().post("/api/v1/intake/work-orders").set(as("officer.e")).send({
      road_id: outside, work_type: "Pothole", repair_method: "Hot mix patch", contractor_id: "CT01", area_sqm: 10, cost_inr: 5000, assigned_at: "2025-10-06" });
    expect(r.status).toBe(403);
  });
  it("flags an over-billed new work order at once, then deletes it", async () => {
    const o = (await api().get("/api/v1/intake/options").set(as("officer.e"))).body;
    const m = o.methods.find((x: any) => x.repair_method === "Hot mix patch");
    const body = { road_id: o.roads[0].road_id, work_type: "Pothole", repair_method: "Hot mix patch", contractor_id: "CT01",
      area_sqm: 10, cost_inr: m.standard_rate_inr * 10 * 2, assigned_at: "2025-10-06T10:00:00" };
    const bad = await api().post("/api/v1/intake/work-orders").set(as("officer.e")).send({ ...body, repair_method: "Drain desilting" });
    expect(bad.status).toBe(400);
    const r = await api().post("/api/v1/intake/work-orders").set(as("officer.e")).send(body);
    expect(r.status).toBe(201);
    expect(r.body.flags.some((f: any) => f.flag_type === "overbilled")).toBe(true);
    const del = await api().delete(`/api/v1/intake/work-orders/${r.body.work_order.work_order_id}`).set(as("officer.e"));
    expect(del.status).toBe(204);
    expect((await api().delete("/api/v1/intake/work-orders/WO25-00001").set(as("officer.e"))).status).toBe(404);
  });
  it("puts a new complaint into the plan", async () => {
    const o = (await api().get("/api/v1/intake/options").set(as("officer.e"))).body;
    const r = await api().post("/api/v1/intake/complaints").set(as("officer.e")).send({
      description: `Deep pothole on ${o.roads[0].road_name} near the signal`, category_reported: "Pothole", locality_text: "Byculla" });
    expect(r.status).toBe(201);
    expect(r.body.road.road_name).toBe(o.roads[0].road_name);
    expect(r.body.plan.rank).toBeGreaterThan(0);
    expect(JSON.stringify(r.body)).not.toContain("complainant_id");
    // Clean up so reference counts hold.
    const { db } = await import("../src/lib/db");
    await db.complaint.delete({ where: { complaint_id: r.body.complaint.complaint_id } });
    if (r.body.joined_existing) await db.issue.update({ where: { issue_id: r.body.issue.issue_id }, data: { complaint_count: { decrement: 1 } } });
    else await db.issue.delete({ where: { issue_id: r.body.issue.issue_id } });
  });
});

describe("ask", () => {
  it("returns 429 on the eleventh question in a minute", async () => {
    // Too-short questions are refused before Claude is called, but still count.
    const send = () => api().post("/api/v1/ask").set(as("citizen")).send({ question: "x", scope_type: "ward", scope_id: "E" });
    for (let i = 0; i < 10; i++) expect((await send()).status).toBe(400);
    expect((await send()).status).toBe(429);
  });

  it("marks a summary stale only when its figures have changed", async () => {
    const { db } = await import("../src/lib/db");
    const where = { subject_type_subject_id_lang: { subject_type: "ward", subject_id: "E", lang: "en" } };
    const row = await db.summary.findUnique({ where });
    if (!row) return; // summarise has not been run on this database
    const get = async () => (await api().get("/api/v1/ask/summary?type=ward&id=E").set(as("citizen"))).body.summary.stale;
    // Fresh means the stored hash matches today's figures, whenever the summary was written.
    const { factsHash } = await import("../src/modules/ask");
    await db.summary.update({ where, data: { facts_hash: (await factsHash("ward", "E")).hash } });
    expect(await get()).toBe(false);
    await db.summary.update({ where, data: { facts_hash: "old" } });
    expect(await get()).toBe(true);
    await db.summary.update({ where, data: { facts_hash: row.facts_hash } });
  });

  it("keeps a ward officer to their own ward and validates input", async () => {
    const out = await api().post("/api/v1/ask").set(as("officer.e")).send({ question: "Why is spend high?", scope_type: "ward", scope_id: "B" });
    expect(out.status).toBe(403);
    const bad = await api().post("/api/v1/ask").set(as("auditor")).send({ question: "x", scope_type: "ward", scope_id: "E" });
    expect(bad.status).toBe(400);
  });
  it("gathers facts without the rate-card comparison for citizens", async () => {
    const { factsFor } = await import("../src/modules/ask");
    const f: any = await factsFor("ward", "E", false);
    expect(f.ward.ward_code).toBe("E");
    expect(f.recent_work_orders.length).toBeGreaterThan(0);
    expect(f.recent_work_orders[0]).not.toHaveProperty("cost_ratio");
    expect(f.recent_work_orders[0]).not.toHaveProperty("expected_cost");
    expect(f.top_of_plan.length).toBeGreaterThan(0);
  });
});
