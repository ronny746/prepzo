import 'package:flutter/material.dart';
import 'package:lms/features/courses/data/models/course_model.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Same rule as the website (`src/app/course/[id]/page.tsx`): the planner is
/// shown for the Shakti test series, matched by course name or tag.
bool isShaktiCourse(CourseModel course) {
  final re = RegExp('shakti', caseSensitive: false);
  return re.hasMatch(course.name) || re.hasMatch(course.tag ?? '');
}

/// App version of the website's `ShaktiPlanner` (components/course/
/// ShaktiPlanner.tsx). Keep the dates and counts in step with that file.
class ShaktiPlanner extends StatelessWidget {
  const ShaktiPlanner({super.key});

  static const _navy = Color(0xFF0B203C);
  static const _goldLight = Color(0xFFE2B653);
  static const _cream = Color(0xFFFAF7EF);
  static const _line = Color(0xFFE4DED0);
  static const _muted = Color(0xFF6B7486);
  static const _body = Color(0xFF3C4A60);
  static const _green = Color(0xFF0C8044);

  // 117 in total; the total is a chip in the header so these four sit in a
  // tidy 2 x 2 grid.
  static const _stats = [
    ('81', 'Chapter tests'),
    ('10', 'Part tests'),
    ('25', 'Full mocks'),
    ('1', 'Free mock'),
  ];

  static const _phases = [
    _Phase(
      '01',
      'Launch and first look',
      '25–29 Nov',
      _Tone.violet,
      'All 81 chapter tests open on day one, followed by a free full-syllabus mock.',
      [
        ('25 Nov', 'LIVE', '81 chapter tests open'),
        ('29 Nov', 'FREE', 'All-India Mock'),
      ],
    ),
    _Phase(
      '02',
      'Revise by quarter',
      '2–13 Dec',
      _Tone.blue,
      'Four part tests cover one syllabus quarter at a time.',
      [
        ('02 Dec', 'PT1', 'Class 11 · first half'),
        ('06 Dec', 'PT2', 'Class 11 · second half'),
        ('09 Dec', 'PT3', 'Class 12 · first half'),
        ('13 Dec', 'PT4', 'Class 12 · second half'),
      ],
    ),
    _Phase(
      '03',
      'Second round and first mocks',
      '16–30 Dec',
      _Tone.green,
      'Repeat each quarter at a higher level, then move into full papers over the break.',
      [
        ('16 Dec', 'PT5', 'Q1 · round 2'),
        ('19 Dec', 'PT6', 'Q2 · round 2'),
        ('20 Dec', 'FT1', 'Full syllabus'),
        ('25 Dec', 'FT2', 'Full syllabus'),
        ('30 Dec', 'FT4', 'Full syllabus'),
      ],
    ),
    _Phase(
      '04',
      'Full-mock sprint',
      '2–17 Jan',
      _Tone.green,
      'A full paper every second day, calibrated to real JEE Main shifts.',
      [
        ('02 Jan', 'FT5', 'Full syllabus'),
        ('06 Jan', 'FT7', 'Full syllabus'),
        ('10 Jan', 'FT9', 'Toughest paper'),
        ('17 Jan', 'FT13', 'Final confidence paper'),
      ],
    ),
    _Phase(
      '05',
      'JEE Main Session 1',
      '20–28 Jan',
      _Tone.gold,
      'Gap mocks keep preparation moving around the January exam window.',
      [
        ('20–24 Jan', 'JEE', 'Session 1 exam days'),
        ('25 Jan', 'FT14', 'Gap mock'),
        ('26 Jan', 'FT15', 'Gap mock'),
      ],
    ),
    _Phase(
      '06',
      'Session 2 track',
      '14–31 Mar',
      _Tone.navy,
      'Ten more full mocks after boards, ahead of Session 2 on 2–7 April.',
      [
        ('14 Mar', 'FT16', 'Full syllabus'),
        ('21 Mar', 'FT19', 'Full syllabus'),
        ('31 Mar', 'FT25', 'Final full mock'),
      ],
    ),
  ];

