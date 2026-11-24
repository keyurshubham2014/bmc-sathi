-- All audit and money views. Rerunnable: drops and recreates everything.
-- Rules read thresholds from the setting table, so they change without a redeploy.

DROP VIEW IF EXISTS v_followup, v_work_order_delay, v_plan, v_ward_recoverable, v_open_issue_risk, v_method_durability, v_scorecard, v_ward_spend_breakdown, v_ward_money, v_flag, v_work_order CASCADE;

CREATE OR REPLACE FUNCTION cfg(k text) RETURNS double precision
LANGUAGE sql STABLE AS $$ SELECT value FROM setting WHERE key = k $$;

-- One row per work order with cost against the rate card and its peer-group context.
CREATE VIEW v_work_order AS
SELECT
  w.*,
  c.contractor_name,
  rc.unit,
  rc.standard_rate_inr,
  x.expected_cost,
  w.cost_inr / NULLIF(x.expected_cost, 0)                    AS cost_ratio,
  r.road_name, r.road_type, r.surface, r.bus_route,
  r.under_dlp                                                AS road_under_dlp,
  r.last_resurfaced,
  EXISTS (SELECT 1 FROM work_order_complaint l WHERE l.work_order_id = w.work_order_id) AS has_complaint,
  CASE WHEN COALESCE(rn.mm, 0) >= cfg('rain_heavy_mm')    THEN 'heavy'
       WHEN COALESCE(rn.mm, 0) >= cfg('rain_moderate_mm') THEN 'moderate'
       ELSE 'dry' END                                        AS rain_band,
  CASE WHEN wd.low_lying_index >= cfg('low_lying_cutoff') THEN 'low_lying' ELSE 'normal' END AS ward_type
FROM work_order w
JOIN contractor c ON c.contractor_id = w.contractor_id
JOIN rate_card rc ON rc.repair_method = w.repair_method
JOIN road r       ON r.road_id = w.road_id
JOIN ward wd      ON wd.ward_code = w.ward_code
CROSS JOIN LATERAL (
  SELECT CASE WHEN rc.unit = 'per sqm' THEN w.area_sqm * rc.standard_rate_inr
              ELSE rc.standard_rate_inr END::double precision AS expected_cost
) x
LEFT JOIN (SELECT date, MAX(rainfall_mm) AS mm FROM rainfall_daily GROUP BY date) rn
       ON rn.date = COALESCE(w.completed_at, w.assigned_at)::date;

-- Each job's clock split at assignment: the wait before the contractor had the job, and the work after it.
-- The clock starts at the first linked complaint, so jobs with no complaint are left out.
CREATE VIEW v_work_order_delay AS
WITH d AS (
  SELECT w.work_order_id, w.ward_code, w.contractor_id, w.work_type, w.repair_method, w.rain_band, w.ward_type,
         w.sla_hours, w.sla_met, f.first_complaint_at,
         GREATEST(EXTRACT(EPOCH FROM (w.assigned_at - f.first_complaint_at)) / 3600, 0)::float8 AS hours_to_assign,
         (EXTRACT(EPOCH FROM (w.completed_at - w.assigned_at)) / 3600)::float8                 AS hours_to_do
  FROM v_work_order w
  JOIN (SELECT l.work_order_id, MIN(c.received_at) AS first_complaint_at
        FROM work_order_complaint l JOIN complaint c USING (complaint_id) GROUP BY 1) f USING (work_order_id)
),
t AS (  -- what such work typically takes once assigned
  SELECT work_type, percentile_cont(cfg('fair_chance_pct')) WITHIN GROUP (ORDER BY hours_to_do) AS typical_hours
  FROM d GROUP BY 1
)
SELECT d.*, t.typical_hours,
       (d.sla_hours - d.hours_to_assign >= t.typical_hours) AS fair_chance,
       CASE WHEN d.sla_met IS NOT FALSE                              THEN NULL
            WHEN d.hours_to_assign >= d.sla_hours                    THEN 'expired_before_assignment'
            WHEN d.sla_hours - d.hours_to_assign >= t.typical_hours  THEN 'had_time'
            ELSE 'too_little_time_left' END AS miss_cause
FROM d JOIN t USING (work_type);

-- Each re-opened job and the next job on the same road and work type within 30 days of it, if there was one.
-- The link is inferred from place, kind of work and date: "followed by another job", not proof it redid this one.
CREATE VIEW v_followup AS
SELECT w.work_order_id, w.contractor_id, w.ward_code, w.cost_inr,
       n.work_order_id AS followup_work_order_id, n.cost_inr AS followup_cost, n.contractor_id AS followup_contractor_id
