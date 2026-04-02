-- View: dashboard_attendance_tracker
-- Purpose: Attendance breakdown by event, gender, and age grouping.
-- This view mirrors the AttendanceTracker.astro query so the same dataset can be reused as a published view.

SELECT
  event_date,
  run_id,
  CASE
    WHEN age_category LIKE 'W%' OR age_category LIKE 'JW%' OR age_category LIKE 'SW%' OR age_category LIKE 'VW%' THEN 'Female'
    WHEN age_category LIKE 'M%' OR age_category LIKE 'JM%' OR age_category LIKE 'SM%' OR age_category LIKE 'VM%' THEN 'Male'
    ELSE 'Unknown'
  END AS gender,
  CASE
    WHEN age_category LIKE 'J%' THEN 'Junior'
    WHEN age_category LIKE 'S%' THEN 'Senior'
    WHEN age_category LIKE 'V%' THEN 'Veteran'
    ELSE 'Other'
  END AS age_group,
  age_category,
  COUNT(*) AS finishers
FROM `parkrun_data.results`
GROUP BY event_date, run_id, gender, age_group, age_category
ORDER BY event_date ASC, run_id ASC, gender ASC, age_group ASC, age_category ASC;