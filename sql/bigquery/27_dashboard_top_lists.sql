-- View: dashboard_top_lists
-- Purpose: Nested top-list datasets matching the TopLists.astro component.
-- This view returns a single row with one array field per rendered leaderboard.

WITH parsed_results AS (
  SELECT
    athlete_id,
    first_name,
    last_name,
    run_id,
    event_date,
    finish_time,
    age_category,
    club_name,
    is_unknown_athlete,
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
    END AS finish_seconds
  FROM `parkrun_data.results`
),
athlete_base AS (
  SELECT
    athlete_id,
    ANY_VALUE(CONCAT(first_name, ' ', last_name)) AS athlete_name,
    COUNT(DISTINCT run_id) AS total_runs,
    ANY_VALUE(gender) AS gender
  FROM parsed_results
  WHERE is_unknown_athlete = FALSE
  GROUP BY athlete_id
),
volunteer_appearances AS (
  SELECT
    athlete_id,
    COUNT(DISTINCT event_date) AS vol_appearances
  FROM `parkrun_data.volunteers`
  GROUP BY athlete_id
),
athlete_fastest_ranked AS (
  SELECT
    athlete_id,
    finish_time,
    event_date,
    run_id,
    finish_seconds,
    ROW_NUMBER() OVER (
      PARTITION BY athlete_id
      ORDER BY finish_seconds ASC, event_date ASC
    ) AS rn
  FROM parsed_results
  WHERE is_unknown_athlete = FALSE
    AND finish_seconds IS NOT NULL
),
athlete_fastest AS (
  SELECT *
  FROM athlete_fastest_ranked
  WHERE rn = 1
),
volunteer_base AS (
  SELECT
    athlete_id,
    ANY_VALUE(CONCAT(first_name, ' ', last_name)) AS vol_name,
    COUNT(DISTINCT event_date) AS appearances
  FROM `parkrun_data.volunteers`
  WHERE athlete_id != 2214
  GROUP BY athlete_id
),
volunteer_run_stats AS (
  SELECT
    athlete_id,
    NULLIF(COUNT(DISTINCT run_id), 0) AS total_runs,
    MIN(finish_seconds) AS fastest_s
  FROM parsed_results
  WHERE is_unknown_athlete = FALSE
  GROUP BY athlete_id
),
event_aggs AS (
  SELECT
    run_id,
    event_date,
    COUNT(*) AS value,
    MIN(finish_seconds) AS fastest_s,
    AVG(finish_seconds) AS mean_s,
    MAX(finish_seconds) AS slowest_s
  FROM parsed_results
  WHERE finish_seconds IS NOT NULL
  GROUP BY run_id, event_date
),
club_base AS (
  SELECT
    club_name AS label,
    COUNT(*) AS value
  FROM parsed_results
  WHERE club_name IS NOT NULL
    AND club_name != ''
    AND LOWER(club_name) != 'unattached'
  GROUP BY club_name
),
club_finishers_ranked AS (
  SELECT
    club_name,
    gender,
    CONCAT(first_name, ' ', last_name) AS athlete_name,
    finish_time,
    finish_seconds,
    ROW_NUMBER() OVER (
      PARTITION BY club_name, gender
      ORDER BY finish_seconds ASC, first_name ASC, last_name ASC
    ) AS rn
  FROM parsed_results
  WHERE club_name IS NOT NULL
    AND club_name != ''
    AND LOWER(club_name) != 'unattached'
    AND finish_seconds IS NOT NULL
    AND gender IN ('Male', 'Female')
)
SELECT
  ARRAY(
    SELECT AS STRUCT
      vb.vol_name AS label,
      vb.appearances AS value,
      vrs.total_runs AS run_count,
      CASE
        WHEN vrs.fastest_s IS NULL THEN NULL
        WHEN vrs.fastest_s >= 3600 THEN FORMAT(
          '%02d:%02d:%02d',
          CAST(DIV(vrs.fastest_s, 3600) AS INT64),
          CAST(DIV(MOD(vrs.fastest_s, 3600), 60) AS INT64),
          CAST(MOD(vrs.fastest_s, 60) AS INT64)
        )
        ELSE FORMAT(
          '%02d:%02d',
          CAST(DIV(vrs.fastest_s, 60) AS INT64),
          CAST(MOD(vrs.fastest_s, 60) AS INT64)
        )
      END AS fastest_time
    FROM volunteer_base vb
    LEFT JOIN volunteer_run_stats vrs
      ON vb.athlete_id = vrs.athlete_id
    ORDER BY value DESC, label ASC
    LIMIT 20
  ) AS volunteers,
  ARRAY(
    SELECT AS STRUCT
      CAST(ea.event_date AS STRING) AS label,
      ea.value,
      ea.run_id,
      CASE
        WHEN ea.fastest_s IS NULL THEN NULL
        WHEN ea.fastest_s >= 3600 THEN FORMAT(
          '%02d:%02d:%02d',
          CAST(DIV(ea.fastest_s, 3600) AS INT64),
          CAST(DIV(MOD(ea.fastest_s, 3600), 60) AS INT64),
          CAST(MOD(ea.fastest_s, 60) AS INT64)
        )
        ELSE FORMAT('%02d:%02d', CAST(DIV(ea.fastest_s, 60) AS INT64), CAST(MOD(ea.fastest_s, 60) AS INT64))
      END AS fastest_time,
      CASE
        WHEN ea.mean_s IS NULL THEN NULL
        WHEN ea.mean_s >= 3600 THEN FORMAT(
          '%02d:%02d:%02d',
          CAST(DIV(CAST(ROUND(ea.mean_s) AS INT64), 3600) AS INT64),
          CAST(DIV(MOD(CAST(ROUND(ea.mean_s) AS INT64), 3600), 60) AS INT64),
          CAST(MOD(CAST(ROUND(ea.mean_s) AS INT64), 60) AS INT64)
        )
        ELSE FORMAT('%02d:%02d', CAST(DIV(CAST(ROUND(ea.mean_s) AS INT64), 60) AS INT64), CAST(MOD(CAST(ROUND(ea.mean_s) AS INT64), 60) AS INT64))
      END AS mean_time,
      CASE
        WHEN ea.slowest_s IS NULL THEN NULL
        WHEN ea.slowest_s >= 3600 THEN FORMAT(
          '%02d:%02d:%02d',
          CAST(DIV(ea.slowest_s, 3600) AS INT64),
          CAST(DIV(MOD(ea.slowest_s, 3600), 60) AS INT64),
          CAST(MOD(ea.slowest_s, 60) AS INT64)
        )
        ELSE FORMAT('%02d:%02d', CAST(DIV(ea.slowest_s, 60) AS INT64), CAST(MOD(ea.slowest_s, 60) AS INT64))
      END AS slowest_time
    FROM event_aggs ea
    ORDER BY ea.value DESC, ea.run_id DESC
    LIMIT 20
  ) AS events,
  ARRAY(
    SELECT AS STRUCT
      a.athlete_name AS label,
      a.total_runs AS value,
      f.finish_time AS fastest_time,
      CAST(f.event_date AS STRING) AS fastest_date,
      f.run_id AS fastest_run_id,
      IFNULL(v.vol_appearances, 0) AS vol_count
    FROM athlete_base a
    LEFT JOIN volunteer_appearances v
      ON a.athlete_id = v.athlete_id
    LEFT JOIN athlete_fastest f
      ON a.athlete_id = f.athlete_id
    ORDER BY a.total_runs DESC, a.athlete_name ASC
    LIMIT 20
  ) AS athletes,
  ARRAY(
    SELECT AS STRUCT
      a.athlete_name AS label,
      a.total_runs AS value,
      f.finish_time AS fastest_time,
      CAST(f.event_date AS STRING) AS fastest_date,
      f.run_id AS fastest_run_id,
      IFNULL(v.vol_appearances, 0) AS vol_count
    FROM athlete_base a
    LEFT JOIN volunteer_appearances v
      ON a.athlete_id = v.athlete_id
    LEFT JOIN athlete_fastest f
      ON a.athlete_id = f.athlete_id
    WHERE a.gender = 'Male'
    ORDER BY a.total_runs DESC, a.athlete_name ASC
    LIMIT 20
  ) AS athletes_male,
  ARRAY(
    SELECT AS STRUCT
      a.athlete_name AS label,
      a.total_runs AS value,
      f.finish_time AS fastest_time,
      CAST(f.event_date AS STRING) AS fastest_date,
      f.run_id AS fastest_run_id,
      IFNULL(v.vol_appearances, 0) AS vol_count
    FROM athlete_base a
    LEFT JOIN volunteer_appearances v
      ON a.athlete_id = v.athlete_id
    LEFT JOIN athlete_fastest f
      ON a.athlete_id = f.athlete_id
    WHERE a.gender = 'Female'
    ORDER BY a.total_runs DESC, a.athlete_name ASC
    LIMIT 20
  ) AS athletes_female,
  ARRAY(
    SELECT AS STRUCT
      cb.label,
      cb.value,
      fm.athlete_name AS fastest_male_name,
      fm.finish_time AS fastest_male_time,
      ff.athlete_name AS fastest_female_name,
      ff.finish_time AS fastest_female_time
    FROM club_base cb
    LEFT JOIN club_finishers_ranked fm
      ON cb.label = fm.club_name
      AND fm.gender = 'Male'
      AND fm.rn = 1
    LEFT JOIN club_finishers_ranked ff
      ON cb.label = ff.club_name
      AND ff.gender = 'Female'
      AND ff.rn = 1
    ORDER BY cb.value DESC, cb.label ASC
    LIMIT 20
  ) AS clubs;