FROM work_order w
LEFT JOIN LATERAL (
  SELECT n.work_order_id, n.cost_inr, n.contractor_id FROM work_order n
  WHERE n.road_id = w.road_id AND n.work_type = w.work_type
    AND n.assigned_at > w.completed_at AND n.assigned_at <= w.completed_at + interval '30 days'
  ORDER BY n.assigned_at, n.work_order_id LIMIT 1
) n ON true
WHERE w.reopened_within_30d;

-- Flags. Identity is (flag_type, work_order_id), so decisions survive recomputation.
CREATE VIEW v_flag AS
WITH f AS (
  -- Billed well above the rate card.
  SELECT 'overbilled' AS flag_type, 'flag' AS tier, w.work_order_id, w.ward_code, w.contractor_id,
         ROUND(w.cost_inr - w.expected_cost)::int AS amount_at_stake,
         jsonb_build_object('method', w.repair_method, 'unit', w.unit, 'area_sqm', w.area_sqm,
                            'rate', w.standard_rate_inr, 'expected_cost', ROUND(w.expected_cost),
                            'cost', w.cost_inr, 'ratio', ROUND(w.cost_ratio::numeric, 2)) AS evidence
  FROM v_work_order w
  WHERE w.cost_ratio > cfg('overbill_ratio')
  UNION ALL
  -- Above normal variation but below the flag line: shown, never decided.
  SELECT 'overbilled', 'watch', w.work_order_id, w.ward_code, w.contractor_id,
         ROUND(w.cost_inr - w.expected_cost)::int,
         jsonb_build_object('method', w.repair_method, 'unit', w.unit, 'area_sqm', w.area_sqm,
                            'rate', w.standard_rate_inr, 'expected_cost', ROUND(w.expected_cost),
                            'cost', w.cost_inr, 'ratio', ROUND(w.cost_ratio::numeric, 2))
  FROM v_work_order w
  WHERE w.cost_ratio > cfg('overbill_watch_ratio') AND w.cost_ratio <= cfg('overbill_ratio')
  UNION ALL
  -- No complaint linked, and it repeats an earlier job on the same road by the same contractor.
  SELECT 'duplicate', 'flag', w.work_order_id, w.ward_code, w.contractor_id, w.cost_inr,
         jsonb_build_object('earlier_work_order_id', e.work_order_id, 'earlier_assigned_at', e.assigned_at,
                            'earlier_cost', e.cost_inr, 'earlier_area_sqm', e.area_sqm,
                            'area_sqm', w.area_sqm, 'cost', w.cost_inr,
                            'days_apart', ROUND((EXTRACT(EPOCH FROM (w.assigned_at - e.assigned_at)) / 86400)::numeric, 1))
  FROM v_work_order w
  CROSS JOIN LATERAL (
    SELECT e.* FROM work_order e
    WHERE e.road_id = w.road_id AND e.work_type = w.work_type AND e.contractor_id = w.contractor_id
      AND e.work_order_id <> w.work_order_id
      AND e.assigned_at < w.assigned_at
      AND w.assigned_at - e.assigned_at <= make_interval(days => cfg('dup_window_days')::int)
      AND ABS(e.area_sqm - w.area_sqm) <= cfg('dup_area_tolerance') * e.area_sqm
    ORDER BY e.assigned_at DESC LIMIT 1
  ) e
  WHERE NOT w.has_complaint
  UNION ALL
  -- Paid by BMC while the road was under its Defect Liability Period.
  SELECT 'dlp', 'flag', w.work_order_id, w.ward_code, w.contractor_id, w.cost_inr,
         jsonb_build_object('road_id', w.road_id, 'road_name', w.road_name,
                            'last_resurfaced', w.last_resurfaced, 'cost', w.cost_inr)
  FROM v_work_order w
  WHERE w.road_under_dlp AND w.cost_inr > 0
)
SELECT f.*, COALESCE(d.decision, 'open') AS decision, d.note, d.decided_by, d.decided_at
FROM f
LEFT JOIN flag_decision d ON d.flag_type = f.flag_type AND d.work_order_id = f.work_order_id;

