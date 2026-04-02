-- View: dashboard_volunteer_milestones
-- Purpose: Volunteer milestone tracker with next-target calculations and progress percentages.
-- This view matches the VolunteerMilestones.astro data requirements.

WITH volunteer_summary AS (
	SELECT
		athlete_id,
		ANY_VALUE(first_name) AS first_name,
		ANY_VALUE(last_name) AS last_name,
		COUNT(DISTINCT event_date) AS vol_table_count,
		MAX(event_date) AS last_vol_date,
		ARRAY_AGG(run_id ORDER BY event_date DESC LIMIT 1)[OFFSET(0)] AS last_run_id
	FROM `parkrun_data.volunteers`
	WHERE athlete_id IS NOT NULL
		AND athlete_id != 2214
	GROUP BY athlete_id
),
result_summary AS (
	SELECT
		athlete_id,
		MAX(vol_count) AS highest_vol_results
	FROM `parkrun_data.results`
	WHERE athlete_id IS NOT NULL
		AND athlete_id != 2214
	GROUP BY athlete_id
),
volunteer_counts AS (
	SELECT
		v.athlete_id,
		v.first_name,
		v.last_name,
		v.last_vol_date,
		v.last_run_id,
		GREATEST(v.vol_table_count, IFNULL(r.highest_vol_results, 0)) AS current_count
	FROM volunteer_summary v
	LEFT JOIN result_summary r
		ON v.athlete_id = r.athlete_id
	WHERE GREATEST(v.vol_table_count, IFNULL(r.highest_vol_results, 0)) > 5
),
milestones AS (
	SELECT milestone
	FROM UNNEST([10, 25, 50, 100, 250, 500]) AS milestone
),
next_milestone AS (
	SELECT
		v.athlete_id,
		v.first_name,
		v.last_name,
		v.current_count,
		v.last_vol_date,
		v.last_run_id,
		MIN(m.milestone) AS next_milestone
	FROM volunteer_counts v
	INNER JOIN milestones m
		ON m.milestone > v.current_count
	GROUP BY
		v.athlete_id,
		v.first_name,
		v.last_name,
		v.current_count,
		v.last_vol_date,
		v.last_run_id
)
SELECT
	athlete_id,
	first_name,
	last_name,
	current_count,
	last_vol_date,
	last_run_id,
	next_milestone,
	next_milestone.next_milestone - current_count AS remaining,
	ROUND(current_count / next_milestone.next_milestone * 100) AS progress_pct
FROM next_milestone
ORDER BY last_vol_date DESC, remaining ASC
LIMIT 100;
