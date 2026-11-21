-- CreateTable
CREATE TABLE "ward" (
    "ward_code" TEXT NOT NULL,
    "ward_name" TEXT NOT NULL,
    "zone" TEXT NOT NULL,
    "assistant_commissioner_office" TEXT NOT NULL,
    "centroid_lat" DOUBLE PRECISION NOT NULL,
    "centroid_lon" DOUBLE PRECISION NOT NULL,
    "approx_area_km2" DOUBLE PRECISION NOT NULL,
    "population_est" INTEGER NOT NULL,
    "low_lying_index" DOUBLE PRECISION NOT NULL,
    "engineering_crews" INTEGER NOT NULL,
    "localities" TEXT NOT NULL,
    "monsoon_repair_budget_inr_2025" INTEGER NOT NULL,

    CONSTRAINT "ward_pkey" PRIMARY KEY ("ward_code")
);

-- CreateTable
CREATE TABLE "locality" (
    "locality" TEXT NOT NULL,
    "ward_code" TEXT NOT NULL,
    "lat" DOUBLE PRECISION NOT NULL,
    "lon" DOUBLE PRECISION NOT NULL,
    "aliases" TEXT,

    CONSTRAINT "locality_pkey" PRIMARY KEY ("locality","ward_code")
);

-- CreateTable
CREATE TABLE "road" (
    "road_id" TEXT NOT NULL,
    "road_name" TEXT NOT NULL,
    "segment_no" INTEGER NOT NULL,
    "ward_code" TEXT NOT NULL,
    "road_type" TEXT NOT NULL,
    "surface" TEXT NOT NULL,
    "lanes" INTEGER NOT NULL,
    "length_m" DOUBLE PRECISION NOT NULL,
    "start_lat" DOUBLE PRECISION NOT NULL,
    "start_lon" DOUBLE PRECISION NOT NULL,
    "end_lat" DOUBLE PRECISION NOT NULL,
    "end_lon" DOUBLE PRECISION NOT NULL,
    "last_resurfaced" DATE NOT NULL,
    "under_dlp" BOOLEAN NOT NULL,
    "bus_route" BOOLEAN NOT NULL,

    CONSTRAINT "road_pkey" PRIMARY KEY ("road_id")
);

-- CreateTable
CREATE TABLE "traffic" (
    "road_id" TEXT NOT NULL,
    "peak_hour_vehicles" INTEGER NOT NULL,
    "avg_peak_speed_kmph" DOUBLE PRECISION NOT NULL,
    "congestion_index_0_10" DOUBLE PRECISION NOT NULL,
    "bus_routes_count" INTEGER NOT NULL,
    "two_wheeler_share_pct" DOUBLE PRECISION NOT NULL,

    CONSTRAINT "traffic_pkey" PRIMARY KEY ("road_id")
);

-- CreateTable
CREATE TABLE "flood_hotspot" (
    "hotspot_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "ward_code" TEXT NOT NULL,
    "lat" DOUBLE PRECISION NOT NULL,
    "lon" DOUBLE PRECISION NOT NULL,
    "flood_threshold_mm_per_day" DOUBLE PRECISION NOT NULL,
    "tide_sensitive" BOOLEAN NOT NULL,
    "avg_water_depth_cm" DOUBLE PRECISION NOT NULL,
    "avg_recession_hours" DOUBLE PRECISION NOT NULL,
    "pumping_station_nearby" BOOLEAN NOT NULL,
    "years_flagged_last_5" INTEGER NOT NULL,

    CONSTRAINT "flood_hotspot_pkey" PRIMARY KEY ("hotspot_id")
);

-- CreateTable
CREATE TABLE "facility" (
    "facility_id" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "ward_code" TEXT NOT NULL,
    "lat" DOUBLE PRECISION NOT NULL,
    "lon" DOUBLE PRECISION NOT NULL,
    "beds_or_students" INTEGER,
    "emergency_services" BOOLEAN NOT NULL,
    "ambulance_entry_road" TEXT,

    CONSTRAINT "facility_pkey" PRIMARY KEY ("facility_id")
);