-- One row per ward: budget, spend and the money at question.
CREATE VIEW v_ward_money AS
SELECT
  wd.ward_code, wd.ward_name, wd.zone, wd.low_lying_index,
  wd.monsoon_repair_budget_inr_2025                              AS budget,
  COALESCE(s.spend, 0)                                           AS spend,
  wd.monsoon_repair_budget_inr_2025 - COALESCE(s.spend, 0)       AS remaining,
  COALESCE(s.spend, 0)::double precision / wd.monsoon_repair_budget_inr_2025 AS spend_share,
  COALESCE(s.jobs, 0)                                            AS jobs,
  COALESCE(s.reopened_spend, 0)                                  AS reopened_spend,
  COALESCE(s.reopened_jobs, 0)                                   AS reopened_jobs,
  COALESCE(s.dlp_spend, 0)                                       AS dlp_spend,
  COALESCE(s.dlp_jobs, 0)                                        AS dlp_jobs,
  COALESCE(fl.open_flag_amount, 0)                               AS open_flag_amount,
  COALESCE(fl.open_flags, 0)                                     AS open_flags,
  s.sla_met_rate, s.reopen_rate
FROM ward wd
LEFT JOIN (
  SELECT ward_code,
         SUM(cost_inr)::bigint AS spend, COUNT(*)::int AS jobs,
         COALESCE(SUM(cost_inr) FILTER (WHERE reopened_within_30d), 0)::bigint AS reopened_spend,
         (COUNT(*) FILTER (WHERE reopened_within_30d))::int                    AS reopened_jobs,
         COALESCE(SUM(cost_inr) FILTER (WHERE road_under_dlp), 0)::bigint      AS dlp_spend,
         (COUNT(*) FILTER (WHERE road_under_dlp))::int                         AS dlp_jobs,
         AVG(sla_met::int)             AS sla_met_rate,
         AVG(reopened_within_30d::int) AS reopen_rate
  FROM v_work_order GROUP BY ward_code
) s ON s.ward_code = wd.ward_code
LEFT JOIN (
  -- A work order with several flag types counts once, at its largest amount.
  SELECT ward_code, SUM(amt)::bigint AS open_flag_amount, COUNT(*)::int AS open_flags
  FROM (SELECT ward_code, work_order_id, MAX(amount_at_stake) AS amt
        FROM v_flag WHERE tier = 'flag' AND decision = 'open'
        GROUP BY ward_code, work_order_id) t
  GROUP BY ward_code
) fl ON fl.ward_code = wd.ward_code;

-- Flagged money per ward: confirmed by a decision, or still possible (open or awaiting an explanation).
-- A work order never counts for more than its largest flag that has not been dismissed. Its confirmed part
-- is its largest confirmed flag; whatever is left of the largest amount stays possible.
-- When a billing flag and a DLP flag tie for largest, the amount goes under DLP.
CREATE VIEW v_ward_recoverable AS
WITH f AS (
  SELECT ward_code, work_order_id, amount_at_stake AS amt, (flag_type = 'dlp') AS is_dlp, (decision = 'confirmed') AS is_confirmed
  FROM v_flag WHERE tier = 'flag' AND decision <> 'not_an_issue'
),
w AS (
  SELECT ward_code, work_order_id,
         COALESCE(MAX(amt) FILTER (WHERE is_confirmed), 0)                                    AS c_amt,
         COALESCE((array_agg(is_dlp ORDER BY amt DESC, is_dlp DESC) FILTER (WHERE is_confirmed))[1], false) AS c_dlp,
         MAX(amt)                                                                             AS t_amt,
         (array_agg(is_dlp ORDER BY amt DESC, is_dlp DESC))[1]                                             AS t_dlp
  FROM f GROUP BY 1, 2
)
SELECT wd.ward_code,
       COALESCE(SUM(c_amt) FILTER (WHERE NOT c_dlp), 0)::bigint         AS confirmed_billing,
       COALESCE(SUM(c_amt) FILTER (WHERE c_dlp), 0)::bigint             AS confirmed_dlp,
       COALESCE(SUM(c_amt), 0)::bigint                                  AS confirmed_total,
       COALESCE(SUM(t_amt - c_amt) FILTER (WHERE NOT t_dlp), 0)::bigint AS possible_billing,
       COALESCE(SUM(t_amt - c_amt) FILTER (WHERE t_dlp), 0)::bigint     AS possible_dlp,
       COALESCE(SUM(t_amt - c_amt), 0)::bigint                          AS possible_total
FROM ward wd LEFT JOIN w USING (ward_code)
GROUP BY wd.ward_code;

-- Spend per ward by contractor, repair method and week.
CREATE VIEW v_ward_spend_breakdown AS
SELECT ward_code, 'contractor' AS dimension, contractor_id AS key, contractor_name AS label,
       SUM(cost_inr)::bigint AS spend, COUNT(*)::int AS jobs
