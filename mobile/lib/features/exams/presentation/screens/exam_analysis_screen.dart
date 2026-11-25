import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/features/exams/data/models/exams_models.dart';

class ExamAnalysisScreen extends StatelessWidget {
  const ExamAnalysisScreen({super.key, required this.result});

  final ExamResultModel result;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Performance Analytics',
      showAppBar: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            _HeroScoreCard(result: result),
            const SizedBox(height: 24),
            const _AiInsightSection(),
            const SizedBox(height: 24),
            const _SubjectAnalysisSection(),
            const SizedBox(height: 24),
            const _TopicAnalysisSection(),
            const SizedBox(height: 24),
            const _QuestionTypeAnalysis(),
            const SizedBox(height: 24),
            const _DifficultyAnalysis(),
            const SizedBox(height: 24),
            const _TimeAnalysis(),
            const SizedBox(height: 24),
            const _PerformanceTrend(),
            const SizedBox(height: 24),
            const _RankComparison(),
            const SizedBox(height: 24),
            const _StrengthsWeaknesses(),
            const SizedBox(height: 24),
            const _RecommendedStudy(),
            const SizedBox(height: 24),
            const _QuestionReviewSection(),
            const SizedBox(height: 24),
            const _AchievementsSection(),
            const SizedBox(height: 32),
            const _DownloadShareSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// 1. Hero Score Card
class _HeroScoreCard extends StatelessWidget {
  const _HeroScoreCard({required this.result});
  final ExamResultModel result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            result.examTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink(context),
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  value: result.percentage / 100,
                  strokeWidth: 12,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primary,
                  ),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                children: [
                  Text(
                    '${result.percentage}%',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                      letterSpacing: -1.0,
                    ),
                  ),
                  Text(
                    'Overall Score',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _HeroStatItem(
                label: 'Rank',
                value: '#42',
                icon: Icons.emoji_events_outlined,
                color: Colors.amber,
              ),
              _HeroStatItem(
                label: 'Accuracy',
                value: '84%',
                icon: Icons.ads_click_rounded,
                color: Colors.green,
              ),
              _HeroStatItem(
                label: 'Time',
                value: '45m',
                icon: Icons.timer_outlined,
                color: Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _HeroStatItem(
                label: 'Attempted',
                value: '92/100',
                icon: Icons.check_circle_outline,
                color: Colors.purple,
              ),
              _HeroStatItem(
                label: 'Score',
                value: '${result.score}/${result.totalMarks}',
                icon: Icons.analytics_outlined,
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
              label: const Text('View Detailed Solutions'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatItem extends StatelessWidget {
  const _HeroStatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink(context),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// 2. AI Performance Summary
class _AiInsightSection extends StatelessWidget {
  const _AiInsightSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366F1).withValues(alpha: 0.05),
            const Color(0xFFA855F7).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Color(0xFF6366F1),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'AI Performance Insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.indigo.shade900,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Great job! You\'ve shown significant improvement in Physics. You seem to struggle with complex numerical problems under time pressure.',
            style: TextStyle(
              height: 1.5,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.inkSoft(context),
            ),
          ),
          const SizedBox(height: 20),
          _InsightTag(
            label: 'Strength',
            text: 'Chemistry: Organic',
            icon: Icons.thumb_up_alt_rounded,
            color: Colors.green,
          ),
          const SizedBox(height: 10),
          _InsightTag(
            label: 'Weakness',
            text: 'Biology: Genetics',
            icon: Icons.lightbulb_rounded,
            color: Colors.orange,
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Recommendation: Focus on Biology Genetics MCQs for 30 mins daily to boost your overall accuracy.',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Colors.indigo,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightTag extends StatelessWidget {
  const _InsightTag({
    required this.label,
    required this.text,
    required this.icon,
    required this.color,
  });
  final String label, text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.ink(context),
            ),
          ),
        ),
      ],
    );
  }
}

