-- View: dashboard_performance_tracker
-- Purpose: Per-event performance metrics grouped so the UI can re-aggregate by gender and age filters.
-- This view mirrors the PerformanceTracker.astro query.

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
  MIN(
    CASE
      WHEN ARRAY_LENGTH(SPLIT(finish_time, ':')) = 3 THEN
        SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(0)] AS INT64) * 3600
        + SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(1)] AS INT64) * 60
        + SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(2)] AS INT64)
      WHEN ARRAY_LENGTH(SPLIT(finish_time, ':')) = 2 THEN
        SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(0)] AS INT64) * 60
        + SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(1)] AS INT64)
      ELSE NULL
    END
  ) AS fastest_seconds,
  AVG(
    CASE
      WHEN ARRAY_LENGTH(SPLIT(finish_time, ':')) = 3 THEN
        SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(0)] AS INT64) * 3600
        + SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(1)] AS INT64) * 60
        + SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(2)] AS INT64)
      WHEN ARRAY_LENGTH(SPLIT(finish_time, ':')) = 2 THEN
        SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(0)] AS INT64) * 60
        + SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(1)] AS INT64)
      ELSE NULL
    END
  ) AS average_seconds,
  MAX(
    CASE
      WHEN ARRAY_LENGTH(SPLIT(finish_time, ':')) = 3 THEN
        SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(0)] AS INT64) * 3600
        + SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(1)] AS INT64) * 60
        + SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(2)] AS INT64)
      WHEN ARRAY_LENGTH(SPLIT(finish_time, ':')) = 2 THEN
        SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(0)] AS INT64) * 60
        + SAFE_CAST(SPLIT(finish_time, ':')[OFFSET(1)] AS INT64)
      ELSE NULL
    END
  ) AS slowest_seconds,
  COUNT(*) AS finishers
FROM `parkrun_data.results`
WHERE finish_time IS NOT NULL
  AND finish_time != ''
GROUP BY event_date, run_id, gender, age_group, age_category
ORDER BY event_date ASC, run_id ASC, gender ASC, age_group ASC, age_category ASC;