FROM v_work_order GROUP BY ward_code, contractor_id, contractor_name
UNION ALL
SELECT ward_code, 'method', repair_method, repair_method, SUM(cost_inr)::bigint, COUNT(*)::int
FROM v_work_order GROUP BY ward_code, repair_method
UNION ALL
SELECT ward_code, 'week',
       to_char(date_trunc('week', COALESCE(completed_at, assigned_at)), 'YYYY-MM-DD'),
       to_char(date_trunc('week', COALESCE(completed_at, assigned_at)), 'DD Mon'),
       SUM(cost_inr)::bigint, COUNT(*)::int
FROM v_work_order GROUP BY ward_code, date_trunc('week', COALESCE(completed_at, assigned_at));

-- ---------- scorecards ----------

-- Band for a gap from similar jobs. z is signed so that positive always means better.
CREATE OR REPLACE FUNCTION band(n bigint, z double precision) RETURNS text
LANGUAGE sql STABLE AS $$
  SELECT CASE WHEN n < cfg('band_min_jobs') OR z IS NULL THEN 'too_few'
              WHEN abs(z) < cfg('band_z')        THEN 'similar'
              WHEN z >=  cfg('band_z_strong')    THEN 'well_above'
              WHEN z > 0                         THEN 'above'
              WHEN z <= -cfg('band_z_strong')    THEN 'well_below'
              ELSE 'below' END $$;

