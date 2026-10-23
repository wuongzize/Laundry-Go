import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';

class AnalysisDashboardPage extends StatefulWidget {
  const AnalysisDashboardPage({super.key});

  @override
  State<AnalysisDashboardPage> createState() => _AnalysisDashboardPageState();
}

class _AnalysisDashboardPageState extends State<AnalysisDashboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DateTime _selectedDate = DateTime.now();
  String _selectedTimeRange = 'weekly'; // 默认显示周视图
  final double _revenuePerUse = 6.0;
  bool _showRevenueChart = true; // 控制显示收入还是使用次数

  // 获取最近30天的收入数据（用于折线图）
  Future<List<Map<String, dynamic>>> _getRevenueTrendData(int days) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days - 1));

    try {

      
      // Let's rewrite the block properly
      final allDocs = await _firestore
          .collection('machine_usage')
          .where('ownerUid', isEqualTo: user.uid)
          .get();

      final filteredDocs = allDocs.docs.where((doc) {
        final timestamp = doc['timestamp'] as Timestamp?;
        if (timestamp == null) return false;
        return timestamp.toDate().isAfter(startDate) || timestamp.toDate().isAtSameMomentAs(startDate);
      }).toList();

      // 初始化日期数据
      final Map<DateTime, int> dailyUsage = {};
      for (int i = 0; i < days; i++) {
        final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1 - i));
        dailyUsage[date] = 0;
      }

      // 统计每天的使用次数
      for (var doc in filteredDocs) {
        final timestamp = doc['timestamp']?.toDate();
        if (timestamp != null) {
          final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
          if (dailyUsage.containsKey(date)) {
            dailyUsage[date] = (dailyUsage[date] ?? 0) + 1;
          }
        }
      }

      // 转换为折线图数据
      return dailyUsage.entries.map((entry) {
        final usage = entry.value;
        final revenue = usage * _revenuePerUse;
        return {
          'date': entry.key,
          'usageCount': usage,
          'revenue': revenue,
          'formattedDate': _getFormattedDate(entry.key, days),
          'dayName': DateFormat('E').format(entry.key),
          'isToday': entry.key.day == now.day && entry.key.month == now.month && entry.key.year == now.year,
        };
      }).toList();
    } catch (e) {
      print('Error fetching revenue trend data: $e');
      return [];
    }
  }

  String _getFormattedDate(DateTime date, int totalDays) {
    if (totalDays <= 7) {
      return DateFormat('E').format(date); // 周视图：显示星期几
    } else if (totalDays <= 30) {
      return DateFormat('MMM d').format(date); // 月视图：显示月份和日期
    } else {
      return DateFormat('MM/dd').format(date); // 长期视图：显示月/日
    }
  }

  // 获取每小时使用数据
  Future<List<Map<String, dynamic>>> _getHourlyUsageData() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final todayStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    try {
      final allDocs = await _firestore
          .collection('machine_usage')
          .where('ownerUid', isEqualTo: user.uid)
          .get();

      final filteredDocs = allDocs.docs.where((doc) {
        final timestamp = doc['timestamp'] as Timestamp?;
        if (timestamp == null) return false;
        final date = timestamp.toDate();
        return date.isAfter(todayStart) && date.isBefore(todayEnd);
      }).toList();

      // 初始化24小时数据
      final Map<int, int> hourlyData = {};
      for (int i = 0; i < 24; i++) {
        hourlyData[i] = 0;
      }

      for (var doc in filteredDocs) {
        final timestamp = doc['timestamp']?.toDate();
        if (timestamp != null) {
          final hour = timestamp.hour;
          hourlyData[hour] = (hourlyData[hour] ?? 0) + 1;
        }
      }

      return hourlyData.entries.map((entry) {
        final usage = entry.value;
        return {
          'hour': '${entry.key}:00',
          'usageCount': usage,
          'revenue': usage * _revenuePerUse,
          'hourIndex': entry.key,
        };
      }).toList();
    } catch (e) {
      print('Error fetching hourly data: $e');
      return [];
    }
  }

  // 获取性能汇总 (Dynamic)
  Future<Map<String, dynamic>> _getPerformanceSummary(int days) async {
    final user = _auth.currentUser;
    if (user == null) return {};

    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));

    try {
      final allDocs = await _firestore
          .collection('machine_usage')
          .where('ownerUid', isEqualTo: user.uid)
          .get();

      final filteredDocs = allDocs.docs.where((doc) {
        final timestamp = doc['timestamp'] as Timestamp?;
        if (timestamp == null) return false;
        return timestamp.toDate().isAfter(startDate);
      }).toList();

      final totalUses = filteredDocs.length;
      final monthlyRevenue = totalUses * _revenuePerUse;

      return {
        'totalUses': totalUses,
        'totalRevenue': monthlyRevenue,
        'averageDaily': days > 0 ? monthlyRevenue / days : 0.0,
      };
    } catch (e) {
      print('Error fetching performance summary: $e');
      return {};
    }
  }

  // 构建折线图
  Widget _buildLineChart(List<Map<String, dynamic>> data, String title, int days) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    // 计算最大值
    final maxValue = data
        .map((e) => _showRevenueChart ? e['revenue'] as double : (e['usageCount'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);

    // 计算总值
    final totalValue = data.fold(0.0, (sum, item) {
      return sum + (_showRevenueChart ? item['revenue'] as double : (item['usageCount'] as num).toDouble());
    });

    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和切换按钮
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // // 时间范围选择器 (Simplified)
                    PopupMenuButton<String>(
                       child: Row(
                         children: [
                           const Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryColor),
                           const SizedBox(width: 4),
                           Text(
                             _selectedTimeRange == 'weekly' ? 'Last 7 Days' : 
                             _selectedTimeRange == 'monthly' ? 'Last 30 Days' : 'Last 90 Days',
                             style: const TextStyle(
                               color: AppTheme.primaryColor,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                           const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
                         ],
                       ),
                      onSelected: (value) {
                        setState(() {
                          _selectedTimeRange = value;
                        });
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'weekly',
                          child: Text('Last 7 Days'),
                        ),
                        const PopupMenuItem(
                          value: 'monthly',
                          child: Text('Last 30 Days'),
                        ),
                        const PopupMenuItem(
                          value: 'quarterly',
                          child: Text('Last 90 Days'),
                        ),
                      ],
                    ),
                    // 切换按钮
                    ChoiceChip(
                      label: Text(_showRevenueChart ? 'Revenue' : 'Usage'),
                      selected: true,
                      selectedColor: AppTheme.primaryColor.withOpacity(0.1),
                      labelStyle: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold
                      ),
                      onSelected: (_) {
                        setState(() {
                          _showRevenueChart = !_showRevenueChart;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 10),
            
            // 统计数据
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Total: ${_showRevenueChart ? 'RM${totalValue.toStringAsFixed(2)}' : '$totalValue uses'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Avg: ${_showRevenueChart ? 'RM${(totalValue / days).toStringAsFixed(2)}/day' : '${(totalValue / days).toStringAsFixed(1)} uses/day'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 10),
            
            // 折线图
            SizedBox(
              height: 300,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawHorizontalLine: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.shade200,
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: days <= 7 ? 1 : (days / 5).ceilToDouble(),
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() < data.length) {
                              final item = data[value.toInt()];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  item['formattedDate'],
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: maxValue > 0 ? maxValue / 5 : 10,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              _showRevenueChart 
                                ? 'RM${value.toInt()}'
                                : value.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    minX: 0,
                    maxX: data.length.toDouble() - 1,
                    minY: 0,
                    maxY: maxValue * 1.1, // 留10%空间
                    lineBarsData: [
                      // 收入/使用次数折线
                      LineChartBarData(
                        spots: data.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final value = _showRevenueChart 
                            ? item['revenue'] as double 
                            : (item['usageCount'] as num).toDouble();
                          
                          return FlSpot(index.toDouble(), value);
                        }).toList(),
                        isCurved: true,
                        color: _showRevenueChart ? AppTheme.primaryColor : AppTheme.secondaryColor,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            if (data[index]['isToday'] == true) {
                              return FlDotCirclePainter(
                                radius: 5,
                                color: Colors.orange,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            }
                            return FlDotCirclePainter(
                              radius: 4,
                              color: _showRevenueChart ? AppTheme.primaryColor : AppTheme.secondaryColor,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              (_showRevenueChart 
                                ? AppTheme.primaryColor 
                                : AppTheme.secondaryColor).withOpacity(0.3),
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 10),
            
            // 图例
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _showRevenueChart ? AppTheme.primaryColor : AppTheme.secondaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _showRevenueChart ? 'Daily Revenue (RM)' : 'Daily Machine Usage',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 构建小时收入/使用率图表
  Widget _buildHourlyChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available for today'));
    }

    final totalRevenue = data.fold(0.0, (sum, item) => sum + (item['revenue'] as double));  
    final totalUses = data.fold(0, (sum, item) => sum + (item['usageCount'] as int));

    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today\'s Hourly Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Revenue: RM${totalRevenue.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total Uses: $totalUses',
                  style: TextStyle(
                    color: AppTheme.secondaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Revenue per Use: RM$_revenuePerUse',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 10),
            
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: true,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 0.5,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade100,
                        strokeWidth: 0.5,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        interval: 2,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() % 3 == 0 && value.toInt() < 24) {
                            return Text(
                              '${value.toInt()}h',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            'RM${value.toInt()}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 23,
                  minY: 0,
                  maxY: data.map((e) => e['revenue'] as double).reduce((a, b) => a > b ? a : b) * 1.2,
                  lineBarsData: [
                    // 收入折线
                    LineChartBarData(
                      spots: data.map((item) {
                        return FlSpot(item['hourIndex'].toDouble(), item['revenue'] as double);
                      }).toList(),
                      isCurved: true,
                      color: AppTheme.primaryColor,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.3),
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    // 使用次数折线（次坐标轴）
                    LineChartBarData(
                      spots: data.map((item) {
                        final maxRevenue = data.map((e) => e['revenue'] as double).reduce((a, b) => a > b ? a : b);
                        final usage = item['usageCount'] as int;
                        // 将使用次数映射到收入坐标系
                        final scaledUsage = usage * (maxRevenue / (data.map((e) => e['usageCount'] as int).reduce((a, b) => a > b ? a : b) * 1.5));
                        return FlSpot(item['hourIndex'].toDouble(), scaledUsage);
                      }).toList(),
                      isCurved: true,
                      color: AppTheme.secondaryColor,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            
            // 小时图图例
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 2,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Revenue (RM)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 12,
                  height: 2,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Usage Count (scaled)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int days = _selectedTimeRange == 'weekly' ? 7 : 
                     _selectedTimeRange == 'monthly' ? 30 : 90;
    final String chartTitle = _selectedTimeRange == 'weekly' ? '7-Day Trend' :
                              _selectedTimeRange == 'monthly' ? '30-Day Trend' : '90-Day Trend';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Dashboard'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间范围选择卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Revenue & Usage Analysis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildTimeRangeChip('Weekly', Icons.today, 'weekly'),
                        _buildTimeRangeChip('Monthly', Icons.calendar_month, 'monthly'),
                        _buildTimeRangeChip('Quarterly', Icons.timeline, 'quarterly'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Each machine use generates RM$_revenuePerUse revenue',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 主要折线图
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _getRevenueTrendData(days),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data ?? [];
                return _buildLineChart(data, chartTitle, days);
              },
            ),

            const SizedBox(height: 20),

            // 今日小时图表
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _getHourlyUsageData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox();
                }
                final data = snapshot.data ?? [];
                return _buildHourlyChart(data);
              },
            ),

            const SizedBox(height: 20),

            // 月度汇总
            // 性能汇总
            FutureBuilder<Map<String, dynamic>>(
              future: _getPerformanceSummary(days),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox();
                }
                final data = snapshot.data ?? {};
                final totalRevenue = data['totalRevenue'] ?? 0.0;
                final totalUses = data['totalUses'] ?? 0;
                final averageDaily = data['averageDaily'] ?? 0.0;

                String periodTitle;
                switch (_selectedTimeRange) {
                  case 'weekly': periodTitle = 'Weekly Performance'; break;
                  case 'monthly': periodTitle = 'Monthly Performance'; break;
                  case 'quarterly': periodTitle = 'Quarterly Performance'; break;
                  default: periodTitle = 'Performance Summary';
                }

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          periodTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSummaryItem(
                              'Total Revenue',
                              'RM${totalRevenue.toStringAsFixed(2)}',
                              Icons.attach_money,
                              AppTheme.primaryColor,
                            ),
                            _buildSummaryItem(
                              'Total Uses',
                              '$totalUses',
                              Icons.local_laundry_service,
                              AppTheme.secondaryColor,
                            ),
                            _buildSummaryItem(
                              'Avg Daily',
                              'RM${averageDaily.toStringAsFixed(2)}',
                              Icons.trending_up,
                              AppTheme.primaryColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // 时间范围选择芯片
  Widget _buildTimeRangeChip(String label, IconData icon, String value) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: _selectedTimeRange == value,
      onSelected: (_) {
        setState(() {
          _selectedTimeRange = value;
        });
      },
      selectedColor: AppTheme.secondaryColor.withOpacity(0.2),
      labelStyle: TextStyle(
        color: _selectedTimeRange == value ? AppTheme.secondaryColor : AppTheme.textPrimary,
        fontWeight: _selectedTimeRange == value ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  // 汇总项目
  Widget _buildSummaryItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}