-- CreateTable
CREATE TABLE "accident" (
    "accident_id" TEXT NOT NULL,
    "occurred_at" TIMESTAMP(0) NOT NULL,
    "ward_code" TEXT NOT NULL,
    "road_id" TEXT,
    "lat" DOUBLE PRECISION NOT NULL,
    "lon" DOUBLE PRECISION NOT NULL,
    "vehicle_type" TEXT NOT NULL,
    "severity" TEXT NOT NULL,
    "probable_cause" TEXT NOT NULL,

    CONSTRAINT "accident_pkey" PRIMARY KEY ("accident_id")
);

-- CreateTable
CREATE TABLE "rainfall_daily" (
    "date" DATE NOT NULL,
    "station" TEXT NOT NULL,
    "rainfall_mm" DOUBLE PRECISION NOT NULL,
    "imd_category" TEXT NOT NULL,
    "imd_alert" TEXT NOT NULL,

    CONSTRAINT "rainfall_daily_pkey" PRIMARY KEY ("date","station")
);

-- CreateTable
CREATE TABLE "tide" (
    "date" DATE NOT NULL,
    "high_tide_time" TEXT NOT NULL,
    "height_m" DOUBLE PRECISION NOT NULL,
    "big_tide_flag" BOOLEAN NOT NULL,

    CONSTRAINT "tide_pkey" PRIMARY KEY ("date","high_tide_time")
);

-- CreateTable
CREATE TABLE "rate_card" (
    "repair_method" TEXT NOT NULL,
    "unit" TEXT NOT NULL,
    "standard_rate_inr" INTEGER NOT NULL,

    CONSTRAINT "rate_card_pkey" PRIMARY KEY ("repair_method")
);

-- CreateTable
CREATE TABLE "contractor" (
    "contractor_id" TEXT NOT NULL,
    "contractor_name" TEXT NOT NULL,
    "empanelled_since" INTEGER NOT NULL,
    "active_wards" TEXT NOT NULL,

    CONSTRAINT "contractor_pkey" PRIMARY KEY ("contractor_id")
);

-- CreateTable
CREATE TABLE "complaint" (
    "complaint_id" TEXT NOT NULL,
    "received_at" TIMESTAMP(0) NOT NULL,
    "channel" TEXT NOT NULL,
    "category_reported" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "language" TEXT,
    "locality_text" TEXT,
    "ward_code" TEXT,
    "lat" DOUBLE PRECISION,
    "lon" DOUBLE PRECISION,
    "gps_accuracy_m" DOUBLE PRECISION,
    "photo_url" TEXT,
    "photo_description" TEXT,
    "complainant_id" TEXT,
    "upvotes" INTEGER NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL,
    "resolved_at" TIMESTAMP(0),
    "source" TEXT NOT NULL DEFAULT 'import',

    CONSTRAINT "complaint_pkey" PRIMARY KEY ("complaint_id")
);

-- CreateTable
CREATE TABLE "social_post" (
    "post_id" TEXT NOT NULL,
    "posted_at" TIMESTAMP(0) NOT NULL,
    "source" TEXT NOT NULL,
    "author_handle" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "has_media" BOOLEAN NOT NULL,
    "likes_or_forwards" INTEGER NOT NULL,

    CONSTRAINT "social_post_pkey" PRIMARY KEY ("post_id")
);

-- CreateTable
CREATE TABLE "work_order" (
    "work_order_id" TEXT NOT NULL,
    "linked_complaint_ids" TEXT,
    "ward_code" TEXT NOT NULL,
    "road_id" TEXT NOT NULL,
    "work_type" TEXT NOT NULL,
    "repair_method" TEXT NOT NULL,
    "contractor_id" TEXT NOT NULL,
    "assigned_at" TIMESTAMP(0) NOT NULL,
    "work_started_at" TIMESTAMP(0),
    "completed_at" TIMESTAMP(0),
    "area_sqm" DOUBLE PRECISION NOT NULL,
    "cost_inr" INTEGER NOT NULL,
    "sla_hours" INTEGER,
    "sla_met" BOOLEAN,
    "reopened_within_30d" BOOLEAN,
    "engineer_remark" TEXT,
    "source" TEXT NOT NULL DEFAULT 'import',

    CONSTRAINT "work_order_pkey" PRIMARY KEY ("work_order_id")
);

