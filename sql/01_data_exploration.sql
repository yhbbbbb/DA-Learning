-- ============================================================
-- 01 数据探索与清洗
-- 数据集：阿里天池 UserBehavior
-- 说明：适用于 MySQL / SQLite / PostgreSQL
-- ============================================================

-- 1. 创建原始数据表
CREATE TABLE IF NOT EXISTS user_behavior ( 
    --如果表已存在就跳过，不会报错。这是一种安全写法，防止重复执行时出错
    user_id       INT,
    item_id       INT,
    category_id   INT,
    behavior_type VARCHAR(10),  -- pv/fav/cart/buy
    timestamp     BIGINT        -- Unix时间戳（秒）
);

-- 2. 导入数据（MySQL示例，根据实际数据库调整）
-- LOAD DATA INFILE '/path/to/UserBehavior.csv'
-- INTO TABLE user_behavior
-- FIELDS TERMINATED BY ','
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS;

-- ============================================================
-- 数据概览
-- ============================================================

-- 总记录数
SELECT COUNT(*) AS total_records FROM user_behavior;

-- 独立用户数
SELECT COUNT(DISTINCT user_id) AS unique_users FROM user_behavior;

-- 独立商品数
SELECT COUNT(DISTINCT item_id) AS unique_items FROM user_behavior;

-- 独立类目数
SELECT COUNT(DISTINCT category_id) AS unique_categories FROM user_behavior;

-- ============================================================
-- 行为类型分布
-- ============================================================

SELECT
    behavior_type,
    CASE behavior_type
        WHEN 'pv'   THEN '浏览'
        WHEN 'fav'   THEN '收藏'
        WHEN 'cart'  THEN '加购'
        WHEN 'buy'   THEN '购买'
    END AS behavior_name, --行为类型翻译，方便阅读
    COUNT(*) AS count, -- 计数
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM user_behavior), 2) AS percentage
    --用"该行为数量 ÷ 总行为数量 × 100"算出百分比，ROUND(..., 2) 保留两位小数
FROM user_behavior
GROUP BY behavior_type  --分组排序
ORDER BY count DESC;  --按行为类型分组，按数量从高到低排列

-- ============================================================
-- 按日期的行为分布
-- ============================================================

SELECT
    FROM_UNIXTIME(timestamp, '%Y-%m-%d') AS date,
    --把 Unix 时间戳（如 1511624400）转成可读日期
    behavior_type,
    COUNT(*) AS count
FROM user_behavior
GROUP BY date, behavior_type --双维度分组
ORDER BY date, behavior_type;--先按日期升序，同一天内再按行为类型排序

-- ============================================================
-- 按小时的行为分布（识别高峰时段）
-- ============================================================

SELECT
    HOUR(FROM_UNIXTIME(timestamp)) AS hour_of_day,
    behavior_type,
    COUNT(*) AS count
FROM user_behavior
GROUP BY hour_of_day, behavior_type
ORDER BY hour_of_day, behavior_type;

-- ============================================================
-- 数据质量检查
-- ============================================================

-- 检查缺失值
SELECT
    SUM(CASE WHEN user_id IS NULL THEN 1 ELSE 0 END) AS null_user_id,
    SUM(CASE WHEN item_id IS NULL THEN 1 ELSE 0 END) AS null_item_id,
    SUM(CASE WHEN category_id IS NULL THEN 1 ELSE 0 END) AS null_category_id,
    SUM(CASE WHEN behavior_type IS NULL THEN 1 ELSE 0 END) AS null_behavior_type,
    SUM(CASE WHEN timestamp IS NULL THEN 1 ELSE 0 END) AS null_timestamp
FROM user_behavior;

-- 检查重复记录
SELECT
    user_id, item_id, category_id, behavior_type, timestamp,
    COUNT(*) AS duplicate_count
FROM user_behavior
GROUP BY user_id, item_id, category_id, behavior_type, timestamp
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 10;

-- 检查时间范围
SELECT
    FROM_UNIXTIME(MIN(timestamp)) AS earliest_time,
    FROM_UNIXTIME(MAX(timestamp)) AS latest_time,
    DATEDIFF(FROM_UNIXTIME(MAX(timestamp)), FROM_UNIXTIME(MIN(timestamp))) AS date_range_days
FROM user_behavior;

-- 检查行为类型是否合法
SELECT DISTINCT behavior_type FROM user_behavior;