// 3. Subject-wise Analysis
class _SubjectAnalysisSection extends StatelessWidget {
  const _SubjectAnalysisSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Subject Analysis'),
        const SizedBox(height: 16),
        _SubjectCard(
          subject: 'Pharmacology',
          percentage: 82,
          correct: 18,
          incorrect: 4,
          avgTime: '42s',
          color: Colors.blue,
        ),
        const SizedBox(height: 12),
        _SubjectCard(
          subject: 'Microbiology',
          percentage: 64,
          correct: 12,
          incorrect: 8,
          avgTime: '55s',
          color: Colors.teal,
        ),
      ],
    );
  }
}

class _SubjectCard extends StatefulWidget {
  const _SubjectCard({
    required this.subject,
    required this.percentage,
    required this.correct,
    required this.incorrect,
    required this.avgTime,
    required this.color,
  });
  final String subject;
  final int percentage, correct, incorrect;
  final String avgTime;
  final Color color;

  @override
  State<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<_SubjectCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.subject,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppTheme.ink(context),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: widget.percentage / 100,
                          backgroundColor: widget.color.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation(widget.color),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Text(
                  '${widget.percentage}%',
                  style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.grey,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MiniStat(
                    label: 'Correct',
                    value: '${widget.correct}',
                    color: Colors.green,
                  ),
                  _MiniStat(
                    label: 'Incorrect',
                    value: '${widget.incorrect}',
                    color: Colors.red,
                  ),
                  _MiniStat(
                    label: 'Avg Time',
                    value: widget.avgTime,
                    color: Colors.blueGrey,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _TopicMiniRow(topic: 'Antibiotics', accuracy: 90),
              const _TopicMiniRow(topic: 'Drug Dosage', accuracy: 45),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TopicMiniRow extends StatelessWidget {
  const _TopicMiniRow({required this.topic, required this.accuracy});
  final String topic;
  final int accuracy;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Text(
            topic,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.inkSoft(context),
            ),
          ),
          const Spacer(),
          Text(
            '$accuracy%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: accuracy > 70 ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

// 4. Topic-wise Analysis
class _TopicAnalysisSection extends StatelessWidget {
  const _TopicAnalysisSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Topic Analysis'),
        const SizedBox(height: 16),
        _TopicGroup(
          title: 'Strong Topics',
          color: Colors.green,
          topics: const [
            {'name': 'Cardiovascular System', 'pct': 95},
            {'name': 'Endocrine System', 'pct': 88},
          ],
        ),
        const SizedBox(height: 16),
        _TopicGroup(
          title: 'Weak Topics',
          color: Colors.red,
          topics: const [
            {'name': 'Neurological Disorders', 'pct': 32},
            {'name': 'Acid-Base Balance', 'pct': 41},
          ],
        ),
      ],
    );
  }
}

class _TopicGroup extends StatelessWidget {
  const _TopicGroup({
    required this.title,
    required this.color,
    required this.topics,
  });
  final String title;
  final Color color;
  final List<Map<String, dynamic>> topics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          ...topics.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.ink(context),
                        ),
                      ),
                      Text(
                        '${t['pct']}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: t['pct'] / 100,
                      backgroundColor: color.withValues(alpha: 0.05),
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 5. Question Type Analysis
class _QuestionTypeAnalysis extends StatelessWidget {
  const _QuestionTypeAnalysis();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Question Type Mastery'),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: const [
            _QTypeCard(
              label: 'MCQs',
              pct: 90,
              icon: Icons.list_alt_rounded,
              color: Colors.blue,
            ),
            _QTypeCard(
              label: 'Clinical',
              pct: 45,
              icon: Icons.medical_services_outlined,
              color: Colors.purple,
            ),
            _QTypeCard(
              label: 'Image Based',
              pct: 75,
              icon: Icons.image_outlined,
              color: Colors.teal,
            ),
            _QTypeCard(
              label: 'Assertion',
              pct: 60,
              icon: Icons.rule_rounded,
              color: Colors.orange,
            ),
          ],
        ),
      ],
    );
  }
}

