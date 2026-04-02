-- View: dashboard_headline_stats
-- Purpose: Aggregated metrics matching the logic in HeadlineStats.astro
-- This view replicates the dashboard query for consistency and ease of use.

SELECT
  total_parkrun_events,
  total_parkrun_finishers,
  parkrun_total_distance_km,
  parkrun_pct_to_moon,
  parkrun_total_finish_time_days,
  avg_parkrun_finishers_per_week,
  unique_athletes,
  unique_volunteers,
  parkrun_fastest_time,
  CASE
    WHEN avg_finish_seconds >= 3600 THEN
      FORMAT('%02d:%02d:%02d',
        CAST(DIV(CAST(ROUND(avg_finish_seconds) AS INT64), 3600) AS INT64),
        CAST(DIV(MOD(CAST(ROUND(avg_finish_seconds) AS INT64), 3600), 60) AS INT64),
        CAST(MOD(CAST(ROUND(avg_finish_seconds) AS INT64), 60) AS INT64)
      )
    ELSE
      FORMAT('%02d:%02d',
        CAST(DIV(CAST(ROUND(avg_finish_seconds) AS INT64), 60) AS INT64),
        CAST(MOD(CAST(ROUND(avg_finish_seconds) AS INT64), 60) AS INT64)
      )
  END AS parkrun_mean_time,
  parkrun_slowest_time,
  parkrun_genuine_pb_count,
  distinct_clubs
FROM (
  SELECT
    COUNT(DISTINCT run_id) as total_parkrun_events,
    COUNT(*) as total_parkrun_finishers,
    COUNT(*) * 5 as parkrun_total_distance_km,
    -- Percentage of the way to the moon (384,400 km)
    (COUNT(*) * 5) / 384400 * 100 as parkrun_pct_to_moon,
    SUM(
      CASE
        WHEN ARRAY_LENGTH(SPLIT(finish_time, ':')) = 3 THEN
          CAST(SPLIT(finish_time, ':')[OFFSET(0)] AS INT64) * 3600 +
          CAST(SPLIT(finish_time, ':')[OFFSET(1)] AS INT64) * 60 +
          CAST(SPLIT(finish_time, ':')[OFFSET(2)] AS INT64)
        WHEN ARRAY_LENGTH(SPLIT(finish_time, ':')) = 2 THEN
          CAST(SPLIT(finish_time, ':')[OFFSET(0)] AS INT64) * 60 +
          CAST(SPLIT(finish_time, ':')[OFFSET(1)] AS INT64)
        ELSE 0
      END
    ) / 86400 as parkrun_total_finish_time_days,
    AVG(
      CASE
        WHEN ARRAY_LENGTH(SPLIT(finish_time, ':')) = 3 THEN
          CAST(SPLIT(finish_time, ':')[OFFSET(0)] AS INT64) * 3600 +
          CAST(SPLIT(finish_time, ':')[OFFSET(1)] AS INT64) * 60 +
          CAST(SPLIT(finish_time, ':')[OFFSET(2)] AS INT64)
        WHEN ARRAY_LENGTH(SPLIT(finish_time, ':')) = 2 THEN
          CAST(SPLIT(finish_time, ':')[OFFSET(0)] AS INT64) * 60 +
          CAST(SPLIT(finish_time, ':')[OFFSET(1)] AS INT64)
        ELSE NULL
      END
    ) as avg_finish_seconds,
    COUNT(*) / NULLIF(COUNT(DISTINCT event_date), 0) as avg_parkrun_finishers_per_week,
    COUNT(DISTINCT athlete_id) as unique_athletes,
    (SELECT COUNT(DISTINCT IFNULL(athlete_id, 2214)) FROM `parkrun_data.volunteers`) as unique_volunteers,
    MIN(finish_time) as parkrun_fastest_time,
    MAX(finish_time) as parkrun_slowest_time,
    COUNTIF(was_genuine_pb = true) as parkrun_genuine_pb_count,
    COUNT(DISTINCT club_name) as distinct_clubs
  FROM `parkrun_data.results`
)