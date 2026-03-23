-- Set this parameter in BigQuery UI before running:
-- @target_event_number INT64

WITH latest_run AS (
  SELECT MAX(run_id) AS run_id
  FROM parkrun_data.results
  WHERE event_number = @target_event_number
),
res AS (
  SELECT COUNT(*) AS results_rows, COUNT(DISTINCT athlete_id) AS results_athletes
  FROM parkrun_data.results
  WHERE event_number = @target_event_number
    AND run_id = (SELECT run_id FROM latest_run)
),
vol AS (
  SELECT COUNT(*) AS volunteer_rows, COUNT(DISTINCT athlete_id) AS volunteer_athletes
  FROM parkrun_data.volunteers
  WHERE event_number = @target_event_number
    AND run_id = (SELECT run_id FROM latest_run)
)
SELECT
  (SELECT run_id FROM latest_run) AS latest_run_id,
  res.results_rows,
  res.results_athletes,
  vol.volunteer_rows,
  vol.volunteer_athletes
FROM res, vol;
