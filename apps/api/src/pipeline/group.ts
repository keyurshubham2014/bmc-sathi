// Locates every complaint (ward and road) and groups complaints into issues.
// Rebuilds all issues from scratch each run, so it is safe to rerun after enrich changes.
import { db } from "../lib/db";
import { nearestRoad } from "../lib/geo";

// Node 20 has no Map.groupBy.
function groupBy<T>(items: T[], key: (item: T) => string): Map<string, T[]> {
  const out = new Map<string, T[]>();
  for (const item of items) (out.get(key(item)) ?? out.set(key(item), []).get(key(item))!).push(item);
  return out;
}

const WINDOW_MS = 7 * 86_400_000; // complaints further apart than this are separate issues
const OUT_OF_SCOPE = /^(Rejected|Forwarded)/;

const [complaints, roads, localities, links, workOrders] = await Promise.all([
  db.complaint.findMany({ include: { enriched: true }, orderBy: { received_at: "asc" } }),
  db.road.findMany(),
  db.locality.findMany(),
  db.work_order_complaint.findMany(),
  db.work_order.findMany({ select: { work_order_id: true, ward_code: true, road_id: true, work_type: true, reopened_within_30d: true } }),
]);
if (complaints.some((c) => !c.enriched)) throw new Error("Run enrich first: some complaints have no complaint_enriched row.");

const roadsByWard = groupBy(roads, (r) => r.ward_code);
const woById = new Map(workOrders.map((w) => [w.work_order_id, w]));
const woOfComplaint = new Map(links.map((l) => [l.complaint_id, l.work_order_id]));

// Gazetteer: locality name and every alias (Devanagari included), lower-cased.
const gazetteer = new Map<string, (typeof localities)[number]>();
for (const l of localities)
  for (const name of [l.locality, ...(l.aliases ?? "").split(/[;|,]/)])
    if (name.trim()) gazetteer.set(name.trim().toLowerCase(), l);
const findLocality = (text: string | null) => {
  if (!text) return null;
  const t = text.trim().toLowerCase();
  return gazetteer.get(t) ?? [...gazetteer].find(([name]) => t.includes(name) || name.includes(t))?.[1] ?? null;
};

type Loc = { ward: string | null; road: string | null; lat: number | null; lon: number | null; source: string };

function locate(c: (typeof complaints)[number]): Loc {
  const wo = woById.get(woOfComplaint.get(c.complaint_id) ?? "");
  const place = findLocality(c.locality_text);
  const lat = c.lat ?? place?.lat ?? null, lon = c.lon ?? place?.lon ?? null;
  // 1. BMC linked it to a job: that job's road is the best evidence of where it is.
  if (wo) return { ward: wo.ward_code, road: wo.road_id, lat, lon, source: "work_order" };
  const gpsRoad = c.lat != null && c.lon != null ? nearestRoad(c.lat, c.lon, roads)?.road : null;
  const ward = c.ward_code ?? place?.ward_code ?? gpsRoad?.ward_code ?? null;
  const inWard = ward ? roadsByWard.get(ward) ?? [] : roads;
  // 2. GPS: nearest segment in the ward.
  if (c.lat != null && c.lon != null)
    return { ward, road: nearestRoad(c.lat, c.lon, inWard)?.road.road_id ?? null, lat, lon, source: "gps" };
  // 3. A road named in the text, nearest the locality centre.
  const named = inWard.filter((r) => r.road_name === c.enriched!.road_name_mentioned);
  if (named.length)
    return { ward, road: (place ? nearestRoad(place.lat, place.lon, named)!.road : named[0]).road_id, lat, lon, source: "locality" };
  // 4. Locality centre: nearest segment in the ward.
  if (place) return { ward, road: nearestRoad(place.lat, place.lon, inWard)?.road.road_id ?? null, lat, lon, source: "locality" };
  return { ward, road: null, lat, lon, source: "none" };
}

type Issue = {
  issue_id: number; ward_code: string; road_id: string | null; category: string; severity: number;
  first_reported_at: Date; last_reported_at: Date; complaint_count: number; upvotes_total: number;
  work_order_id: string | null; state: string;
};
const issues: Issue[] = [];
const issueOf = new Map<string, number>(); // complaint_id -> issue_id
const loc = new Map(complaints.map((c) => [c.complaint_id, locate(c)]));

