-- View: dashboard_course_records
-- Purpose: Record tables for overall, male, female, and age-category course records.
-- This view expands the Records.astro logic into a reusable, non-parameterized dataset.

WITH parsed_results AS (
	SELECT
		athlete_id,
		first_name,
		last_name,
		finish_time,
		event_date,
		run_id,
		age_category,
		age_grading,
		CASE
			WHEN age_category LIKE 'W%' OR age_category LIKE 'JW%' OR age_category LIKE 'SW%' OR age_category LIKE 'VW%' THEN 'Female'
			WHEN age_category LIKE 'M%' OR age_category LIKE 'JM%' OR age_category LIKE 'SM%' OR age_category LIKE 'VM%' THEN 'Male'
			ELSE 'Unknown'
		END AS gender,
		CASE
			WHEN ARRAY_LENGTH(SPLIT(finish_time, ':')) = 3 THEN
				SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(0)] AS INT64) * 3600
				+ SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(1)] AS INT64) * 60
				+ SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(2)] AS INT64)
			WHEN ARRAY_LENGTH(SPLIT(finish_time, ':')) = 2 THEN
				SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(0)] AS INT64) * 60
				+ SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(1)] AS INT64)
			ELSE NULL
		END AS pb_seconds
	FROM `parkrun_data.results`
	WHERE is_unknown_athlete = FALSE
		AND finish_time IS NOT NULL
		AND finish_time != ''
),
athlete_pbs AS (
	SELECT
		athlete_id,
		first_name,
		last_name,
		finish_time AS pb_time,
		pb_seconds,
		age_grading AS best_grading,
		event_date AS pb_date,
		run_id,
		age_category,
		gender,
		ROW_NUMBER() OVER (
			PARTITION BY athlete_id
			ORDER BY pb_seconds ASC, event_date ASC
		) AS pb_rn
	FROM parsed_results
	WHERE pb_seconds IS NOT NULL
),
pb_records AS (
	SELECT *
	FROM athlete_pbs
	WHERE pb_rn = 1
),
overall_ranked AS (
	SELECT
		'overall' AS record_scope,
		CAST(NULL AS STRING) AS scope_value,
		athlete_id,
		first_name,
		last_name,
		pb_time,
		pb_seconds,
		best_grading,
		pb_date,
		run_id,
		age_category,
		gender,
		ROW_NUMBER() OVER (ORDER BY pb_seconds ASC, pb_date ASC) AS rank
	FROM pb_records
),
male_ranked AS (
	SELECT
		'male' AS record_scope,
		CAST(NULL AS STRING) AS scope_value,
		athlete_id,
		first_name,
		last_name,
		pb_time,
		pb_seconds,
		best_grading,
		pb_date,
		run_id,
		age_category,
		gender,
		ROW_NUMBER() OVER (ORDER BY pb_seconds ASC, pb_date ASC) AS rank
	FROM pb_records
	WHERE gender = 'Male'
),
female_ranked AS (
	SELECT
		'female' AS record_scope,
		CAST(NULL AS STRING) AS scope_value,
		athlete_id,
		first_name,
		last_name,
		pb_time,
		pb_seconds,
		best_grading,
		pb_date,
		run_id,
		age_category,
		gender,
		ROW_NUMBER() OVER (ORDER BY pb_seconds ASC, pb_date ASC) AS rank
	FROM pb_records
	WHERE gender = 'Female'
),
category_ranked AS (
	SELECT
		'category' AS record_scope,
		age_category AS scope_value,
		athlete_id,
		first_name,
		last_name,
		pb_time,
		pb_seconds,
		best_grading,
		pb_date,
		run_id,
		age_category,
		gender,
		ROW_NUMBER() OVER (
			PARTITION BY age_category
			ORDER BY pb_seconds ASC, pb_date ASC
		) AS rank
	FROM pb_records
	WHERE age_category IS NOT NULL
		AND age_category != ''
)
SELECT *
FROM overall_ranked
WHERE rank <= 10

UNION ALL

SELECT *
FROM male_ranked
WHERE rank <= 10

UNION ALL

SELECT *
FROM female_ranked
WHERE rank <= 10

UNION ALL

SELECT *
FROM category_ranked
WHERE rank <= 10

ORDER BY record_scope, scope_value, rank;