-- CreateTable
CREATE TABLE "work_order_complaint" (
    "work_order_id" TEXT NOT NULL,
    "complaint_id" TEXT NOT NULL,

    CONSTRAINT "work_order_complaint_pkey" PRIMARY KEY ("work_order_id","complaint_id")
);

-- CreateTable
CREATE TABLE "road_proximity" (
    "road_id" TEXT NOT NULL,
    "near_hotspot_id" TEXT,
    "hotspot_tide_sensitive" BOOLEAN NOT NULL DEFAULT false,
    "hospital_entry_count" INTEGER NOT NULL DEFAULT 0,
    "school_count" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "road_proximity_pkey" PRIMARY KEY ("road_id")
);

-- CreateTable
CREATE TABLE "complaint_enriched" (
    "complaint_id" TEXT NOT NULL,
    "category_clean" TEXT NOT NULL,
    "severity" SMALLINT,
    "text_en" TEXT,
    "road_name_mentioned" TEXT,
    "ward_code_resolved" TEXT,
    "lat_resolved" DOUBLE PRECISION,
    "lon_resolved" DOUBLE PRECISION,
    "location_source" TEXT NOT NULL DEFAULT 'none',
    "road_id_resolved" TEXT,
    "issue_id" INTEGER,
    "model" TEXT,
    "enriched_at" TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "complaint_enriched_pkey" PRIMARY KEY ("complaint_id")
);

-- CreateTable
CREATE TABLE "issue" (
    "issue_id" SERIAL NOT NULL,
    "ward_code" TEXT NOT NULL,
    "road_id" TEXT,
    "category" TEXT NOT NULL,
    "severity" SMALLINT NOT NULL,
    "first_reported_at" TIMESTAMP(0) NOT NULL,
    "last_reported_at" TIMESTAMP(0) NOT NULL,
    "complaint_count" INTEGER NOT NULL,
    "upvotes_total" INTEGER NOT NULL DEFAULT 0,
    "work_order_id" TEXT,
    "state" TEXT NOT NULL,

    CONSTRAINT "issue_pkey" PRIMARY KEY ("issue_id")
);

-- CreateTable
CREATE TABLE "social_post_label" (
    "post_id" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "issue_id" INTEGER,
    "text_en" TEXT,

    CONSTRAINT "social_post_label_pkey" PRIMARY KEY ("post_id")
);

-- CreateTable
CREATE TABLE "summary" (
    "subject_type" TEXT NOT NULL,
    "subject_id" TEXT NOT NULL,
    "lang" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "facts_hash" TEXT NOT NULL,
    "generated_at" TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "summary_pkey" PRIMARY KEY ("subject_type","subject_id","lang")
);

-- CreateTable
CREATE TABLE "flag_decision" (
    "flag_type" TEXT NOT NULL,
    "work_order_id" TEXT NOT NULL,
    "decision" TEXT NOT NULL,
    "note" TEXT,
    "decided_by" INTEGER NOT NULL,
    "decided_at" TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "flag_decision_pkey" PRIMARY KEY ("flag_type","work_order_id")
);

-- CreateTable
CREATE TABLE "setting" (
    "key" TEXT NOT NULL,
    "value" DOUBLE PRECISION NOT NULL,
    "description" TEXT NOT NULL,

    CONSTRAINT "setting_pkey" PRIMARY KEY ("key")
);

-- CreateTable
CREATE TABLE "app_user" (
    "user_id" SERIAL NOT NULL,
    "username" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "role" TEXT NOT NULL,
    "ward_code" TEXT,
    "display_name" TEXT NOT NULL,

    CONSTRAINT "app_user_pkey" PRIMARY KEY ("user_id")
);

-- CreateIndex
CREATE INDEX "road_ward_code_idx" ON "road"("ward_code");

-- CreateIndex
CREATE INDEX "flood_hotspot_ward_code_idx" ON "flood_hotspot"("ward_code");