-- Speed, durability and cost for each contractor and each ward, against similar jobs.
-- "Similar" = same work type, repair method, rain band and ward type, leaving out the subject's own jobs.
CREATE VIEW v_scorecard AS
WITH jobs AS (
  SELECT 'contractor' AS subject_type, contractor_id AS subject_id, w.* FROM v_work_order w
  UNION ALL
  SELECT 'ward', ward_code, w.* FROM v_work_order w
),
cell AS (   -- the subject's jobs in each peer group
  SELECT subject_type, subject_id, work_type, repair_method, rain_band, ward_type,
         COUNT(sla_met) AS n_sla, COALESCE(SUM(sla_met::int), 0) AS on_time,
         COUNT(reopened_within_30d) AS n_reo, COALESCE(SUM(reopened_within_30d::int), 0) AS reo
  FROM jobs GROUP BY 1, 2, 3, 4, 5, 6
),
strat AS (  -- everyone's jobs in each peer group
  SELECT work_type, repair_method, rain_band, ward_type,
         COUNT(sla_met) AS n_sla, COALESCE(SUM(sla_met::int), 0) AS on_time,
         COUNT(reopened_within_30d) AS n_reo, COALESCE(SUM(reopened_within_30d::int), 0) AS reo
  FROM v_work_order GROUP BY 1, 2, 3, 4
),
wide_all AS (  -- fallback peer group: work type and method only
  SELECT work_type, repair_method, SUM(n_sla) AS n_sla, SUM(on_time) AS on_time, SUM(n_reo) AS n_reo, SUM(reo) AS reo
  FROM strat GROUP BY 1, 2
),
wide_own AS (
  SELECT subject_type, subject_id, work_type, repair_method,
         SUM(n_sla) AS n_sla, SUM(on_time) AS on_time, SUM(n_reo) AS n_reo, SUM(reo) AS reo
  FROM cell GROUP BY 1, 2, 3, 4
),
x AS (      -- what similar jobs achieved, per peer group, without the subject's own jobs
  SELECT c.subject_type, c.subject_id, c.n_sla, c.on_time, c.n_reo, c.reo,
         CASE WHEN s.n_sla - c.n_sla >= 5 THEN (s.on_time - c.on_time)::float8 / (s.n_sla - c.n_sla)
              ELSE (wa.on_time - wo.on_time)::float8 / NULLIF(wa.n_sla - wo.n_sla, 0) END AS exp_sla,
         CASE WHEN s.n_reo - c.n_reo >= 5 THEN (s.reo - c.reo)::float8 / (s.n_reo - c.n_reo)
              ELSE (wa.reo - wo.reo)::float8 / NULLIF(wa.n_reo - wo.n_reo, 0) END AS exp_reo
  FROM cell c
  JOIN strat s     USING (work_type, repair_method, rain_band, ward_type)
  JOIN wide_all wa USING (work_type, repair_method)
  JOIN wide_own wo USING (subject_type, subject_id, work_type, repair_method)
),
agg AS (
  SELECT subject_type, subject_id,
         SUM(n_sla)::bigint AS n_sla, SUM(on_time)::float8 / NULLIF(SUM(n_sla), 0) AS obs_sla,
         SUM(n_sla * exp_sla) / NULLIF(SUM(n_sla) FILTER (WHERE exp_sla IS NOT NULL), 0) AS exp_sla,
         SUM(n_reo)::bigint AS n_reo, SUM(reo)::float8 / NULLIF(SUM(n_reo), 0) AS obs_reo,
         SUM(n_reo * exp_reo) / NULLIF(SUM(n_reo) FILTER (WHERE exp_reo IS NOT NULL), 0) AS exp_reo
  FROM x GROUP BY 1, 2
),
ctx AS (
  SELECT subject_type, subject_id, COUNT(*)::int AS jobs, SUM(cost_inr)::bigint AS spend,
         COUNT(DISTINCT ward_code)::int AS wards,
         (COUNT(*) FILTER (WHERE rain_band = 'heavy'))::int     AS heavy_rain_jobs,
         (COUNT(*) FILTER (WHERE ward_type = 'low_lying'))::int AS low_lying_jobs,
         percentile_cont(0.5) WITHIN GROUP (ORDER BY cost_ratio) AS median_ratio,
         (COUNT(*) FILTER (WHERE cost_ratio > cfg('overbill_ratio')))::int AS over_jobs
  FROM jobs GROUP BY 1, 2
),
-- The same comparison for the two delay measures, over jobs whose clock is known.
dj AS (
  SELECT 'contractor' AS subject_type, contractor_id AS subject_id, d.* FROM v_work_order_delay d
  UNION ALL
  SELECT 'ward', ward_code, d.* FROM v_work_order_delay d
),
dcell AS (
  SELECT subject_type, subject_id, work_type, repair_method, rain_band, ward_type,
         COUNT(*) FILTER (WHERE fair_chance) AS n_fair, COUNT(*) FILTER (WHERE fair_chance AND sla_met) AS fair_on,
         COUNT(*) AS n_wait, SUM(hours_to_assign) AS sum_wait, SUM(hours_to_assign * hours_to_assign) AS sq_wait
  FROM dj GROUP BY 1, 2, 3, 4, 5, 6
),
dstrat AS (
  SELECT work_type, repair_method, rain_band, ward_type,
         COUNT(*) FILTER (WHERE fair_chance) AS n_fair, COUNT(*) FILTER (WHERE fair_chance AND sla_met) AS fair_on,
         COUNT(*) AS n_wait, SUM(hours_to_assign) AS sum_wait
  FROM v_work_order_delay GROUP BY 1, 2, 3, 4
),
dwide_all AS (
  SELECT work_type, repair_method, SUM(n_fair) AS n_fair, SUM(fair_on) AS fair_on, SUM(n_wait) AS n_wait, SUM(sum_wait) AS sum_wait
  FROM dstrat GROUP BY 1, 2
),
dwide_own AS (
  SELECT subject_type, subject_id, work_type, repair_method,
         SUM(n_fair) AS n_fair, SUM(fair_on) AS fair_on, SUM(n_wait) AS n_wait, SUM(sum_wait) AS sum_wait
  FROM dcell GROUP BY 1, 2, 3, 4
),
dx AS (
  SELECT c.subject_type, c.subject_id, c.n_fair, c.fair_on, c.n_wait, c.sum_wait, c.sq_wait,
         CASE WHEN s.n_fair - c.n_fair >= 5 THEN (s.fair_on - c.fair_on)::float8 / (s.n_fair - c.n_fair)
              ELSE (wa.fair_on - wo.fair_on)::float8 / NULLIF(wa.n_fair - wo.n_fair, 0) END AS exp_fair,
         CASE WHEN s.n_wait - c.n_wait >= 5 THEN (s.sum_wait - c.sum_wait) / (s.n_wait - c.n_wait)
              ELSE (wa.sum_wait - wo.sum_wait) / NULLIF(wa.n_wait - wo.n_wait, 0) END AS exp_wait
  FROM dcell c
  JOIN dstrat s     USING (work_type, repair_method, rain_band, ward_type)
  JOIN dwide_all wa USING (work_type, repair_method)
  JOIN dwide_own wo USING (subject_type, subject_id, work_type, repair_method)
),
dagg AS (
  SELECT subject_type, subject_id,
         SUM(n_fair)::bigint AS n_fair, SUM(fair_on)::float8 / NULLIF(SUM(n_fair), 0) AS obs_fair,
         SUM(n_fair * exp_fair) / NULLIF(SUM(n_fair) FILTER (WHERE exp_fair IS NOT NULL), 0) AS exp_fair,
         SUM(n_wait)::bigint AS n_wait, SUM(sum_wait) / NULLIF(SUM(n_wait), 0) AS obs_wait,
         SUM(n_wait * exp_wait) / NULLIF(SUM(n_wait) FILTER (WHERE exp_wait IS NOT NULL), 0) AS exp_wait,
         sqrt(GREATEST(SUM(sq_wait) / NULLIF(SUM(n_wait), 0) - power(SUM(sum_wait) / NULLIF(SUM(n_wait), 0), 2), 0)) AS sd_wait
  FROM dx GROUP BY 1, 2
)
SELECT c.subject_type, c.subject_id, 'speed' AS measure, a.obs_sla AS observed, a.exp_sla AS expected,
       a.n_sla AS n, band(a.n_sla, (a.obs_sla - a.exp_sla) / NULLIF(sqrt(a.exp_sla * (1 - a.exp_sla) / NULLIF(a.n_sla, 0)), 0)) AS band,
       NULL::int AS flagged, c.jobs, c.spend, c.wards, c.heavy_rain_jobs, c.low_lying_jobs
