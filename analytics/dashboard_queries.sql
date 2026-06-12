-- ============================================================
-- MINIVO ANALYTICS DASHBOARD QUERIES
-- Dataset: puzzloragames-minivo.analytics_534840822
-- Region: us (multi-region)
-- Note: All queries use _TABLE_SUFFIX filter for cost control.
--       Adjust INTERVAL 90 DAY to your desired lookback window.
-- ============================================================


-- ============================================================
-- 1. RETENTION & ENGAGEMENT
-- ============================================================

-- 1a. Daily Active Users (DAU)
-- How many unique users open the app each day?
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS date,
  COUNT(DISTINCT user_pseudo_id) AS dau
FROM `puzzloragames-minivo.analytics_534840822.events_*`
WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
  AND event_name = 'session_start'
GROUP BY date
ORDER BY date DESC;


-- 1b. Average sessions per user per day
-- Are users opening the app multiple times a day?
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS date,
  COUNT(*) * 1.0 / COUNT(DISTINCT user_pseudo_id) AS avg_sessions_per_user
FROM `puzzloragames-minivo.analytics_534840822.events_*`
WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
  AND event_name = 'session_start'
GROUP BY date
ORDER BY date DESC;


-- 1c. Average session duration (seconds) — aggregated per session
-- How long are users spending per session?
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS date,
  AVG(session_engagement_sec) AS avg_session_sec
FROM (
  SELECT
    event_date,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    SUM((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'engagement_time_msec')) / 1000.0 AS session_engagement_sec
  FROM `puzzloragames-minivo.analytics_534840822.events_*`
  WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
    AND event_name = 'user_engagement'
  GROUP BY event_date, user_pseudo_id, session_id
)
GROUP BY date
ORDER BY date DESC;


-- ============================================================
-- 2. USER GROWTH
-- ============================================================

-- 2a. New users per day
-- How many users installed the app each day?
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS date,
  COUNT(DISTINCT user_pseudo_id) AS new_users
FROM `puzzloragames-minivo.analytics_534840822.events_*`
WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
  AND event_name = 'first_open'
GROUP BY date
ORDER BY date DESC;


-- 2b. New users by country
-- Where are your users coming from?
SELECT
  geo.country AS country,
  COUNT(DISTINCT user_pseudo_id) AS new_users
FROM `puzzloragames-minivo.analytics_534840822.events_*`
WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
  AND event_name = 'first_open'
GROUP BY country
ORDER BY new_users DESC;


-- 2c. Last active time per user with device info
-- When did each user last open the app?
SELECT
  user_pseudo_id,
  brand,
  model,
  os,
  country,
  city,
  last_app_open
FROM (
  SELECT
    user_pseudo_id,
    device.mobile_brand_name AS brand,
    device.mobile_model_name AS model,
    device.operating_system AS os,
    geo.country AS country,
    geo.city AS city,
    TIMESTAMP_MICROS(event_timestamp) AS last_app_open,
    ROW_NUMBER() OVER (
      PARTITION BY user_pseudo_id
      ORDER BY event_timestamp DESC
    ) AS rn
  FROM `puzzloragames-minivo.analytics_534840822.events_*`
  WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
    AND event_name = 'session_start'
)
WHERE rn = 1
ORDER BY last_app_open DESC;


-- ============================================================
-- 3. GAME PERFORMANCE
-- ============================================================

-- 3a. Most played games (all time)
-- Which games are most popular?
SELECT
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'game_id') AS game_id,
  COUNT(*) AS play_count,
  COUNT(DISTINCT user_pseudo_id) AS unique_players
FROM `puzzloragames-minivo.analytics_534840822.events_*`
WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
  AND event_name = 'game_start'
GROUP BY game_id
ORDER BY play_count DESC;


-- 3b. Games played by country
-- Which games are popular in which countries?
SELECT
  geo.country AS country,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'game_id') AS game_id,
  COUNT(*) AS play_count
FROM `puzzloragames-minivo.analytics_534840822.events_*`
WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
  AND event_name = 'game_start'
GROUP BY country, game_id
ORDER BY country, play_count DESC;


-- 3c. Games played by game, difficulty and country
-- Which difficulty levels are popular per game per country?
SELECT
  geo.country AS country,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'game_id') AS game_id,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'difficulty') AS difficulty,
  COUNT(*) AS play_count
FROM `puzzloragames-minivo.analytics_534840822.events_*`
WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
  AND event_name = 'game_start'
GROUP BY country, game_id, difficulty
ORDER BY country, game_id, play_count DESC;


-- 3d. Average score and duration per game
-- How well are users performing? Which games take longest?
SELECT
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'game_id') AS game_id,
  AVG(COALESCE(
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'score'),
    CAST((SELECT value.double_value FROM UNNEST(event_params) WHERE key = 'score') AS INT64)
  )) AS avg_score,
  MAX(COALESCE(
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'score'),
    CAST((SELECT value.double_value FROM UNNEST(event_params) WHERE key = 'score') AS INT64)
  )) AS max_score,
  AVG(COALESCE(
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'duration_sec'),
    CAST((SELECT value.double_value FROM UNNEST(event_params) WHERE key = 'duration_sec') AS INT64)
  )) AS avg_duration_sec
FROM `puzzloragames-minivo.analytics_534840822.events_*`
WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
  AND event_name = 'game_end'
