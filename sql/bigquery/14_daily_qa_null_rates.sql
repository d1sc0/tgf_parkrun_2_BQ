WITH checks AS (
  SELECT
    'results' AS table_name,
    COUNT(*) AS total_rows,
    COUNTIF(athlete_id IS NULL) AS null_athlete_id,
    COUNTIF(event_date IS NULL) AS null_event_date,
    COUNTIF(run_id IS NULL) AS null_run_id,
    COUNTIF(finish_time IS NULL) AS null_finish_time,
    COUNTIF(first_name IS NULL AND last_name IS NULL) AS null_name
  FROM parkrun_data.results

  UNION ALL

  SELECT
    'junior_results',
    COUNT(*),
    COUNTIF(athlete_id IS NULL),
    COUNTIF(event_date IS NULL),
    COUNTIF(run_id IS NULL),
    COUNTIF(finish_time IS NULL),
    COUNTIF(first_name IS NULL AND last_name IS NULL)
  FROM parkrun_data.junior_results

  UNION ALL

  SELECT
    'volunteers',
    COUNT(*),
    COUNTIF(athlete_id IS NULL),
    COUNTIF(event_date IS NULL),
    COUNTIF(run_id IS NULL),
    CAST(NULL AS INT64) AS null_finish_time,
    COUNTIF(first_name IS NULL AND last_name IS NULL)
  FROM parkrun_data.volunteers

  UNION ALL

  SELECT
    'junior_volunteers',
    COUNT(*),
    COUNTIF(athlete_id IS NULL),
    COUNTIF(event_date IS NULL),
    COUNTIF(run_id IS NULL),
    CAST(NULL AS INT64) AS null_finish_time,
    COUNTIF(first_name IS NULL AND last_name IS NULL)
  FROM parkrun_data.junior_volunteers
)
SELECT
  table_name,
  total_rows,
  null_athlete_id,
  ROUND(SAFE_DIVIDE(null_athlete_id, total_rows) * 100, 2) AS pct_null_athlete_id,
  null_event_date,
  ROUND(SAFE_DIVIDE(null_event_date, total_rows) * 100, 2) AS pct_null_event_date,
  null_run_id,
  ROUND(SAFE_DIVIDE(null_run_id, total_rows) * 100, 2) AS pct_null_run_id,
  null_finish_time,
  null_name
FROM checks
ORDER BY table_name;
