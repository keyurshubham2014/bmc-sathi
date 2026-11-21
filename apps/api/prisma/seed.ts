// Settings defaults and the three demo accounts. Safe to rerun: existing setting values are kept.
import bcrypt from "bcryptjs";
import { db } from "../src/lib/db";

const settings: [string, number, string][] = [
  ["overbill_ratio", 1.5, "Flag a job billed above this multiple of the rate card"],
  ["overbill_watch_ratio", 1.3, "Show a job as 'watch' above this multiple"],
  ["dup_window_days", 7, "Days within which a repeated job counts as possible double billing"],
  ["dup_area_tolerance", 0.05, "How close two areas must be to count as the same job (share)"],
  ["low_lying_cutoff", 0.6, "Low-lying index at or above which a ward is 'low-lying'"],
  ["rain_moderate_mm", 15, "Daily rainfall (mm) from which a job is in the 'moderate' rain band"],
  ["rain_heavy_mm", 65, "Daily rainfall (mm) from which a job is in the 'heavy' rain band"],
  ["band_min_jobs", 30, "Fewest jobs needed before a scorecard band is shown"],
  ["band_z", 2, "Gap from similar jobs (z) needed to say above or below"],
  ["band_z_strong", 3, "Gap from similar jobs (z) needed to say well above or well below"],
  ["w_severity", 30, "Risk weight: severity"],
  ["w_access", 15, "Risk weight: hospital or school access"],
  ["w_safety", 15, "Risk weight: accident record"],
  ["w_traffic", 15, "Risk weight: traffic"],
  ["w_flood", 15, "Risk weight: flood exposure"],
  ["w_demand", 10, "Risk weight: complaints, upvotes and days open"],
  ["high_risk_score", 70, "Risk score from which the longest-lasting method is recommended"],
  ["hotspot_radius_m", 500, "Distance (m) within which a road counts as near a flood hotspot"],
];

const users = [
  { username: "officer.e", role: "ward_officer", ward_code: "E", display_name: "Ward Officer, E Ward" },
  { username: "auditor", role: "auditor", ward_code: null, display_name: "City Auditor" },
  { username: "citizen", role: "citizen", ward_code: null, display_name: "Citizen" },
];

const password = process.env.DEMO_PASSWORD;
if (!password) throw new Error("DEMO_PASSWORD is not set in .env");
const password_hash = await bcrypt.hash(password, 10);

for (const [key, value, description] of settings)
  await db.setting.upsert({ where: { key }, update: { description }, create: { key, value, description } });
for (const u of users)
  await db.app_user.upsert({ where: { username: u.username }, update: { ...u, password_hash }, create: { ...u, password_hash } });

console.log(`seeded ${settings.length} settings, ${users.length} users`);
await db.$disconnect();
