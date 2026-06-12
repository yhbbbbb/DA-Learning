import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime


def load_data(filepath, sample_size=None):
    """加载并预处理UserBehavior数据

    Args:
        filepath: CSV文件路径
        sample_size: 采样数量，None表示加载全部

    Returns:
        处理后的DataFrame
    """
    col_names = ['user_id', 'item_id', 'category_id', 'behavior_type', 'timestamp']
    df = pd.read_csv(filepath, names=col_names, header=0)

    # 时间戳转换
    df['datetime'] = pd.to_datetime(df['timestamp'], unit='s')
    df['date'] = df['datetime'].dt.date
    df['hour'] = df['datetime'].dt.hour
    df['weekday'] = df['datetime'].dt.weekday

    # 去重
    df = df.drop_duplicates()

    # 采样
    if sample_size and len(df) > sample_size:
        df = df.sample(n=sample_size, random_state=42)

    return df


def plot_funnel(df, behavior_col='behavior_type', title='用户行为转化漏斗'):
    """绘制转化漏斗图

    Args:
        df: 包含行为数据的DataFrame
        behavior_col: 行为类型列名
        title: 图表标题
    """
    behavior_map = {'pv': '浏览', 'cart': '加购', 'fav': '收藏', 'buy': '购买'}
    behavior_order = ['pv', 'cart', 'fav', 'buy']

    counts = df.groupby(behavior_col)['user_id'].nunique()
    counts = counts.reindex(behavior_order).dropna()

    labels = [behavior_map.get(b, b) for b in counts.index]
    values = counts.values

    fig, ax = plt.subplots(figsize=(10, 6))
    colors = ['#3498db', '#2ecc71', '#f39c12', '#e74c3c']

    # 绘制漏斗
    max_val = values[0]
    for i, (label, val) in enumerate(zip(labels, values)):
        width = val / max_val
        ax.barh(i, width, color=colors[i], height=0.6, alpha=0.85)
        ax.text(width / 2, i, f'{label}: {val:,} ({val/values[0]*100:.1f}%)',
                ha='center', va='center', fontsize=12, fontweight='bold')

    ax.set_yticks(range(len(labels)))
    ax.set_yticklabels(labels, fontsize=12)
    ax.set_xlim(0, 1.2)
    ax.set_title(title, fontsize=14, fontweight='bold')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['bottom'].set_visible(False)
    ax.set_xticks([])

    plt.tight_layout()
    return fig


def calculate_rfm(df, reference_date=None):
    """计算RFM指标

    Args:
        df: 用户行为数据（仅购买行为）
        reference_date: 参考日期，默认使用数据中最大日期+1天

    Returns:
        RFM DataFrame
    """
    buy_df = df[df['behavior_type'] == 'buy'].copy()

    if reference_date is None:
        reference_date = buy_df['datetime'].max() + pd.Timedelta(days=1)

    rfm = buy_df.groupby('user_id').agg(
        recency=('datetime', lambda x: (reference_date - x.max()).days),
        frequency=('item_id', 'count'),
        monetary=('item_id', 'nunique')
    ).reset_index()

    return rfm


def score_rfm(rfm_df):
    """RFM评分（五分位法）

    Args:
        rfm_df: 包含recency, frequency, monetary列的DataFrame

    Returns:
        带评分的DataFrame
    """
    rfm = rfm_df.copy()

    # R越小越好，所以用反向分位
    rfm['R_score'] = pd.qcut(rfm['recency'], q=5, labels=[5, 4, 3, 2, 1]).astype(int)
    rfm['F_score'] = pd.qcut(rfm['frequency'].rank(method='first'), q=5, labels=[1, 2, 3, 4, 5]).astype(int)
    rfm['M_score'] = pd.qcut(rfm['monetary'].rank(method='first'), q=5, labels=[1, 2, 3, 4, 5]).astype(int)

    rfm['RFM_score'] = rfm['R_score'] + rfm['F_score'] + rfm['M_score']

    return rfm


def label_rfm_segments(rfm_df):
    """根据RFM总分进行用户分群

    Args:
        rfm_df: 包含RFM_score列的DataFrame

    Returns:
        带分群标签的DataFrame
    """
    rfm = rfm_df.copy()

    def segment(score):
        if score >= 13:
            return '高价值用户'
        elif score >= 10:
            return '潜力用户'
        elif score >= 7:
            return '一般用户'
        else:
            return '流失风险用户'

    rfm['segment'] = rfm['RFM_score'].apply(segment)
    return rfm


def plot_rfm_distribution(rfm_df):
    """可视化RFM分群结果

    Args:
        rfm_df: 包含segment列的DataFrame
    """
    fig, axes = plt.subplots(1, 3, figsize=(18, 5))

    # 用户分群占比
    segment_counts = rfm_df['segment'].value_counts()
    colors = ['#e74c3c', '#f39c12', '#3498db', '#2ecc71']
    axes[0].pie(segment_counts, labels=segment_counts.index, autopct='%1.1f%%',
                colors=colors, startangle=90)
    axes[0].set_title('用户分群占比', fontsize=13, fontweight='bold')

    # RFM分布箱线图
    rfm_melted = rfm_df.melt(id_vars=['segment'],
                              value_vars=['recency', 'frequency', 'monetary'],
                              var_name='指标', value_name='值')
    sns.boxplot(data=rfm_melted, x='指标', y='值', hue='segment', ax=axes[1])
    axes[1].set_title('各分群RFM分布', fontsize=13, fontweight='bold')

    # R vs F 散点图
    scatter = axes[2].scatter(rfm_df['recency'], rfm_df['frequency'],
                               c=rfm_df['RFM_score'], cmap='RdYlGn', alpha=0.5, s=10)
    axes[2].set_xlabel('Recency (天)')
    axes[2].set_ylabel('Frequency (次)')
    axes[2].set_title('Recency vs Frequency', fontsize=13, fontweight='bold')
    plt.colorbar(scatter, ax=axes[2], label='RFM Score')

    plt.tight_layout()
    return fig