  static const _quarters = [
    (
      'Q1',
      'Class 11 · first half',
      'Units, kinematics, laws of motion',
      'Basic concepts, atom, periodic table',
      'Quadratics, sequences, trigonometry',
    ),
    (
      'Q2',
      'Class 11 · second half',
      'Gravitation, thermal physics, waves',
      'Equilibrium, redox, GOC, hydrocarbons',
      'Coordinate geometry, limits, statistics',
    ),
    (
      'Q3',
      'Class 12 · first half',
      'Electrostatics, current, magnetism, AC',
      'Solutions, electrochemistry, kinetics',
      'Calculus basics, matrices, determinants',
    ),
    (
      'Q4',
      'Class 12 · second half',
      'Optics, dual nature, atoms, nuclei',
      'Organic, biomolecules, practical chemistry',
      'Integration, vectors, 3D, probability',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _hero(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _statsGrid(),
                const SizedBox(height: 24),
                _heading('The Shakti schedule', 'Six levels of preparation'),
                const SizedBox(height: 12),
                for (final p in _phases) ...[
                  _PhaseCard(phase: p),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 14),
                _heading('Part-test syllabus map', 'What each quarter covers'),
                const SizedBox(height: 12),
                for (final q in _quarters) ...[
                  _quarterCard(q),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
                _footer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    return Container(
      color: _navy,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PhosphorIcon(
                PhosphorIcons.lightning,
                size: 14,
                color: _goldLight,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'SHAKTI SCHEDULE · JEE MAIN 2027',
                  style: const TextStyle(
                    color: _goldLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Build your exam power, date by date.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'One ladder from chapter tests to part tests to full mocks, planned around both JEE Main sessions.',
            style: TextStyle(
              color: Color(0xFFB9C3D4),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in const [
                '117 tests',
                'Series live · 25 Nov',
                'Session 1 · 20–28 Jan',
                'Session 2 · 2–7 Apr',
              ])
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    chip,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Wrap (not a fixed-ratio grid) so bigger system fonts grow the tiles
  // instead of overflowing them.
  Widget _statsGrid() {
    return LayoutBuilder(
      builder: (context, c) {
        final tileWidth = (c.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (value, label) in _stats)
              Container(
                width: tileWidth,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _heading(String eyebrow, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            color: _green,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: _navy,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // One card per quarter instead of the website's wide table, which would
  // not fit a phone screen.
  Widget _quarterCard((String, String, String, String, String) q) {
    final (code, span, physics, chemistry, maths) = q;
    Widget row(String subject, String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              subject,
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _body, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$code  ',
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                TextSpan(
                  text: span,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          row('Physics', physics),
          row('Chemistry', chemistry),
          row('Mathematics', maths),
        ],
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(PhosphorIcons.target, size: 18, color: _goldLight),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Real NTA-level practice',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Every paper includes detailed solutions, score analysis and a clear next action.',
            style: TextStyle(
              color: Color(0xFFB9C3D4),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

enum _Tone {
  violet(Color(0xFFF5F3FF), Color(0xFF6D28D9), Color(0xFFDDD6FE)),
  blue(Color(0xFFEFF6FF), Color(0xFF1D4ED8), Color(0xFFBFDBFE)),
  green(Color(0xFFECFDF5), Color(0xFF047857), Color(0xFFA7F3D0)),
  gold(Color(0xFFFFFBEB), Color(0xFF92400E), Color(0xFFFDE68A)),
  navy(Color(0xFFF1F5F9), Color(0xFF0B132B), Color(0xFFE2E8F0));

  const _Tone(this.bg, this.fg, this.border);
  final Color bg;
  final Color fg;
  final Color border;
}

class _Phase {
  const _Phase(
    this.level,
    this.title,
    this.dates,
    this.tone,
    this.copy,
    this.items,
  );
  final String level;
  final String title;
  final String dates;
  final _Tone tone;
  final String copy;
  final List<(String, String, String)> items;
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.phase});
  final _Phase phase;

  @override
  Widget build(BuildContext context) {
    final t = phase.tone;
    Widget tag(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: t.fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShaktiPlanner._line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    tag('LEVEL ${phase.level}'),
                    const SizedBox(height: 6),
                    Text(
                      phase.title,
                      style: const TextStyle(
                        color: ShaktiPlanner._navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ShaktiPlanner._cream,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  phase.dates,
                  style: const TextStyle(
                    color: ShaktiPlanner._muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            phase.copy,
            style: const TextStyle(
              color: ShaktiPlanner._body,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          for (final (date, code, label) in phase.items)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(
                      date,
                      style: const TextStyle(
                        color: ShaktiPlanner._muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  tag(code),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ShaktiPlanner._body,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
