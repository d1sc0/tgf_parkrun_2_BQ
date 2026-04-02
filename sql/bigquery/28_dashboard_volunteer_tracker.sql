-- View: dashboard_volunteer_tracker
-- Purpose: Volunteer credits, roles, and finisher totals by event.
-- This view mirrors the VolunteerTracker.astro query.

WITH event_finishers AS (
  SELECT
    run_id,
    COUNT(*) AS total_finishers
  FROM `parkrun_data.results`
  GROUP BY run_id
)
SELECT
  v.event_date,
  v.run_id,
  v.task_name,
  v.athlete_id,
  EXTRACT(YEAR FROM v.event_date) AS year,
  f.total_finishers
FROM `parkrun_data.volunteers` v
LEFT JOIN event_finishers f
  ON v.run_id = f.run_id
ORDER BY v.event_date ASC, v.run_id ASC, v.task_name ASC;