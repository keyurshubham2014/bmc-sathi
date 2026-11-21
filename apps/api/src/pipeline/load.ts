// Loads the 15 supplied files into the raw tables. Safe to rerun: rows that already exist are
// skipped, so decisions, enrichment, issues and intake rows are never touched.
// To reload changed source files from scratch, run `npx prisma migrate reset` first.
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { parse } from "csv-parse/sync";
import { db } from "../lib/db";
import { distanceToSegmentM } from "../lib/geo";

const DATA = resolve(import.meta.dirname, "../../../../data");

type Kind = "int" | "float" | "bool" | "ts" | "date";
type Row = Record<string, unknown>;

/** Reads a CSV and converts the named columns. Blank becomes null. Y/N becomes boolean. */
function read(file: string, types: Record<string, Kind> = {}, drop: string[] = []): Row[] {
  const rows: Record<string, string>[] = parse(readFileSync(resolve(DATA, file)), { columns: true, bom: true });
  return rows.map((raw) => {
    const out: Row = {};
    for (const [k, v] of Object.entries(raw)) {
      if (drop.includes(k)) continue;
      if (v === "") { out[k] = null; continue; }
      switch (types[k]) {
        case "int": out[k] = Math.round(Number(v)); break;
        case "float": out[k] = Number(v); break;
        case "bool": out[k] = v === "Y"; break;
        // Timestamps are IST wall-clock; store the same wall-clock digits.
        case "ts": out[k] = new Date(v.replace(" ", "T") + ":00Z"); break;
        case "date": out[k] = new Date(v + "T00:00:00Z"); break;
        default: out[k] = v;
      }
    }
    return out;
  });
}

async function insert(table: string, rows: Row[]) {
  const model = (db as any)[table];
  let added = 0;
  for (let i = 0; i < rows.length; i += 1000)
    added += (await model.createMany({ data: rows.slice(i, i + 1000), skipDuplicates: true })).count;
  console.log(`  ${table}: ${rows.length} in file, ${added} added`);
}

const wards = read("wards.csv", {
  centroid_lat: "float", centroid_lon: "float", approx_area_km2: "float", population_est: "int",
  low_lying_index: "float", engineering_crews: "int", monsoon_repair_budget_inr_2025: "int",
});
const localities = read("localities.csv", { lat: "float", lon: "float" });
const roads = read("roads.csv", {
  segment_no: "int", lanes: "int", length_m: "float", start_lat: "float", start_lon: "float",
  end_lat: "float", end_lon: "float", last_resurfaced: "date", under_dlp: "bool", bus_route: "bool",
});
const traffic = read("traffic.csv", {
  peak_hour_vehicles: "int", avg_peak_speed_kmph: "float", congestion_index_0_10: "float",
  bus_routes_count: "int", two_wheeler_share_pct: "float",
});
const hotspots = read("flood_hotspots.csv", {
  lat: "float", lon: "float", flood_threshold_mm_per_day: "float", tide_sensitive: "bool",
  avg_water_depth_cm: "float", avg_recession_hours: "float", pumping_station_nearby: "bool",
  years_flagged_last_5: "int",
});
const facilities = read("facilities.csv", { lat: "float", lon: "float", beds_or_students: "int", emergency_services: "bool" });
const accidents = read("accidents.csv", { occurred_at: "ts", lat: "float", lon: "float" });
const rainfall = read("rainfall_daily.csv", { date: "date", rainfall_mm: "float" });
const tides = read("tides.csv", { date: "date", height_m: "float", big_tide_flag: "bool" });
const rates = read("rate_card.csv", { standard_rate_inr: "int" });
const contractors = read("contractors.csv", { empanelled_since: "int" });
const complaints = read("complaints.csv", {
  received_at: "ts", lat: "float", lon: "float", gps_accuracy_m: "float", upvotes: "int", resolved_at: "ts",
});
const posts = read("social_posts.csv", { posted_at: "ts", has_media: "bool", likes_or_forwards: "int" });
const workOrders = read("work_orders.csv", {
  assigned_at: "ts", work_started_at: "ts", completed_at: "ts", area_sqm: "float", cost_inr: "int",
  sla_hours: "int", sla_met: "bool", reopened_within_30d: "bool",
}, ["contractor_name"]);

for (const c of complaints) c.upvotes ??= 0;

// Split the pipe-separated complaint ids, keeping only ids that exist.
const complaintIds = new Set(complaints.map((c) => c.complaint_id));
const links = workOrders.flatMap((w) =>
  String(w.linked_complaint_ids ?? "").split("|").filter((id) => complaintIds.has(id))
    .map((complaint_id) => ({ work_order_id: w.work_order_id, complaint_id })));

// Per road: nearest flood hotspot within range, and the hospitals and schools it serves.
const radius = (await db.setting.findUnique({ where: { key: "hotspot_radius_m" } }))?.value ?? 500;
const proximity = roads.map((r: any) => {
  let near: any = null, best = Infinity;
  for (const h of hotspots as any[]) {
    const m = distanceToSegmentM(h.lat, h.lon, r.start_lat, r.start_lon, r.end_lat, r.end_lon);
    if (m <= radius && m < best) { best = m; near = h; }
  }
  const served = (facilities as any[]).filter((f) => f.ambulance_entry_road === r.road_id);
  return {
    road_id: r.road_id,
    near_hotspot_id: near?.hotspot_id ?? null,
    hotspot_tide_sensitive: near?.tide_sensitive ?? false,
    hospital_entry_count: served.filter((f) => f.type === "Hospital" && f.emergency_services).length,
    school_count: served.filter((f) => f.type === "School").length,
  };
});

console.log("loading...");
await insert("ward", wards);
await insert("locality", localities);
await insert("road", roads);
await insert("traffic", traffic);
await insert("flood_hotspot", hotspots);
await insert("facility", facilities);
await insert("accident", accidents);
await insert("rainfall_daily", rainfall);
await insert("tide", tides);
await insert("rate_card", rates);
await insert("contractor", contractors);
await insert("complaint", complaints);
await insert("social_post", posts);
await insert("work_order", workOrders);
await insert("work_order_complaint", links);
await db.road_proximity.deleteMany(); // recomputed each run
await insert("road_proximity", proximity);

console.log("done.");
await db.$disconnect();