GROUP BY game_id
ORDER BY avg_score DESC;


-- 3e. Win/Loss rate per game
-- Which games are too hard or too easy?
SELECT
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'game_id') AS game_id,
  COUNT(*) AS total_games,
  COUNTIF((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'result') = 'win') AS wins,
  COUNTIF((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'result') = 'loss') AS losses,
  SAFE_DIVIDE(
    COUNTIF((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'result') = 'win'),
    COUNT(*)
  ) AS win_rate
FROM `puzzloragames-minivo.analytics_534840822.events_*`
WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
  AND event_name = 'game_end'
GROUP BY game_id
ORDER BY win_rate DESC;


-- 3f. Games explored per user
-- Are users trying multiple games or stuck on one?
SELECT
  COUNTIF(games_played = 1) AS played_1_game,
  COUNTIF(games_played BETWEEN 2 AND 3) AS played_2_3_games,
  COUNTIF(games_played BETWEEN 4 AND 6) AS played_4_6_games,
  COUNTIF(games_played > 6) AS played_7_plus_games
FROM (
  SELECT
    user_pseudo_id,
    COUNT(DISTINCT (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'game_id')) AS games_played
  FROM `puzzloragames-minivo.analytics_534840822.events_*`
  WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
    AND event_name = 'game_start'
  GROUP BY user_pseudo_id
);


-- ============================================================
-- 4. TUTORIALS
-- ============================================================

-- 4a. Tutorial completion rate per game
-- Are users finishing the tutorial or skipping it?
SELECT
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'game_id') AS game_id,
  COUNTIF(event_name = 'tutorial_started') AS started,
  COUNTIF(event_name = 'tutorial_completed'
    AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'finished') = 1) AS finished,
  COUNTIF(event_name = 'tutorial_completed'
    AND COALESCE((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'finished'), 0) != 1) AS dismissed,
  SAFE_DIVIDE(
    COUNTIF(event_name = 'tutorial_completed'
      AND (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'finished') = 1),
    COUNTIF(event_name = 'tutorial_started')
  ) AS completion_rate
FROM `puzzloragames-minivo.analytics_534840822.events_*`
WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
  AND event_name IN ('tutorial_started', 'tutorial_completed')
GROUP BY game_id
ORDER BY completion_rate;


-- ============================================================
-- 5. ADS
-- ============================================================

-- 5a. Ad performance by game
-- Which games drive the most ad views? Are users watching full ads?
SELECT
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'game_id') AS game_id,
  COUNTIF(event_name = 'ad_shown') AS impressions,
  COUNTIF(event_name = 'ad_completed') AS completed,
  COUNTIF(event_name = 'ad_skipped') AS skipped,
  COUNTIF(event_name = 'ad_failed') AS failed,
  SAFE_DIVIDE(
    COUNTIF(event_name = 'ad_completed'),
    COUNTIF(event_name = 'ad_shown')
  ) AS completion_rate
FROM `puzzloragames-minivo.analytics_534840822.events_*`
WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
  AND event_name IN ('ad_shown', 'ad_completed', 'ad_skipped', 'ad_failed')
GROUP BY game_id
ORDER BY impressions DESC;


-- 5b. Rewarded ad by reward type
-- Which rewards do users watch ads for most?
SELECT
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'reward_type') AS reward_type,
  COUNTIF(event_name = 'ad_shown') AS shown,
  COUNTIF(event_name = 'ad_completed') AS completed,
  COUNTIF(event_name = 'ad_skipped') AS skipped
FROM `puzzloragames-minivo.analytics_534840822.events_*`
WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
  AND event_name IN ('ad_shown', 'ad_completed', 'ad_skipped')
  AND (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'ad_type') = 'rewarded'
GROUP BY reward_type
ORDER BY shown DESC;


-- ============================================================
-- 6. APP VERSIONS
-- ============================================================

-- 6a. Total users per app version
-- Which versions are your users on?
SELECT
  app_info.version AS app_version,
  COUNT(DISTINCT user_pseudo_id) AS total_users
FROM `puzzloragames-minivo.analytics_534840822.events_*`
WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
  AND event_name = 'session_start'
GROUP BY app_version
ORDER BY app_version DESC;


-- 6b. Total users per app version by country
SELECT
  app_info.version AS app_version,
  geo.country AS country,
  COUNT(DISTINCT user_pseudo_id) AS total_users
FROM `puzzloragames-minivo.analytics_534840822.events_*`
WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
  AND event_name = 'session_start'
GROUP BY app_version, country
ORDER BY app_version DESC, total_users DESC;


-- ============================================================
-- 7. USAGE MONITORING
-- ============================================================

-- 7a. BigQuery usage (last 30 days)
-- How much of the free 1 TB quota have you used?
-- Note: region-us is correct for default Firebase BQ exports.
--       If this errors, run the region check query below first.
SELECT
  SUM(total_bytes_processed) / POW(1024, 3) AS total_gb_used,
  1024 - SUM(total_bytes_processed) / POW(1024, 3) AS free_gb_remaining,
  COUNT(*) AS total_queries
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
  AND job_type = 'QUERY';


-- 7b. Check dataset region (run this if 7a errors)
SELECT
  schema_name,
  location
FROM `puzzloragames-minivo`.INFORMATION_SCHEMA.SCHEMATA
WHERE schema_name = 'analytics_534840822';