-- CreateIndex
CREATE INDEX "facility_ambulance_entry_road_idx" ON "facility"("ambulance_entry_road");

-- CreateIndex
CREATE INDEX "accident_road_id_idx" ON "accident"("road_id");

-- CreateIndex
CREATE INDEX "complaint_ward_code_idx" ON "complaint"("ward_code");

-- CreateIndex
CREATE INDEX "complaint_status_idx" ON "complaint"("status");

-- CreateIndex
CREATE INDEX "complaint_received_at_idx" ON "complaint"("received_at");

-- CreateIndex
CREATE INDEX "work_order_ward_code_idx" ON "work_order"("ward_code");

-- CreateIndex
CREATE INDEX "work_order_road_id_idx" ON "work_order"("road_id");

-- CreateIndex
CREATE INDEX "work_order_contractor_id_idx" ON "work_order"("contractor_id");

-- CreateIndex
CREATE INDEX "work_order_road_id_work_type_assigned_at_idx" ON "work_order"("road_id", "work_type", "assigned_at");

-- CreateIndex
CREATE INDEX "work_order_complaint_complaint_id_idx" ON "work_order_complaint"("complaint_id");

-- CreateIndex
CREATE INDEX "complaint_enriched_issue_id_idx" ON "complaint_enriched"("issue_id");

-- CreateIndex
CREATE INDEX "complaint_enriched_road_id_resolved_idx" ON "complaint_enriched"("road_id_resolved");

-- CreateIndex
CREATE UNIQUE INDEX "issue_work_order_id_key" ON "issue"("work_order_id");

-- CreateIndex
CREATE INDEX "issue_ward_code_idx" ON "issue"("ward_code");

-- CreateIndex
CREATE INDEX "issue_state_idx" ON "issue"("state");

-- CreateIndex
CREATE INDEX "issue_road_id_category_idx" ON "issue"("road_id", "category");

-- CreateIndex
CREATE UNIQUE INDEX "app_user_username_key" ON "app_user"("username");

-- AddForeignKey
ALTER TABLE "road" ADD CONSTRAINT "road_ward_code_fkey" FOREIGN KEY ("ward_code") REFERENCES "ward"("ward_code") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_order" ADD CONSTRAINT "work_order_ward_code_fkey" FOREIGN KEY ("ward_code") REFERENCES "ward"("ward_code") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_order" ADD CONSTRAINT "work_order_road_id_fkey" FOREIGN KEY ("road_id") REFERENCES "road"("road_id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_order" ADD CONSTRAINT "work_order_contractor_id_fkey" FOREIGN KEY ("contractor_id") REFERENCES "contractor"("contractor_id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_order" ADD CONSTRAINT "work_order_repair_method_fkey" FOREIGN KEY ("repair_method") REFERENCES "rate_card"("repair_method") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_order_complaint" ADD CONSTRAINT "work_order_complaint_work_order_id_fkey" FOREIGN KEY ("work_order_id") REFERENCES "work_order"("work_order_id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_order_complaint" ADD CONSTRAINT "work_order_complaint_complaint_id_fkey" FOREIGN KEY ("complaint_id") REFERENCES "complaint"("complaint_id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "complaint_enriched" ADD CONSTRAINT "complaint_enriched_complaint_id_fkey" FOREIGN KEY ("complaint_id") REFERENCES "complaint"("complaint_id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "complaint_enriched" ADD CONSTRAINT "complaint_enriched_issue_id_fkey" FOREIGN KEY ("issue_id") REFERENCES "issue"("issue_id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "issue" ADD CONSTRAINT "issue_work_order_id_fkey" FOREIGN KEY ("work_order_id") REFERENCES "work_order"("work_order_id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "flag_decision" ADD CONSTRAINT "flag_decision_work_order_id_fkey" FOREIGN KEY ("work_order_id") REFERENCES "work_order"("work_order_id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "flag_decision" ADD CONSTRAINT "flag_decision_decided_by_fkey" FOREIGN KEY ("decided_by") REFERENCES "app_user"("user_id") ON DELETE RESTRICT ON UPDATE CASCADE;
