# 电商用户行为分析与转化率优化

## 项目背景

基于阿里天池淘宝用户行为数据，分析用户转化路径与行为特征，构建数据分析模型支持业务决策。

## 数据说明

数据集来源：[阿里天池 UserBehavior](https://tianchi.aliyun.com/dataset/649)

| 字段名 | 说明 |
|--------|------|
| user_id | 用户ID |
| item_id | 商品ID |
| category_id | 商品类目ID |
| behavior_type | 行为类型：pv(浏览), fav(收藏), cart(加购), buy(购买) |
| timestamp | 行为时间戳（秒级） |

## 项目结构

```
├── data/                  # 数据存放目录
├── sql/                   # SQL分析脚本
│   ├── 01_data_exploration.sql
│   ├── 02_funnel_analysis.sql
│   └── 03_user_path_analysis.sql
├── notebooks/             # Jupyter Notebooks
│   ├── 01_data_preprocessing.ipynb
│   ├── 02_funnel_visualization.ipynb
│   ├── 03_rfm_segmentation.ipynb
│   └── 04_trend_analysis.ipynb
├── src/utils.py           # 工具函数
├── tableau/               # Tableau看板指南
└── report/                # 分析报告
```

## 快速开始

1. 安装依赖：`pip install -r requirements.txt`
2. 下载数据：从阿里天池下载 UserBehavior.csv 放入 `data/` 目录
3. 按顺序运行 notebooks/ 下的 Jupyter Notebook

## 技术栈

- **SQL**：数据清洗、漏斗分析、LAG函数路径分析
- **Python**：数据预处理、RFM建模、K-Means聚类、趋势分析
- **Tableau**：可视化看板搭建