class _QTypeCard extends StatelessWidget {
  const _QTypeCard({
    required this.label,
    required this.pct,
    required this.icon,
    required this.color,
  });
  final String label;
  final int pct;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppTheme.ink(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$pct%',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// 6. Difficulty Analysis
class _DifficultyAnalysis extends StatelessWidget {
  const _DifficultyAnalysis();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Difficulty Analysis'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 35,
                    sections: [
                      PieChartSectionData(
                        value: 40,
                        color: Colors.green,
                        radius: 15,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: 35,
                        color: Colors.orange,
                        radius: 15,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: 25,
                        color: Colors.red,
                        radius: 15,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 32),
              const Expanded(
                child: Column(
                  children: [
                    _DifficultyLegend(
                      label: 'Easy',
                      pct: 90,
                      color: Colors.green,
                    ),
                    _DifficultyLegend(
                      label: 'Medium',
                      pct: 65,
                      color: Colors.orange,
                    ),
                    _DifficultyLegend(
                      label: 'Hard',
                      pct: 30,
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DifficultyLegend extends StatelessWidget {
  const _DifficultyLegend({
    required this.label,
    required this.pct,
    required this.color,
  });
  final String label;
  final int pct;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.inkSoft(context),
            ),
          ),
          const Spacer(),
          Text(
            '$pct%',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// 7. Time Analysis
class _TimeAnalysis extends StatelessWidget {
  const _TimeAnalysis();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Time Analysis'),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(24),
          ),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: const [
                    FlSpot(0, 30),
                    FlSpot(1, 45),
                    FlSpot(2, 20),
                    FlSpot(3, 80),
                    FlSpot(4, 35),
                    FlSpot(5, 50),
                  ],
                  isCurved: true,
                  color: AppTheme.primary,
                  barWidth: 4,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppTheme.primary.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _TimeStatBox(
                label: 'Slowest',
                value: '110s',
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TimeStatBox(
                label: 'Fastest',
                value: '12s',
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimeStatBox extends StatelessWidget {
  const _TimeStatBox({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppTheme.ink(context),
            ),
          ),
        ],
      ),
    );
  }
}

// 8. Performance Trend
class _PerformanceTrend extends StatelessWidget {
  const _PerformanceTrend();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Growth Trend'),
        const SizedBox(height: 16),
        Container(
          height: 180,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(24),
          ),
          child: BarChart(
            BarChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: [
                BarChartGroupData(
                  x: 0,
                  barRods: [
                    BarChartRodData(
                      toY: 60,
                      color: Colors.grey.shade300,
                      width: 15,
                    ),
                  ],
                ),
                BarChartGroupData(
                  x: 1,
                  barRods: [
                    BarChartRodData(
                      toY: 65,
                      color: Colors.grey.shade300,
                      width: 15,
                    ),
                  ],
                ),
                BarChartGroupData(
                  x: 2,
                  barRods: [
                    BarChartRodData(
                      toY: 72,
                      color: Colors.grey.shade300,
                      width: 15,
                    ),
                  ],
                ),
                BarChartGroupData(
                  x: 3,
                  barRods: [
                    BarChartRodData(
                      toY: 84,
                      color: AppTheme.primary,
                      width: 15,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// 9. Rank Comparison
class _RankComparison extends StatelessWidget {
  const _RankComparison();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Rank Benchmarking'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              _BenchmarkRow(
                label: 'Topper Score',
                value: '98%',
                color: Colors.amber,
              ),
              _BenchmarkRow(
                label: 'Top 100 Avg',
                value: '91%',
                color: Colors.blue,
              ),
              _BenchmarkRow(
                label: 'Overall Avg',
                value: '64%',
                color: Colors.grey,
              ),
              const Divider(height: 32),
              _BenchmarkRow(
                label: 'Your Score',
                value: '84%',
                color: AppTheme.primary,
                isBold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BenchmarkRow extends StatelessWidget {
  const _BenchmarkRow({
    required this.label,
    required this.value,
    required this.color,
    this.isBold = false,
  });
  final String label, value;
  final Color color;
  final bool isBold;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              fontSize: 14,
              color: AppTheme.ink(context),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: isBold ? color : Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

// 10. Strengths & Weaknesses
class _StrengthsWeaknesses extends StatelessWidget {
  const _StrengthsWeaknesses();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SwCard(
            title: 'Strengths',
            items: const ['Physics', 'Chemistry', 'Formula Recall'],
            color: Colors.green,
            icon: Icons.auto_graph_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SwCard(
            title: 'Weaknesses',
            items: const [
              'Biology Genetics',
              'Inorganic Chem',
              'Time Management',
            ],
            color: Colors.red,
            icon: Icons.trending_down_rounded,
          ),
        ),
      ],
    );
  }
}

class _SwCard extends StatelessWidget {
  const _SwCard({
    required this.title,
    required this.items,
    required this.color,
    required this.icon,
  });
  final String title;
  final List<String> items;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $item',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.inkSoft(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 11. Recommended Next Study
class _RecommendedStudy extends StatelessWidget {
  const _RecommendedStudy();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Recommended Next Steps'),
        const SizedBox(height: 16),
        _StudyRecommendationItem(
          title: 'Acid-Base Imbalance Video',
          type: 'Video Lecture',
          duration: '15 mins',
          icon: Icons.play_circle_fill,
          color: Colors.red,
        ),
        const SizedBox(height: 12),
        _StudyRecommendationItem(
          title: 'Neurological Disorders Notes',
          type: 'Study Material',
          duration: '10 pages',
          icon: Icons.description,
          color: Colors.orange,
        ),
      ],
    );
  }
}

class _StudyRecommendationItem extends StatelessWidget {
  const _StudyRecommendationItem({
    required this.title,
    required this.type,
    required this.duration,
    required this.icon,
    required this.color,
  });
  final String title, type, duration;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line(context)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppTheme.ink(context),
                  ),
                ),
                Text(
                  '$type • $duration',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}

// 12. Question Review
class _QuestionReviewSection extends StatelessWidget {
  const _QuestionReviewSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          const Text(
            'Question Review',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ReviewStat(label: 'Correct', count: 18, color: Colors.green),
              _ReviewStat(label: 'Incorrect', count: 4, color: Colors.red),
              _ReviewStat(label: 'Skipped', count: 2, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Review Incorrect Questions',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewStat extends StatelessWidget {
  const _ReviewStat({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// 13. Achievements
class _AchievementsSection extends StatelessWidget {
  const _AchievementsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Achievements Earned'),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: const [
              _AchievementBadge(
                label: 'Speedster',
                icon: Icons.bolt,
                color: Colors.orange,
              ),
              _AchievementBadge(
                label: 'Sharpshooter',
                icon: Icons.gps_fixed,
                color: Colors.blue,
              ),
              _AchievementBadge(
                label: '7 Day Streak',
                icon: Icons.local_fire_department,
                color: Colors.red,
              ),
              _AchievementBadge(
                label: 'Master',
                icon: Icons.auto_awesome,
                color: Colors.purple,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  const _AchievementBadge({
    required this.label,
    required this.icon,
    required this.color,
  });
  final String label;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// 14. Download & Share Report
class _DownloadShareSection extends StatelessWidget {
  const _DownloadShareSection();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download PDF'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: IconButton(
            icon: const Icon(Icons.share_rounded, color: AppTheme.primary),
            onPressed: () {},
            padding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}

// Reusable Section Header
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppTheme.ink(context),
        letterSpacing: -0.5,
      ),
    );
  }
}
