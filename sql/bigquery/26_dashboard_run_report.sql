-- View: dashboard_run_report
-- Purpose: Per-run report data with current metrics, previous-run comparisons, and nested detail arrays.
-- This view generalizes the RunReport.astro query so every event is available via a single published view.

WITH parsed_results AS (
  SELECT
    run_id,
    event_date,
    first_name,
    last_name,
    finish_time,
    finish_position,
    age_category,
    age_grading,
    home_run_name,
    is_unknown_athlete,
    was_first_run_at_event,
    run_total,
    was_genuine_pb,
    CASE
      WHEN age_category LIKE 'M%' OR age_category LIKE 'JM%' OR age_category LIKE 'SM%' OR age_category LIKE 'VM%' THEN 'Male'
      ELSE 'Female'
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
    END AS finish_seconds
  FROM `parkrun_data.results`
),
all_runs AS (
  SELECT
    run_id,
    ANY_VALUE(event_date) AS event_date
  FROM parsed_results
  GROUP BY run_id
),
ordered_runs AS (
  SELECT
    run_id,
    event_date,
    LAG(run_id) OVER (ORDER BY event_date ASC) AS prev_run_id,
    LEAD(run_id) OVER (ORDER BY event_date ASC) AS next_run_id
  FROM all_runs
),
volunteer_counts AS (
  SELECT
    run_id,
    COUNT(DISTINCT athlete_id) AS volunteers
  FROM `parkrun_data.volunteers`
  GROUP BY run_id
),
run_metrics AS (
  SELECT
    p.run_id,
    ANY_VALUE(p.event_date) AS event_date,
    COUNT(*) AS finishers,
    COUNTIF(p.was_first_run_at_event = TRUE AND p.is_unknown_athlete = FALSE) AS first_timers,
    COUNTIF(p.run_total = 1 AND p.is_unknown_athlete = FALSE) AS new_parkrunners,
    COUNTIF(p.was_genuine_pb = TRUE) AS pbs,
    COUNTIF(p.is_unknown_athlete = TRUE) AS unknowns,
    IFNULL(MAX(v.volunteers), 0) AS volunteers,
    MIN(p.finish_seconds) AS fastest_s,
    MAX(p.finish_seconds) AS slowest_s,
    AVG(p.finish_seconds) AS mean_s
  FROM parsed_results p
  LEFT JOIN volunteer_counts v
    ON p.run_id = v.run_id
  GROUP BY p.run_id
),
first_finishers_ranked AS (
  SELECT
    run_id,
    first_name,
    last_name,
    finish_time,
    age_grading,
    finish_position,
    gender,
    ROW_NUMBER() OVER (
      PARTITION BY run_id, gender
      ORDER BY finish_position ASC
    ) AS rn
  FROM parsed_results
  WHERE finish_position IS NOT NULL
),
first_finishers_array AS (
  SELECT
    run_id,
    ARRAY_AGG(
      STRUCT(gender, first_name, last_name, finish_time, age_grading, finish_position)
      ORDER BY finish_position ASC
    ) AS first_finishers
  FROM first_finishers_ranked
  WHERE rn = 1
  GROUP BY run_id
),
distribution AS (
  SELECT
    run_id,
    CAST(
      FLOOR(
        CASE
          WHEN ARRAY_LENGTH(SPLIT(finish_time, ':')) = 3 THEN
            SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(0)] AS INT64) * 60
            + SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(1)] AS INT64)
          WHEN ARRAY_LENGTH(SPLIT(finish_time, ':')) = 2 THEN
            SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(0)] AS INT64)
          ELSE 0
        END
      ) AS INT64
    ) AS minute_bucket,
    COUNT(*) AS count
  FROM parsed_results
  WHERE finish_time IS NOT NULL
    AND finish_time != ''
  GROUP BY run_id, minute_bucket
),
distribution_array AS (
  SELECT
    run_id,
    ARRAY_AGG(STRUCT(minute_bucket, count) ORDER BY minute_bucket ASC) AS distribution
  FROM distribution
  GROUP BY run_id
),
top_age_grades_ranked AS (
  SELECT
    run_id,
    first_name,
    last_name,
    age_grading,
    finish_time,
    age_category,
    ROW_NUMBER() OVER (
      PARTITION BY run_id
      ORDER BY age_grading DESC, finish_position ASC
    ) AS rn
  FROM parsed_results
  WHERE age_grading IS NOT NULL
),
top_age_grades_array AS (
  SELECT
    run_id,
    ARRAY_AGG(
      STRUCT(first_name, last_name, age_grading, finish_time, age_category)
      ORDER BY age_grading DESC
    ) AS top_age_grades
  FROM top_age_grades_ranked
  WHERE rn <= 5
  GROUP BY run_id
),
visitors_ranked AS (
  SELECT
    run_id,
    home_run_name,
    COUNT(*) AS count,
    ROW_NUMBER() OVER (
      PARTITION BY run_id
      ORDER BY COUNT(*) DESC, home_run_name ASC
    ) AS rn
  FROM parsed_results
  WHERE home_run_name IS NOT NULL
    AND home_run_name != ''
    AND home_run_name != 'The Great Field parkrun'
    AND is_unknown_athlete = FALSE
  GROUP BY run_id, home_run_name
),
visitors_array AS (
  SELECT
    run_id,
    ARRAY_AGG(STRUCT(home_run_name, count) ORDER BY count DESC, home_run_name ASC) AS visitors
  FROM visitors_ranked
  WHERE rn <= 15
  GROUP BY run_id
)
SELECT
  o.run_id,
  o.event_date,
  o.prev_run_id,
  o.next_run_id,
  m.finishers,
  m.first_timers,
  m.new_parkrunners,
  m.pbs,
  m.unknowns,
  m.volunteers,
  m.fastest_s,
  m.slowest_s,
  m.mean_s,
  CASE
    WHEN m.fastest_s >= 3600 THEN FORMAT(
      '%02d:%02d:%02d',
      CAST(DIV(m.fastest_s, 3600) AS INT64),
      CAST(DIV(MOD(m.fastest_s, 3600), 60) AS INT64),
      CAST(MOD(m.fastest_s, 60) AS INT64)
    )
    ELSE FORMAT(
      '%02d:%02d',
      CAST(DIV(m.fastest_s, 60) AS INT64),
      CAST(MOD(m.fastest_s, 60) AS INT64)
    )
  END AS fastest_time,
  CASE
    WHEN m.slowest_s >= 3600 THEN FORMAT(
      '%02d:%02d:%02d',
      CAST(DIV(m.slowest_s, 3600) AS INT64),
      CAST(DIV(MOD(m.slowest_s, 3600), 60) AS INT64),
      CAST(MOD(m.slowest_s, 60) AS INT64)
    )
    ELSE FORMAT(
      '%02d:%02d',
      CAST(DIV(m.slowest_s, 60) AS INT64),
      CAST(MOD(m.slowest_s, 60) AS INT64)
    )
  END AS slowest_time,
  CASE
    WHEN m.mean_s >= 3600 THEN FORMAT(
      '%02d:%02d:%02d',
      CAST(DIV(CAST(ROUND(m.mean_s) AS INT64), 3600) AS INT64),
      CAST(DIV(MOD(CAST(ROUND(m.mean_s) AS INT64), 3600), 60) AS INT64),
      CAST(MOD(CAST(ROUND(m.mean_s) AS INT64), 60) AS INT64)
    )
    ELSE FORMAT(
      '%02d:%02d',
      CAST(DIV(CAST(ROUND(m.mean_s) AS INT64), 60) AS INT64),
      CAST(MOD(CAST(ROUND(m.mean_s) AS INT64), 60) AS INT64)
    )
  END AS mean_time,
  prev.finishers AS previous_finishers,
  prev.first_timers AS previous_first_timers,
  prev.new_parkrunners AS previous_new_parkrunners,
  prev.pbs AS previous_pbs,
  prev.unknowns AS previous_unknowns,
  prev.volunteers AS previous_volunteers,
  prev.fastest_s AS previous_fastest_s,
  prev.slowest_s AS previous_slowest_s,
  prev.mean_s AS previous_mean_s,
  IFNULL(ff.first_finishers, []) AS first_finishers,
  IFNULL(d.distribution, []) AS distribution,
  IFNULL(tag.top_age_grades, []) AS top_age_grades,
  IFNULL(v.visitors, []) AS visitors
FROM ordered_runs o
LEFT JOIN run_metrics m
  ON o.run_id = m.run_id
LEFT JOIN run_metrics prev
  ON o.prev_run_id = prev.run_id
LEFT JOIN first_finishers_array ff
  ON o.run_id = ff.run_id
LEFT JOIN distribution_array d
  ON o.run_id = d.run_id
LEFT JOIN top_age_grades_array tag
  ON o.run_id = tag.run_id
LEFT JOIN visitors_array v
  ON o.run_id = v.run_id
ORDER BY o.event_date DESC;