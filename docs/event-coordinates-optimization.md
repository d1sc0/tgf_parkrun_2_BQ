# Performance Optimization: Event Coordinates Caching

## Overview

The `HomeRunMap` component displays athlete visitor origins on an interactive map. Previously, it required fetching the external `events.json` file (~1-2MB) from the Parkrun API on every page load to match home run names to geographic coordinates.

This optimization caches event coordinates in BigQuery, eliminating the external API dependency and speeding up page load times.

## How It Works

1. **Sync Script** (`utilities/sync-event-coordinates.js`): Fetches `events.json` once and loads coordinates into a BigQuery table
2. **View Query** (`sql/bigquery/22_dashboard_visitor_stats.sql`): Joins visitor stats to cached coordinates using normalized name matching (`event_name` and `event_long_name` variants)
3. **Component Logic** (`dashboard/src/components/HomeRunMap.astro`): Reads coordinates directly from `_22_dashboard_visitor_stats` and plots only matched locations

## Setup Instructions

### Step 1: Ensure GCP Credentials

Make sure your environment has proper Google Cloud credentials:

```bash
export GOOGLE_CREDENTIALS_PATH=./service-account-key.json
# Optional fallback supported by sync script:
# export GOOGLE_APPLICATION_CREDENTIALS=./service-account-key.json
```

### Step 2: Sync Event Coordinates

Run the sync script to load coordinates into BigQuery:

```bash
npm run sync:coordinates
```

This will:

- Create the `event_coordinates` table in your BigQuery dataset
- Fetch all event coordinates from the Parkrun API
- Replace table contents using a BigQuery `WRITE_TRUNCATE` load job (safe to re-run)

Expected output:

```
Fetching event coordinates from parkrun events.json...
Fetched 2800+ event coordinates. Loading into BigQuery...
Successfully loaded XXXX event coordinates.
✅ Event coordinates sync completed successfully.
```

### Step 3: Publish Views

Publish SQL views so `_22_dashboard_visitor_stats` uses the latest coordinate-matching logic:

```bash
npm run publish:views
```

### Step 4: Verify

- The map component uses cached BigQuery coordinates (no external `events.json` call)
- Coordinate coverage can be validated with:

```sql
SELECT
  COUNT(*) AS total_rows,
  COUNTIF(latitude IS NOT NULL AND longitude IS NOT NULL) AS rows_with_coords
FROM `PROJECT.DATASET._22_dashboard_visitor_stats`;
```

- A small number of rows may remain unmatched for retired or renamed events that no longer exist in the current coordinate feed

## Benefits

✅ **Eliminates external API call** (~1-2MB download)  
✅ **Faster page loads** for HomeRunMap component  
✅ **Reduces request latency** and bandwidth  
✅ **More resilient** if Parkrun API is unavailable  
✅ **One-time sync** per environment

## Optimization Details

### Event Coordinates Table Schema

```
event_coordinates:
  - event_name (STRING): e.g., "Weymouth"
  - event_long_name (STRING): e.g., "Weymouth parkrun"
  - latitude (FLOAT64): Geographic latitude
  - longitude (FLOAT64): Geographic longitude
  - country (STRING): e.g., "GB"
  - last_updated (TIMESTAMP): When coordinates were synced
```

### View Behavior

**Before optimization:** HomeRunMap fetched external `events.json` during page render and matched client-side.  
**After optimization:** `_22_dashboard_visitor_stats` resolves coordinates in BigQuery and HomeRunMap renders directly from view output.

## Maintenance

Re-run `npm run sync:coordinates` periodically (e.g., monthly) if new parkrun events are added. This won't affect the dashboard—it just refreshes the coordinate cache.

## Troubleshooting

**Error: "Could not load the default credentials"**

- Set `GOOGLE_CREDENTIALS_PATH` in `.env` to a valid service-account key path
- Optional fallback: set `GOOGLE_APPLICATION_CREDENTIALS`

**Error: "Table event_coordinates was not found"**

- Run `npm run sync:coordinates` first to create and populate the table

**Map missing some locations**

- This usually means those `home_run_name` values cannot be matched to current coordinate-feed names
- Query `_22_dashboard_visitor_stats` for rows where latitude/longitude are null to inspect unmatched names
- For retired events, null coordinates are expected

## Related Files

- `utilities/sync-event-coordinates.js` — Sync script
- `sql/bigquery/22_dashboard_visitor_stats.sql` — View with active coordinate matching logic
- `dashboard/src/components/HomeRunMap.astro` — Component that renders mapped points from cached coordinates
- `package.json` — `npm run sync:coordinates` script