FROM ctx c JOIN agg a USING (subject_type, subject_id)
UNION ALL
-- Fewer re-opens is better, so the sign is reversed.
SELECT c.subject_type, c.subject_id, 'durability', a.obs_reo, a.exp_reo,
       a.n_reo, band(a.n_reo, (a.exp_reo - a.obs_reo) / NULLIF(sqrt(a.exp_reo * (1 - a.exp_reo) / NULLIF(a.n_reo, 0)), 0)),
       NULL::int, c.jobs, c.spend, c.wards, c.heavy_rain_jobs, c.low_lying_jobs
FROM ctx c JOIN agg a USING (subject_type, subject_id)
UNION ALL
SELECT c.subject_type, c.subject_id, 'cost', c.median_ratio, 1, c.jobs::bigint,
       -- "Review" only when the share of jobs above the flag line is more than twice the city's share.
       CASE WHEN c.over_jobs::float8 / c.jobs > 2 * (SELECT AVG((cost_ratio > cfg('overbill_ratio'))::int) FROM v_work_order)
            THEN 'review' ELSE 'typical' END,
       c.over_jobs, c.jobs, c.spend, c.wards, c.heavy_rain_jobs, c.low_lying_jobs
FROM ctx c
UNION ALL
-- On time among jobs that reached the subject with enough time left.
SELECT c.subject_type, c.subject_id, 'speed_fair', d.obs_fair, d.exp_fair, COALESCE(d.n_fair, 0),
       band(COALESCE(d.n_fair, 0), (d.obs_fair - d.exp_fair) / NULLIF(sqrt(d.exp_fair * (1 - d.exp_fair) / NULLIF(d.n_fair, 0)), 0)),
       NULL::int, c.jobs, c.spend, c.wards, c.heavy_rain_jobs, c.low_lying_jobs
FROM ctx c LEFT JOIN dagg d USING (subject_type, subject_id)
UNION ALL
-- Hours a job waited before it was assigned. Fewer is better. A ward assigns jobs; a contractor does not, so it gets no band.
SELECT c.subject_type, c.subject_id, 'assign_wait', d.obs_wait, d.exp_wait, COALESCE(d.n_wait, 0),
       CASE WHEN c.subject_type = 'contractor' THEN 'context'
            ELSE band(COALESCE(d.n_wait, 0), (d.exp_wait - d.obs_wait) / NULLIF(d.sd_wait / sqrt(NULLIF(d.n_wait, 0)), 0)) END,
       NULL::int, c.jobs, c.spend, c.wards, c.heavy_rain_jobs, c.low_lying_jobs
FROM ctx c LEFT JOIN dagg d USING (subject_type, subject_id);

-- ---------- next-rupee plan ----------

-- How often each method re-opened, by road type, with '*' for all road types together.
CREATE VIEW v_method_durability AS
SELECT work_type, repair_method, road_type, COUNT(reopened_within_30d)::int AS jobs, AVG(reopened_within_30d::int)::float8 AS reopen_rate
FROM v_work_order GROUP BY 1, 2, 3
UNION ALL
SELECT work_type, repair_method, '*', COUNT(reopened_within_30d)::int, AVG(reopened_within_30d::int)::float8
FROM v_work_order GROUP BY 1, 2;

