-- ============================================================
-- 03 用户行为路径分析（LAG函数应用）
-- 数据集：阿里天池 UserBehavior
-- 分析：用户行为序列与转化路径
-- ============================================================

-- ============================================================
-- 1. 使用 LAG() 获取用户上一步行为
-- ============================================================

-- 为每个用户的行为按时间排序，并获取上一步行为
CREATE VIEW IF NOT EXISTS user_behavior_sequence AS
SELECT
    user_id,
    item_id,
    behavior_type,
    timestamp,
    FROM_UNIXTIME(timestamp) AS datetime,
    LAG(behavior_type) OVER(PARTITION BY user_id ORDER BY timestamp) AS prev_behavior,
    LAG(timestamp) OVER(PARTITION BY user_id ORDER BY timestamp) AS prev_timestamp
FROM user_behavior;

-- ============================================================
-- 2. 用户行为转移矩阵
-- 统计从行为A转移到行为B的次数
-- ============================================================

SELECT
    prev_behavior AS from_behavior,
    behavior_type AS to_behavior,
    COUNT(*) AS transition_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY prev_behavior), 2) AS transition_rate
FROM user_behavior_sequence
WHERE prev_behavior IS NOT NULL
GROUP BY prev_behavior, behavior_type
ORDER BY from_behavior, transition_count DESC;

-- ============================================================
-- 3. 典型转化路径分析
-- 识别"浏览→加购→购买"等典型路径
-- ============================================================

-- 三步路径分析
WITH three_step_paths AS (
    SELECT
        user_id,
        CONCAT(
            prev_prev_behavior, ' -> ',
            prev_behavior, ' -> ',
            behavior_type
        ) AS path,
        prev_prev_behavior,
        prev_behavior,
        behavior_type AS current_behavior
    FROM (
        SELECT
            user_id,
            behavior_type,
            LAG(behavior_type, 1) OVER(PARTITION BY user_id ORDER BY timestamp) AS prev_behavior,
            LAG(behavior_type, 2) OVER(PARTITION BY user_id ORDER BY timestamp) AS prev_prev_behavior
        FROM user_behavior
    ) t
    WHERE prev_prev_behavior IS NOT NULL
      AND prev_behavior IS NOT NULL
)
SELECT
    path,
    COUNT(*) AS occurrence_count,
    COUNT(DISTINCT user_id) AS unique_users
FROM three_step_paths
GROUP BY path
ORDER BY occurrence_count DESC
LIMIT 20;

-- ============================================================
-- 4. 购买前的行为路径分析
-- 用户在购买前做了哪些行为
-- ============================================================

WITH buy_paths AS (
    SELECT
        user_id,
        behavior_type,
        LAG(behavior_type, 1) OVER(PARTITION BY user_id ORDER BY timestamp) AS step_1,
        LAG(behavior_type, 2) OVER(PARTITION BY user_id ORDER BY timestamp) AS step_2,
        LAG(behavior_type, 3) OVER(PARTITION BY user_id ORDER BY timestamp) AS step_3
    FROM user_behavior
)
SELECT
    CONCAT(
        COALESCE(step_3, '-'), ' -> ',
        COALESCE(step_2, '-'), ' -> ',
        COALESCE(step_1, '-'), ' -> ',
        'buy'
    ) AS path_before_purchase,
    COUNT(*) AS count
FROM buy_paths
WHERE behavior_type = 'buy'
  AND step_1 IS NOT NULL
GROUP BY path_before_purchase
ORDER BY count DESC
LIMIT 15;

-- ============================================================
-- 5. 用户行为步骤数统计
-- 分析用户从首次访问到购买平均需要多少步
-- ============================================================

WITH user_steps AS (
    SELECT
        user_id,
        behavior_type,
        ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY timestamp) AS step_num
    FROM user_behavior
),
buy_step AS (
    SELECT
        user_id,
        MIN(step_num) AS first_buy_step
    FROM user_steps
    WHERE behavior_type = 'buy'
    GROUP BY user_id
)
SELECT
    CASE
        WHEN first_buy_step <= 3  THEN '1-3步（快速转化）'
        WHEN first_buy_step <= 10 THEN '4-10步（正常转化）'
        WHEN first_buy_step <= 30 THEN '11-30步（慢速转化）'
        ELSE '30步以上（极慢转化）'
    END AS step_range,
    COUNT(*) AS user_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM buy_step), 2) AS percentage
FROM buy_step
GROUP BY step_range
ORDER BY MIN(first_buy_step);

-- ============================================================
-- 6. 用户首次行为到购买的时间差分析
-- ============================================================

WITH user_time AS (
    SELECT
        user_id,
        MIN(CASE WHEN behavior_type = 'pv'  THEN timestamp END) AS first_pv_time,
        MIN(CASE WHEN behavior_type = 'buy'  THEN timestamp END) AS first_buy_time
    FROM user_behavior
    WHERE behavior_type IN ('pv', 'buy')
    GROUP BY user_id
    HAVING MIN(CASE WHEN behavior_type = 'buy' THEN timestamp END) IS NOT NULL
)
SELECT
    CASE
        WHEN (first_buy_time - first_pv_time) <= 300     THEN '5分钟内'
        WHEN (first_buy_time - first_pv_time) <= 3600    THEN '5-60分钟'
        WHEN (first_buy_time - first_pv_time) <= 86400   THEN '1-24小时'
        WHEN (first_buy_time - first_pv_time) <= 604800  THEN '1-7天'
        ELSE '7天以上'
    END AS time_to_purchase,
    COUNT(*) AS user_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM user_time), 2) AS percentage
FROM user_time
GROUP BY time_to_purchase
ORDER BY MIN(first_buy_time - first_pv_time);