function addTo(issue: Issue, c: (typeof complaints)[number]) {
  issue.complaint_count++;
  issue.upvotes_total += c.upvotes;
  issue.severity = Math.max(issue.severity, c.enriched!.severity ?? 3);
  if (c.received_at < issue.first_reported_at) issue.first_reported_at = c.received_at;
  if (c.received_at > issue.last_reported_at) issue.last_reported_at = c.received_at;
  issueOf.set(c.complaint_id, issue.issue_id);
}
function newIssue(c: (typeof complaints)[number], over: Partial<Issue>): Issue {
  const l = loc.get(c.complaint_id)!;
  const issue: Issue = {
    issue_id: issues.length + 1, ward_code: l.ward!, road_id: l.road, category: c.enriched!.category_clean,
    severity: 0, first_reported_at: c.received_at, last_reported_at: c.received_at, complaint_count: 0,
    upvotes_total: 0, work_order_id: null, state: "open", ...over,
  };
  issues.push(issue);
  addTo(issue, c);
  return issue;
}

// A. Complaints BMC linked to the same work order are one issue.
const byWorkOrder = new Map<string, Issue>();
// B. Unlinked open complaints: same place and category, within the window.
const openByKey = new Map<string, Issue>();
const later: typeof complaints = [];

for (const c of complaints) {
  const l = loc.get(c.complaint_id)!;
  if (!l.ward) continue; // cannot be placed in any ward; stays ungrouped
  const woId = woOfComplaint.get(c.complaint_id);
  if (woId) {
    const wo = woById.get(woId)!;
    const existing = byWorkOrder.get(woId);
    if (existing) addTo(existing, c);
    else byWorkOrder.set(woId, newIssue(c, { category: wo.work_type, work_order_id: woId, state: wo.reopened_within_30d ? "fixed_reopened" : "fixed" }));
  } else if (OUT_OF_SCOPE.test(c.status) || c.enriched!.category_clean === "not_road") {
    newIssue(c, { state: "out_of_scope" });
  } else if (c.status === "Open" || c.status === "In Progress") {
    // No road resolved: fall back to the locality text so different places do not merge.
    const key = `${l.ward}|${l.road ?? (c.locality_text ?? "").toLowerCase()}|${c.enriched!.category_clean}`;
    const existing = openByKey.get(key);
    if (existing && c.received_at.getTime() - existing.last_reported_at.getTime() <= WINDOW_MS) addTo(existing, c);
    else openByKey.set(key, newIssue(c, {}));
  } else later.push(c); // duplicates and unlinked resolved complaints
}

// C. Complaints already closed as duplicates join the issue they duplicate, if one is found.
const byPlace = groupBy(issues.filter((i) => i.state !== "out_of_scope" && i.road_id), (i) => `${i.road_id}|${i.category}`);
for (const c of later) {
  const l = loc.get(c.complaint_id)!;
  const t = c.received_at.getTime();
  const match = (byPlace.get(`${l.road}|${c.enriched!.category_clean}`) ?? []).find(
    (i) => t >= i.first_reported_at.getTime() - WINDOW_MS && t <= i.last_reported_at.getTime() + WINDOW_MS);
  if (match) addTo(match, c);
}

// Write: replace all issues, then record each complaint's location and issue in one statement.
const ids = complaints.map((c) => c.complaint_id);
const L = ids.map((id) => loc.get(id)!);
await db.$transaction(async (tx) => {
  await tx.issue.deleteMany();
  for (let i = 0; i < issues.length; i += 1000) await tx.issue.createMany({ data: issues.slice(i, i + 1000) });
  await tx.$executeRaw`SELECT setval(pg_get_serial_sequence('issue', 'issue_id'), ${Math.max(issues.length, 1)})`;
  await tx.$executeRaw`
    UPDATE complaint_enriched e SET ward_code_resolved = v.ward, road_id_resolved = v.road, lat_resolved = v.lat,
           lon_resolved = v.lon, location_source = v.source, issue_id = v.issue
    FROM unnest(${ids}::text[], ${L.map((l) => l.ward)}::text[], ${L.map((l) => l.road)}::text[],
                ${L.map((l) => l.lat)}::float8[], ${L.map((l) => l.lon)}::float8[], ${L.map((l) => l.source)}::text[],
                ${ids.map((id) => issueOf.get(id) ?? null)}::int[]) AS v(id, ward, road, lat, lon, source, issue)
    WHERE e.complaint_id = v.id`;
}, { timeout: 120_000 });

const n = (state: string) => issues.filter((i) => i.state === state).length;
console.log(`issues: ${issues.length} (fixed ${n("fixed")}, re-opened ${n("fixed_reopened")}, open ${n("open")}, out of scope ${n("out_of_scope")})`);
console.log(`complaints grouped: ${issueOf.size} of ${complaints.length}; no road resolved: ${L.filter((l) => !l.road).length}; no ward: ${L.filter((l) => !l.ward).length}`);
await db.$disconnect();