-- Risk score for each open issue. Every part is returned so the screen can show the breakdown.
CREATE VIEW v_open_issue_risk AS
WITH asof AS (SELECT MAX(received_at) AS t FROM complaint),  -- the data's "today"
tr AS (
  SELECT road_id, percent_rank() OVER (ORDER BY peak_hour_vehicles) AS pr_vehicles,
         percent_rank() OVER (ORDER BY two_wheeler_share_pct) AS pr_two_wheeler
  FROM traffic
),
acc AS (
  SELECT road_id, SUM(CASE severity WHEN 'Fatal' THEN 3 WHEN 'Grievous' THEN 2 ELSE 1 END)::int AS weight, COUNT(*)::int AS accidents
  FROM accident
  WHERE probable_cause IN ('Pothole', 'Waterlogged road', 'Uneven road / open chamber') AND road_id IS NOT NULL
  GROUP BY road_id
),
p AS (
  SELECT i.*, r.road_name, r.segment_no, r.road_type, r.surface, COALESCE(r.bus_route, false) AS bus_route,
         COALESCE(rp.hospital_entry_count, 0) AS hospital_entry_count, COALESCE(rp.school_count, 0) AS school_count,
         rp.near_hotspot_id, COALESCE(acc.accidents, 0) AS accidents,
         (EXTRACT(EPOCH FROM ((SELECT t FROM asof) - i.first_reported_at)) / 86400)::float8 AS days_open,
         (i.severity - 1) / 4.0 AS p_severity,
         CASE WHEN rp.hospital_entry_count > 0 THEN 1.0 WHEN rp.school_count > 0 THEN 0.5 ELSE 0 END AS p_access,
         LEAST(COALESCE(acc.weight, 0), 6) / 6.0 AS p_safety,
         LEAST(1.0, (COALESCE(tr.pr_vehicles, 0) + COALESCE(tr.pr_two_wheeler, 0)) / 2 + CASE WHEN r.bus_route THEN 0.1 ELSE 0 END) AS p_traffic,
         CASE WHEN rp.near_hotspot_id IS NOT NULL
              THEN CASE WHEN i.category IN ('Waterlogging', 'Choked drain / nullah overflow') THEN 1.0 ELSE 0.7 END
              ELSE wd.low_lying_index * 0.5 END AS p_flood
  FROM issue i
  JOIN ward wd ON wd.ward_code = i.ward_code
  LEFT JOIN road r ON r.road_id = i.road_id
  LEFT JOIN road_proximity rp ON rp.road_id = i.road_id
  LEFT JOIN tr ON tr.road_id = i.road_id
  LEFT JOIN acc ON acc.road_id = i.road_id
  WHERE i.state = 'open'
),
d AS (
  SELECT p.*, percent_rank() OVER (PARTITION BY ward_code ORDER BY complaint_count + upvotes_total / 10.0 + days_open / 7.0) AS p_demand FROM p
)
SELECT d.*,
       ROUND((p_severity * cfg('w_severity'))::numeric, 1)::float8 AS pts_severity,
       ROUND((p_access   * cfg('w_access'))::numeric, 1)::float8   AS pts_access,
       ROUND((p_safety   * cfg('w_safety'))::numeric, 1)::float8   AS pts_safety,
       ROUND((p_traffic  * cfg('w_traffic'))::numeric, 1)::float8  AS pts_traffic,
       ROUND((p_flood    * cfg('w_flood'))::numeric, 1)::float8    AS pts_flood,
       ROUND((p_demand   * cfg('w_demand'))::numeric, 1)::float8   AS pts_demand,
       ROUND((p_severity * cfg('w_severity') + p_access * cfg('w_access') + p_safety * cfg('w_safety')
            + p_traffic * cfg('w_traffic') + p_flood * cfg('w_flood') + p_demand * cfg('w_demand'))::numeric, 1)::float8 AS risk_score
FROM d;

