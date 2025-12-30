#!/bin/bash
# 创建修复后的 index.html

cat > /home/user/lianghuajy/web-ui/backend/static/index.html.fixed << 'ENDOFFILE'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Funcat 涨跌停数据看板</title>

    <!-- Element Plus CSS -->
    <link rel="stylesheet" href="https://unpkg.com/element-plus@2.4.4/dist/index.css">

    <!-- ECharts -->
    <script src="https://unpkg.com/echarts@5.4.3/dist/echarts.min.js"></script>

    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', 'Hiragino Sans GB',
                         'Microsoft YaHei', 'Helvetica Neue', Helvetica, Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }

        #app {
            padding: 20px;
        }

        .header {
            background: white;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 2px 12px rgba(0,0,0,0.1);
        }

        .header h1 {
            font-size: 28px;
            color: #303133;
            margin-bottom: 10px;
        }

        .header .subtitle {
            color: #909399;
            font-size: 14px;
        }

        .filter-bar {
            background: white;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 2px 12px rgba(0,0,0,0.1);
        }

        .stats-overview {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }

        .stat-card {
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 12px rgba(0,0,0,0.1);
            transition: transform 0.3s;
        }

        .stat-card:hover {
            transform: translateY(-5px);
        }

        .stat-card .icon {
            font-size: 32px;
            margin-bottom: 10px;
        }

        .stat-card .value {
            font-size: 32px;
            font-weight: bold;
            margin: 10px 0;
        }

        .stat-card .label {
            color: #909399;
            font-size: 14px;
        }

        .stat-card.red .value { color: #F56C6C; }
        .stat-card.green .value { color: #67C23A; }
        .stat-card.blue .value { color: #409EFF; }
        .stat-card.orange .value { color: #E6A23C; }

        .panel {
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 12px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }

        .panel-title {
            font-size: 18px;
            font-weight: bold;
            margin-bottom: 15px;
            padding-bottom: 10px;
            border-bottom: 2px solid #E4E7ED;
        }

        .full-width {
            width: 100%;
        }

        #sectorChart {
            width: 100%;
            height: 400px;
        }
    </style>
</head>
<body>
    <div id="app">
        <!-- 头部 -->
        <div class="header">
            <h1>📊 Funcat 涨跌停数据看板</h1>
            <div class="subtitle">实时监控市场热点 · 板块涨停统计 · 连板天梯</div>
            <div style="margin-top: 15px;">
                <el-button type="danger" @click="goToYangjia">
                    🔥 炒股养家心法选股
                </el-button>
            </div>
        </div>

        <!-- 筛选栏 -->
        <div class="filter-bar">
            <el-row :gutter="20">
                <el-col :span="6">
                    <el-date-picker
                        v-model="selectedDate"
                        type="date"
                        placeholder="选择日期"
                        format="YYYY-MM-DD"
                        value-format="YYYY-MM-DD"
                        @change="loadData"
                        style="width: 100%"
                    />
                </el-col>
                <el-col :span="6">
                    <el-button type="primary" @click="loadData" style="width: 100%">
                        🔄 刷新数据
                    </el-button>
                </el-col>
            </el-row>
        </div>

        <!-- 统计概览 -->
        <div class="stats-overview">
            <div class="stat-card red">
                <div class="icon">📈</div>
                <div class="value">{{ totalLimitUp }}</div>
                <div class="label">涨停家数</div>
            </div>
            <div class="stat-card green">
                <div class="icon">📉</div>
                <div class="value">{{ totalLimitDown }}</div>
                <div class="label">跌停家数</div>
            </div>
            <div class="stat-card blue">
                <div class="icon">🔥</div>
                <div class="value">{{ totalOneWord }}</div>
                <div class="label">一字涨停</div>
            </div>
            <div class="stat-card orange">
                <div class="icon">💥</div>
                <div class="value">{{ totalBroken }}</div>
                <div class="label">炸板总数</div>
            </div>
        </div>

        <!-- 板块涨停排行 -->
        <div class="panel">
            <div class="panel-title">📊 板块涨停排行</div>
            <div id="sectorChart"></div>
        </div>

        <!-- 板块强度排行 -->
        <div class="panel full-width">
            <div class="panel-title">🔥 板块强度排行</div>
            <el-table v-if="sectorStrength.length > 0" :data="sectorStrength" stripe style="width: 100%" max-height="400">
                <el-table-column type="index" label="排名" width="60" />
                <el-table-column prop="sector_name" label="板块名称" width="120" />
                <el-table-column prop="strength_grade" label="等级" width="80" />
                <el-table-column prop="strength_score" label="强度分数" width="110">
                    <template v-slot="{ row }">
                        <span v-if="row && row.strength_score != null">{{ parseFloat(row.strength_score).toFixed(1) }}</span>
                        <span v-else>-</span>
                    </template>
                </el-table-column>
                <el-table-column prop="limit_up_count" label="涨停数" width="90" />
                <el-table-column prop="one_word_count" label="一字板" width="90" />
            </el-table>
            <div v-else style="text-align: center; padding: 40px; color: #909399;">
                暂无数据
            </div>
        </div>
    </div>

    <!-- Vue 3 -->
    <script src="https://unpkg.com/vue@3.3.11/dist/vue.global.js"></script>
    <!-- Element Plus -->
    <script src="https://unpkg.com/element-plus@2.4.4/dist/index.full.js"></script>

    <script>
        const { createApp } = Vue;
        const ElementPlus = window['element-plus'];

        const app = createApp({
            data() {
                return {
                    selectedDate: '2025-12-30',
                    sectors: [],
                    sectorStats: [],
                    sectorStrength: [],
                    totalLimitUp: 0,
                    totalLimitDown: 0,
                    totalOneWord: 0,
                    totalBroken: 0,
                    sectorChart: null,
                };
            },
            mounted() {
                console.log('✅ Vue应用已挂载');
                this.loadData();
            },
            methods: {
                async loadData() {
                    console.log('🔄 开始加载数据...');
                    await this.loadSectorStats();
                    await this.loadSectorStrength();
                },

                async loadSectorStats() {
                    try {
                        const url = `/api/v1/sectors/stats?date=${this.selectedDate}`;
                        console.log('📊 加载板块统计:', url);
                        const response = await fetch(url);
                        const result = await response.json();
                        console.log('✅ 板块统计结果:', result);

                        if (result.code === 200 && Array.isArray(result.data)) {
                            this.sectorStats = result.data;
                            this.calculateTotals();
                            this.renderSectorChart();
                        }
                    } catch (error) {
                        console.error('❌ 加载板块统计失败:', error);
                        ElementPlus.ElMessage.error('加载数据失败');
                    }
                },

                async loadSectorStrength() {
                    try {
                        const url = `/api/v1/sector-strength?date=${this.selectedDate}&limit=30`;
                        console.log('🔥 加载板块强度:', url);
                        const response = await fetch(url);
                        const result = await response.json();
                        console.log('✅ 板块强度结果:', result);

                        if (result.code === 200 && Array.isArray(result.data)) {
                            this.sectorStrength = result.data;
                            console.log(`📈 共 ${this.sectorStrength.length} 个板块`);
                        }
                    } catch (error) {
                        console.error('❌ 加载板块强度失败:', error);
                    }
                },

                calculateTotals() {
                    this.totalLimitUp = this.sectorStats.reduce((sum, s) => sum + (s.limit_up_count || 0), 0);
                    this.totalLimitDown = this.sectorStats.reduce((sum, s) => sum + (s.limit_down_count || 0), 0);
                    this.totalOneWord = this.sectorStats.reduce((sum, s) => sum + (s.one_word_count || 0), 0);
                    this.totalBroken = this.sectorStats.reduce((sum, s) => sum + (s.broken_count || 0), 0);
                },

                renderSectorChart() {
                    if (!this.sectorStats || this.sectorStats.length === 0) {
                        console.log('⏭️  没有板块数据，跳过图表渲染');
                        return;
                    }

                    try {
                        if (!this.sectorChart) {
                            const chartDom = document.getElementById('sectorChart');
                            if (!chartDom) {
                                console.error('❌ 找不到图表容器');
                                return;
                            }
                            this.sectorChart = echarts.init(chartDom);
                        }

                        const top10 = this.sectorStats.slice(0, 10);

                        const option = {
                            tooltip: {
                                trigger: 'axis',
                                axisPointer: { type: 'shadow' }
                            },
                            legend: {
                                data: ['涨停', '一字板', '炸板', '回封']
                            },
                            grid: {
                                left: '3%',
                                right: '4%',
                                bottom: '3%',
                                containLabel: true
                            },
                            xAxis: {
                                type: 'value'
                            },
                            yAxis: {
                                type: 'category',
                                data: top10.map(s => s.sector_name || '')
                            },
                            series: [
                                {
                                    name: '涨停',
                                    type: 'bar',
                                    data: top10.map(s => s.limit_up_count || 0),
                                    itemStyle: { color: '#F56C6C' }
                                },
                                {
                                    name: '一字板',
                                    type: 'bar',
                                    data: top10.map(s => s.one_word_count || 0),
                                    itemStyle: { color: '#E6A23C' }
                                },
                                {
                                    name: '炸板',
                                    type: 'bar',
                                    data: top10.map(s => s.broken_count || 0),
                                    itemStyle: { color: '#909399' }
                                },
                                {
                                    name: '回封',
                                    type: 'bar',
                                    data: top10.map(s => s.broken_resealed_count || 0),
                                    itemStyle: { color: '#67C23A' }
                                }
                            ]
                        };

                        this.sectorChart.setOption(option);
                        console.log('✅ 图表渲染成功');
                    } catch (error) {
                        console.error('❌ 图表渲染失败:', error);
                    }
                },

                goToYangjia() {
                    window.location.href = '/static/yangjia.html';
                }
            }
        });

        app.config.errorHandler = (err, instance, info) => {
            console.error('❌ Vue错误:', err);
            console.error('错误信息:', info);
        };

        try {
            app.use(ElementPlus);
            const vm = app.mount('#app');
            console.log('🎉 Vue应用挂载成功！');
        } catch (error) {
            console.error('❌ Vue应用挂载失败:', error);
            alert('页面加载失败: ' + error.message);
        }
    </script>
</body>
</html>
ENDOFFILE

# 备份原文件并替换
cd /home/user/lianghuajy/web-ui/backend/static
cp index.html index.html.backup
mv index.html.fixed index.html

echo "✅ 已创建简化版 index.html"
echo "💡 原文件已备份为 index.html.backup"
