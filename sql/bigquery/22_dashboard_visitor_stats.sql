-- View: dashboard_visitor_stats
-- Purpose: Home-run visitor summary used by the visitor map and related dashboard widgets.
-- This view mirrors the HomeRunMap.astro aggregation and adds a few reusable summary columns.

SELECT
	home_run_name,
	LOWER(TRIM(home_run_name)) AS normalized_home_run_name,
	COUNT(*) AS visit_count,
	COUNT(DISTINCT athlete_id) AS athlete_count,
	MIN(event_date) AS first_seen_date,
	MAX(event_date) AS last_seen_date
FROM `parkrun_data.results`
WHERE home_run_name IS NOT NULL
	AND home_run_name != ''
	AND is_unknown_athlete = FALSE
GROUP BY home_run_name
ORDER BY athlete_count DESC, visit_count DESC, home_run_name ASC;