-- The ranked plan: a method, a cost and a running total against the ward's remaining budget.
CREATE VIEW v_plan AS
WITH area AS (
  SELECT ward_code, work_type, percentile_cont(0.5) WITHIN GROUP (ORDER BY area_sqm) AS median_area FROM work_order GROUP BY 1, 2
),
city_area AS (
  SELECT work_type, percentile_cont(0.5) WITHIN GROUP (ORDER BY area_sqm) AS median_area FROM work_order GROUP BY 1
),
i AS (
  SELECT r.*,
         (r.road_type IN ('Highway', 'Arterial') OR r.hospital_entry_count > 0 OR r.bus_route OR r.risk_score >= cfg('high_risk_score')) AS high_risk,
         COALESCE(a.median_area, ca.median_area) AS est_area
  FROM v_open_issue_risk r
  LEFT JOIN area a ON a.ward_code = r.ward_code AND a.work_type = r.category
  LEFT JOIN city_area ca ON ca.work_type = r.category
),
cand AS (  -- every method used for this kind of work, with its cost and how often it re-opened on this road type
  SELECT i.issue_id, i.high_risk, m.repair_method, rc.unit,
         COALESCE(CASE WHEN byroad.jobs >= 10 THEN byroad.reopen_rate END, m.reopen_rate) AS reopen_rate,
         ROUND(CASE WHEN rc.unit = 'per sqm' THEN rc.standard_rate_inr * i.est_area ELSE rc.standard_rate_inr END)::int AS est_cost
  FROM i
  JOIN v_method_durability m ON m.work_type = i.category AND m.road_type = '*'
  JOIN rate_card rc ON rc.repair_method = m.repair_method
  LEFT JOIN v_method_durability byroad ON byroad.work_type = i.category AND byroad.repair_method = m.repair_method AND byroad.road_type = i.road_type
),
ranked AS (
  SELECT cand.*,
         row_number() OVER (PARTITION BY issue_id ORDER BY reopen_rate, est_cost) AS by_durability,
         row_number() OVER (PARTITION BY issue_id ORDER BY est_cost * (1 + reopen_rate), reopen_rate) AS by_cost
  FROM cand
),
pick AS (  -- high-risk roads get the method that lasts; others get the cheapest once redone work is counted
  SELECT issue_id,
         MAX(repair_method) FILTER (WHERE (high_risk AND by_durability = 1) OR (NOT high_risk AND by_cost = 1)) AS recommended_method,
         MAX(est_cost)      FILTER (WHERE (high_risk AND by_durability = 1) OR (NOT high_risk AND by_cost = 1)) AS estimated_cost,
         MAX(reopen_rate)   FILTER (WHERE (high_risk AND by_durability = 1) OR (NOT high_risk AND by_cost = 1)) AS recommended_reopen_rate,
         MAX(repair_method) FILTER (WHERE (high_risk AND by_cost = 1) OR (NOT high_risk AND by_durability = 1)) AS alt_method,
         MAX(est_cost)      FILTER (WHERE (high_risk AND by_cost = 1) OR (NOT high_risk AND by_durability = 1)) AS alt_cost,
         MAX(reopen_rate)   FILTER (WHERE (high_risk AND by_cost = 1) OR (NOT high_risk AND by_durability = 1)) AS alt_reopen_rate,
         COUNT(*)::int AS method_count
  FROM ranked GROUP BY issue_id
),
o AS (
  SELECT i.*, pk.recommended_method, pk.estimated_cost, pk.recommended_reopen_rate, pk.method_count,
         CASE WHEN pk.alt_method <> pk.recommended_method THEN pk.alt_method END AS alt_method,
         CASE WHEN pk.alt_method <> pk.recommended_method THEN pk.alt_cost END AS alt_cost,
         CASE WHEN pk.alt_method <> pk.recommended_method THEN pk.alt_reopen_rate END AS alt_reopen_rate,
         (row_number() OVER (PARTITION BY i.ward_code ORDER BY i.risk_score DESC, i.issue_id))::int AS rank,
         (SUM(pk.estimated_cost) OVER (PARTITION BY i.ward_code ORDER BY i.risk_score DESC, i.issue_id))::bigint AS cumulative_cost
  FROM i JOIN pick pk USING (issue_id)
)
SELECT o.*, wm.remaining AS ward_remaining,
       (wm.remaining > 0 AND o.cumulative_cost <= wm.remaining) AS within_budget,
       -- Recovered money pays off any overspend first. It never changes within_budget.
       (wm.remaining + rv.confirmed_total > 0 AND o.cumulative_cost <= wm.remaining + rv.confirmed_total) AS within_recovered,
       (wm.remaining + rv.confirmed_total + rv.possible_total > 0
        AND o.cumulative_cost <= wm.remaining + rv.confirmed_total + rv.possible_total)                    AS within_possible,
       -- Every loaded job on this road, whatever the work type. The data holds one season, like every other total here.
       COALESCE(rj.road_jobs, 0) AS road_jobs, COALESCE(rj.road_spend, 0)::bigint AS road_spend
FROM o JOIN v_ward_money wm USING (ward_code) JOIN v_ward_recoverable rv USING (ward_code)
LEFT JOIN (SELECT road_id, COUNT(*)::int AS road_jobs, SUM(cost_inr)::bigint AS road_spend FROM work_order GROUP BY road_id) rj
       ON rj.road_id = o.road_id;
