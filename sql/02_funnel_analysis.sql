-- ============================================================
-- 02 转化漏斗模型分析
-- 数据集：阿里天池 UserBehavior
-- 分析：用户从浏览到购买的转化漏斗
-- ============================================================

-- ============================================================
-- 方案一：整体转化漏斗（用户维度）
-- 每个环节统计的是独立用户数
-- ============================================================

SELECT
    '1-浏览' AS stage,
    COUNT(DISTINCT user_id) AS user_count,
    100.00 AS conversion_rate
FROM user_behavior
WHERE behavior_type = 'pv'

UNION ALL

SELECT
    '2-加购' AS stage,
    COUNT(DISTINCT user_id) AS user_count,
    ROUND(
        COUNT(DISTINCT user_id) * 100.0 /
        (SELECT COUNT(DISTINCT user_id) FROM user_behavior WHERE behavior_type = 'pv'),
        2
    ) AS conversion_rate
FROM user_behavior
WHERE behavior_type = 'cart'

UNION ALL

SELECT
    '3-收藏' AS stage,
    COUNT(DISTINCT user_id) AS user_count,
    ROUND(
        COUNT(DISTINCT user_id) * 100.0 /
        (SELECT COUNT(DISTINCT user_id) FROM user_behavior WHERE behavior_type = 'pv'),
        2
    ) AS conversion_rate
FROM user_behavior
WHERE behavior_type = 'fav'

UNION ALL

SELECT
    '4-购买' AS stage,
    COUNT(DISTINCT user_id) AS user_count,
    ROUND(
        COUNT(DISTINCT user_id) * 100.0 /
        (SELECT COUNT(DISTINCT user_id) FROM user_behavior WHERE behavior_type = 'pv'),
        2
    ) AS conversion_rate
FROM user_behavior
WHERE behavior_type = 'buy';

-- ============================================================
-- 方案二：逐步转化漏斗（窗口函数版本）
-- 计算每一步相对于上一步的转化率
-- ============================================================

WITH funnel AS (
    SELECT
        behavior_type,
        COUNT(DISTINCT user_id) AS user_count
    FROM user_behavior
    WHERE behavior_type IN ('pv', 'cart', 'fav', 'buy')
    GROUP BY behavior_type
),
ordered_funnel AS (
    SELECT
        behavior_type,
        user_count,
        CASE behavior_type
            WHEN 'pv'   THEN 1
            WHEN 'cart'  THEN 2
            WHEN 'fav'   THEN 3
            WHEN 'buy'   THEN 4
        END AS stage_order
    FROM funnel
)
SELECT
    behavior_type,
    user_count,
    -- 相对第一步（浏览）的转化率
    ROUND(user_count * 100.0 / MAX(CASE WHEN stage_order = 1 THEN user_count END) OVER(), 2) AS overall_rate,
    -- 相对上一步的转化率（LAG函数）
    ROUND(user_count * 100.0 / LAG(user_count) OVER(ORDER BY stage_order), 2) AS step_rate
FROM ordered_funnel
ORDER BY stage_order;

-- ============================================================
-- 方案三：分品类漏斗分析（Top 10 品类）
-- ============================================================

WITH category_funnel AS (
    SELECT
        category_id,
        COUNT(DISTINCT CASE WHEN behavior_type = 'pv'   THEN user_id END) AS pv_users,
        COUNT(DISTINCT CASE WHEN behavior_type = 'cart'  THEN user_id END) AS cart_users,
        COUNT(DISTINCT CASE WHEN behavior_type = 'fav'   THEN user_id END) AS fav_users,
        COUNT(DISTINCT CASE WHEN behavior_type = 'buy'   THEN user_id END) AS buy_users
    FROM user_behavior
    GROUP BY category_id
)
SELECT
    category_id,
    pv_users,
    cart_users,
    fav_users,
    buy_users,
    ROUND(cart_users * 100.0 / pv_users, 2)  AS pv_to_cart_rate,
    ROUND(buy_users * 100.0 / pv_users, 2)   AS pv_to_buy_rate
FROM category_funnel
WHERE pv_users >= 100  -- 过滤低流量品类
ORDER BY pv_to_buy_rate DESC
LIMIT 10;

-- ============================================================
-- 方案四：按小时的转化率趋势
-- 识别高转化时段
-- ============================================================

WITH hourly_funnel AS (
    SELECT
        HOUR(FROM_UNIXTIME(timestamp)) AS hour_of_day,
        COUNT(DISTINCT CASE WHEN behavior_type = 'pv'  THEN user_id END) AS pv_users,
        COUNT(DISTINCT CASE WHEN behavior_type = 'buy'  THEN user_id END) AS buy_users
    FROM user_behavior
    GROUP BY hour_of_day
)
SELECT
    hour_of_day,
    pv_users,
    buy_users,
    ROUND(buy_users * 100.0 / pv_users, 2) AS conversion_rate
FROM hourly_funnel
ORDER BY hour_of_day;
