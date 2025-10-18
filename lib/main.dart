import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:lottie/lottie.dart';

// ========================= CONFIGURACIÓN =========================
/// Colores de fondo de cada opción (A, B, C, D): rojo, azul, amarillo, púrpura
const List<Color> kOptionColors = <Color>[
  Color(0xFFFF3B30), // rojo
  Color(0xFF007AFF), // azul
  Color(0xFFFFD60A), // amarillo
  ui.Color.fromARGB(255, 24, 226, 34), // púrpura
];

// ========================= MODELOS ===============================
class AppStrings {
  final String headerSubtitle;
  final String tapToStart;
  final String backButton;
  final String correctMessage;
  final String wrongMessage;
  final String questionLabel;

  AppStrings({
    required this.headerSubtitle,
    required this.tapToStart,
    required this.backButton,
    required this.correctMessage,
    required this.wrongMessage,
    required this.questionLabel,
  });

  factory AppStrings.fromJson(Map<String, dynamic> map) {
    return AppStrings(
      headerSubtitle: map['header_subtitle'] as String,
      tapToStart: map['tap_to_start'] as String,
      backButton: map['back_button'] as String,
      correctMessage: map['correct_message'] as String,
      wrongMessage: map['wrong_message'] as String,
      questionLabel: map['question_label'] as String,
    );
  }
}

class LanguageInfo {
  final String code;
  final String name;
  final String flagPath;

  LanguageInfo({
    required this.code,
    required this.name,
    required this.flagPath,
  });
}

class Question {
  final String q;
  final List<String> options; // 4 opciones
  final int answerIndex; // 0..3

  Question({required this.q, required this.options, required this.answerIndex});

  factory Question.fromMap(Map<String, dynamic> map) {
    final opts = (map['options'] as List).map((e) => e.toString()).toList();
    return Question(
      q: map['q'] as String,
      options: List<String>.from(opts),
      answerIndex: map['answer_index'] as int,
    );
  }
}

class Category {
  final String id;
  final String name;
  final String icon;
  final String colorHex;
  final List<Question> questions;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
    required this.questions,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    final qs = (map['questions'] as List)
        .map((m) => Question.fromMap(m as Map<String, dynamic>))
        .toList();
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon']?.toString() ?? 'help',
      colorHex: map['color']?.toString() ?? '#2196F3',
      questions: qs,
    );
  }

  Color color() => _parseHexColor(colorHex);
}

class Dataset {
  final int version;
  final List<Category> categories;

  Dataset({required this.version, required this.categories});

  factory Dataset.fromJson(String jsonStr) {
    final map = json.decode(jsonStr) as Map<String, dynamic>;
    final cats = (map['categories'] as List)
        .map((m) => Category.fromMap(m as Map<String, dynamic>))
        .toList();
    return Dataset(version: map['version'] as int, categories: cats);
  }
}

// Pregunta preparada con opciones mezcladas y nuevo índice de correcta.
class PreparedQuestion {
  final String text;
  final List<String> shuffledOptions;
  final int correctIndex;

  PreparedQuestion({
    required this.text,
    required this.shuffledOptions,
    required this.correctIndex,
  });
}

// ========================= UTILIDADES ============================
// Lista de idiomas disponibles
final List<LanguageInfo> kAvailableLanguages = [
  LanguageInfo(code: 'es', name: 'Español', flagPath: 'assets/flags/es.png'),
  LanguageInfo(code: 'en', name: 'English (UK)', flagPath: 'assets/flags/en.png'),
  LanguageInfo(code: 'us', name: 'English (USA)', flagPath: 'assets/flags/us.png'),
  LanguageInfo(code: 'de', name: 'Deutsch', flagPath: 'assets/flags/de.png'),
  LanguageInfo(code: 'fr', name: 'Français', flagPath: 'assets/flags/fr.png'),
  LanguageInfo(code: 'it', name: 'Italiano', flagPath: 'assets/flags/it.png'),
  LanguageInfo(code: 'ca', name: 'Català', flagPath: 'assets/flags/ca.png'),
  LanguageInfo(code: 'eu', name: 'Euskara', flagPath: 'assets/flags/eu.png'),
  LanguageInfo(code: 'mx', name: 'Mexicano', flagPath: 'assets/flags/mx.png'),
];

Color _parseHexColor(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

IconData _iconFromString(String s) {
  switch (s) {
    case 'science':
      return Icons.science;
    case 'palette':
      return Icons.palette;
    case 'category':
      return Icons.category;
    case 'sports_soccer':
      return Icons.sports_soccer;
    case 'public':
      return Icons.public;
    case 'history':
      return Icons.history;
    case 'movie':
      return Icons.movie;
    default:
      return Icons.help_outline;
  }
}

T pickRandom<T>(List<T> list, Random rng) => list[rng.nextInt(list.length)];

PreparedQuestion prepareQuestion(Question q, Random rng) {
  final opts = List<String>.from(q.options);
  final correctValue = opts[q.answerIndex];
  opts.shuffle(rng);
  final newIndex = opts.indexOf(correctValue);
  return PreparedQuestion(
    text: q.q,
    shuffledOptions: opts,
    correctIndex: newIndex,
  );
}

List<PreparedQuestion> prepareGameQuestions(
  List<Question> all,
  int count,
  Random rng,
) {
  final sample = List<Question>.from(all)..shuffle(rng);
  final take = sample.take(min(count, all.length)).toList();
  return take.map((q) => prepareQuestion(q, rng)).toList();
}

Color bestTextColorFor(Color bg) =>
    bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;

// ========================= MAIN & APP ============================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  runApp(const QuizApp());
}

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BCD4),
          brightness: Brightness.dark,
        ),
      ),
      home: const _DatasetLoader(),
    );
  }
}

// Carga del JSON antes de enseñar la parrilla de categorías.
class _DatasetLoader extends StatefulWidget {
  const _DatasetLoader();
  @override
  State<_DatasetLoader> createState() => _DatasetLoaderState();
}

class _DatasetLoaderState extends State<_DatasetLoader> {
  String _currentLanguage = 'es';
  Future<Dataset>? _datasetFuture;
  Future<AppStrings>? _stringsFuture;

  @override
  void initState() {
    super.initState();
    _loadLanguage(_currentLanguage);
  }

  void _loadLanguage(String langCode) {
    setState(() {
      _currentLanguage = langCode;
      _datasetFuture = rootBundle
          .loadString('assets/questions/questions_$langCode.json')
          .then(Dataset.fromJson);
      _stringsFuture = rootBundle
          .loadString('assets/i18n/$langCode.json')
          .then((str) => AppStrings.fromJson(json.decode(str)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([_datasetFuture!, _stringsFuture!]),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F0F23),
                    Color(0xFF1A1A2E),
                    Color(0xFF16213E),
                  ],
                ),
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snap.hasError || snap.data == null) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F0F23),
                    Color(0xFF1A1A2E),
                    Color(0xFF16213E),
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  'Error cargando preguntas.\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        }
        final dataset = snap.data![0] as Dataset;
        final strings = snap.data![1] as AppStrings;
        return CategoryGridScreen(
          dataset: dataset,
          strings: strings,
          currentLanguage: _currentLanguage,
          onLanguageChanged: _loadLanguage,
        );
      },
    );
  }
}

class QuestionDecks {
  static final Map<String, List<int>> _orderByCat = {};
  static final Map<String, int> _posByCat = {};

  static void _buildOrder(Category cat, Random rng) {
    // normalizamos para evitar duplicados por mayúsculas, espacios, signos, etc.
    String _normalize(String s) {
      final lower = s.toLowerCase().trim();
      final collapsed = lower.replaceAll(RegExp(r'\s+'), ' ');
      // quitamos puntuación (mantiene letras con acentos y números)
      return collapsed.replaceAll(
        RegExp(r'[^\p{L}\p{N}\s]', unicode: true),
        '',
      );
    }

    final seen = <String>{};
    final indices = <int>[];
    for (var i = 0; i < cat.questions.length; i++) {
      final key = _normalize(cat.questions[i].q);
      if (seen.add(key)) indices.add(i);
    }

    indices.shuffle(rng);
    _orderByCat[cat.id] = indices;
    _posByCat[cat.id] = 0;
  }

  static List<Question> take(Category cat, int count, Random rng) {
    if (!_orderByCat.containsKey(cat.id)) {
      _buildOrder(cat, rng);
    }

    final order = _orderByCat[cat.id]!;
    var pos = _posByCat[cat.id]!;
    final remaining = order.length - pos;

    if (count > remaining) count = remaining;

    final slice = order.sublist(pos, pos + count);
    pos += count;

    if (pos >= order.length) {
      _buildOrder(cat, rng);
    } else {
      _posByCat[cat.id] = pos;
    }

    return slice.map((i) => cat.questions[i]).toList();
  }

  static void reset(Category cat) {
    _orderByCat.remove(cat.id);
    _posByCat.remove(cat.id);
  }
}

// ========================= UI: CATEGORÍAS ========================

class QuizHeader extends StatefulWidget {
  const QuizHeader({
    Key? key,
    this.title = 'QUIZ GAME',
    this.subtitle = 'Elige una categoría',
    this.titleFontSize,
    this.subtitleFontSize,
    this.headerHeight = 250,
    this.useAutoFitTitle = false,
    this.useAutoFitSubtitle = false,
  }) : super(key: key);

  final String title;
  final String subtitle;
  final double? titleFontSize;
  final double? subtitleFontSize;
  final double headerHeight;
  final bool useAutoFitTitle;
  final bool useAutoFitSubtitle;

  @override
  State<QuizHeader> createState() => _QuizHeaderState();
}

class _QuizHeaderState extends State<QuizHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double titleSize = widget.titleFontSize ?? 90;
    final double subtitleSize = widget.subtitleFontSize ?? 35;

    final baseTitle = TextStyle(
      fontSize: titleSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 2,
      height: 1.0,
    );

    final subtitleStyle = TextStyle(
      fontSize: subtitleSize,
      fontWeight: FontWeight.w700,
      color: Colors.white.withOpacity(0.9),
      letterSpacing: 1.2,
      shadows: [
        Shadow(
          color: Colors.black.withOpacity(0.4),
          offset: const Offset(0, 2),
          blurRadius: 6,
        ),
      ],
    );

    Widget gradientOutlined(String text) {
      return AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final angle = _ctrl.value * 6.28318530718;
          return Stack(
            alignment: Alignment.center,
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: baseTitle.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 8
                    ..color = Colors.black.withOpacity(0.55),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: const [
                    Color(0xFF7C3AED),
                    Color(0xFF06B6D4),
                    Color(0xFF22C55E),
                  ],
                  transform: GradientRotation(angle),
                ).createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: baseTitle.copyWith(
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.white.withOpacity(0.25),
                        blurRadius: 10,
                      ),
                      Shadow(
                        color: Colors.purpleAccent.withOpacity(0.5),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      );
    }

    Widget maybeFit({required bool fit, required Widget child}) {
      return fit ? FittedBox(fit: BoxFit.scaleDown, child: child) : child;
    }

    return Container(
      height: widget.headerHeight,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          maybeFit(
            fit: widget.useAutoFitTitle,
            child: gradientOutlined(widget.title),
          ),
          const SizedBox(height: 8),
          maybeFit(
            fit: widget.useAutoFitSubtitle,
            child: Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: subtitleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryGridScreen extends StatelessWidget {
  final Dataset dataset;
  final AppStrings strings;
  final String currentLanguage;
  final Function(String) onLanguageChanged;

  const CategoryGridScreen({
    super.key,
    required this.dataset,
    required this.strings,
    required this.currentLanguage,
    required this.onLanguageChanged,
  });

  void _showLanguageSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _LanguageModal(
        currentLanguage: currentLanguage,
        onLanguageSelected: (code) {
          Navigator.of(context).pop();
          onLanguageChanged(code);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    const double headerHeightRatio = 0.35;
    final double headerHeight = screenHeight * headerHeightRatio;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0F23), Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                QuizHeader(
                  titleFontSize: 100,
                  subtitle: strings.headerSubtitle,
                  subtitleFontSize: 20,
                  headerHeight: (headerHeight),
                  useAutoFitTitle: true,
                  useAutoFitSubtitle: true,
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          childAspectRatio: 6,
                        ),
                    itemCount: dataset.categories.length,
                    itemBuilder: (context, index) {
                      return _CategoryCard(
                        category: dataset.categories[index],
                        tapToStartText: strings.tapToStart,
                        strings: strings,
                      );
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              top: 16,
              right: 16,
              child: _LanguageButton(
                currentLanguage: currentLanguage,
                onTap: () => _showLanguageSelector(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final Category category;
  final String tapToStartText;
  final AppStrings strings;
  const _CategoryCard({
    required this.category,
    required this.tapToStartText,
    required this.strings,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = _iconFromString(widget.category.icon);

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        setState(() => _isPressed = false);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QuizScreen(
              category: widget.category,
              strings: widget.strings,
            ),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..scale(_isPressed ? 0.96 : 1.0)
          ..rotateZ(_isPressed ? -0.01 : 0.0),
        child: SizedBox.expand(
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _shimmerAnimation,
                  builder: (context, child) {
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.05),
                            Colors.white.withOpacity(0.12),
                            Colors.white.withOpacity(0.05),
                          ],
                          begin: Alignment(_shimmerAnimation.value, -1),
                          end: Alignment(_shimmerAnimation.value + 1, 1),
                          stops: const [0.0, 0.5, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    );
                  },
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.10),
                        Colors.white.withOpacity(0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                        spreadRadius: -5,
                      ),
                      BoxShadow(
                        color: widget.category.color().withOpacity(0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'category-icon-${widget.category.name}',
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                widget.category.color().withOpacity(1.0),
                                widget.category.color().withOpacity(0.7),
                              ],
                              center: const Alignment(-0.3, -0.3),
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.category.color().withOpacity(0.5),
                                blurRadius: _isPressed ? 20 : 25,
                                spreadRadius: _isPressed ? 0 : 3,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: 40,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.4),
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.category.name,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.5),
                                    offset: const Offset(0, 2),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.tapToStartText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.7),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        transform: Matrix4.identity()
                          ..translate(_isPressed ? 5.0 : 0.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white.withOpacity(0.9),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========================= BOTÓN DE IDIOMA =======================

class _LanguageButton extends StatelessWidget {
  final String currentLanguage;
  final VoidCallback onTap;

  const _LanguageButton({
    required this.currentLanguage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final langInfo = kAvailableLanguages.firstWhere(
      (l) => l.code == currentLanguage,
      orElse: () => kAvailableLanguages[0],
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            langInfo.flagPath,
            fit: BoxFit.cover,
            errorBuilder: (
                context, error, stack) => const Icon(
              Icons.language,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

// ========================= MODAL DE IDIOMAS ======================

class _LanguageModal extends StatelessWidget {
  final String currentLanguage;
  final Function(String) onLanguageSelected;

  const _LanguageModal({
    required this.currentLanguage,
    required this.onLanguageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.12),
              Colors.white.withOpacity(0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.05),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.language,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Selecciona idioma',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                        iconSize: 28,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 2.5,
                    ),
                    itemCount: kAvailableLanguages.length,
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      final lang = kAvailableLanguages[index];
                      final isSelected = lang.code == currentLanguage;
                      return _LanguageItem(
                        language: lang,
                        isSelected: isSelected,
                        onTap: () => onLanguageSelected(lang.code),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageItem extends StatefulWidget {
  final LanguageInfo language;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageItem({
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_LanguageItem> createState() => _LanguageItemState();
}

class _LanguageItemState extends State<_LanguageItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()
          ..scale(_isPressed ? 0.95 : 1.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.isSelected
                ? [
                    const Color(0xFF7C3AED).withOpacity(0.4),
                    const Color(0xFF06B6D4).withOpacity(0.4),
                  ]
                : [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isSelected
                ? Colors.white.withOpacity(0.5)
                : Colors.white.withOpacity(0.2),
            width: widget.isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            if (widget.isSelected)
              BoxShadow(
                color: const Color(0xFF7C3AED).withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  widget.language.flagPath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => const Icon(
                    Icons.flag,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.language.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: widget.isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ========================= UI: QUIZ ==============================

class QuizScreen extends StatefulWidget {
  final Category category;
  final AppStrings strings;
  const QuizScreen({
    super.key,
    required this.category,
    required this.strings,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  final Random _rng = Random();

  PreparedQuestion? _current;
  int _questionNumber = 0;

  final Set<int> _wrongIndices = <int>{};
  bool _showCorrectOverlay = false;
  double _overlayOpacity = 0.0;
  bool _showWrongOverlay = false;
  double _wrongOverlayOpacity = 0.0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _loadNextQuestion();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.98, end: 1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _confetti = ConfettiController(duration: const Duration(milliseconds: 900));
  }

  void _loadNextQuestion() {
    final selected = QuestionDecks.take(widget.category, 1, _rng);
    final pq = prepareQuestion(selected.first, _rng);
    _current = pq;
    _wrongIndices.clear();
    _questionNumber += 1;
    setState(() {});
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _confetti.dispose();
    QuestionDecks.reset(widget.category);
    super.dispose();
  }

  void _onTapOption(int optionIndex) {
    if (_showCorrectOverlay || _showWrongOverlay) return;

    final pq = _current!;
    if (optionIndex == pq.correctIndex) {
      _showCorrectAndProceed();
    } else {
      _showWrongAndNext();
    }
  }

  Future<void> _showCorrectAndProceed() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _showCorrectOverlay = true;
      _overlayOpacity = 0.0;
      _wrongIndices.clear();
    });

    await Future.delayed(const Duration(milliseconds: 10));
    setState(() => _overlayOpacity = 1.0);
    _confetti.play();

    await Future.delayed(const Duration(milliseconds: 2000));

    setState(() => _overlayOpacity = 0.0);
    await Future.delayed(const Duration(milliseconds: 200));

    if (!mounted) return;
    setState(() => _showCorrectOverlay = false);

    _loadNextQuestion();
  }

  Future<void> _showWrongAndNext() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _showWrongOverlay = true;
      _wrongOverlayOpacity = 0.0;
      _wrongIndices.clear();
    });

    await Future.delayed(const Duration(milliseconds: 10));
    setState(() => _wrongOverlayOpacity = 1.0);

    await Future.delayed(const Duration(milliseconds: 2000));

    setState(() => _wrongOverlayOpacity = 0.0);
    await Future.delayed(const Duration(milliseconds: 200));

    if (!mounted) return;
    setState(() {
      _showWrongOverlay = false;
    });

    _loadNextQuestion();
  }

  @override
  Widget build(BuildContext context) {
    final pq = _current;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0F23), Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Center(
                            child: Text(
                              widget.category.name.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.exit_to_app_rounded),
                              label: Text(widget.strings.backButton),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (pq != null)
                      _QuestionCard(
                        text: pq.text,
                        index: _questionNumber - 1,
                        total: 0,
                        questionLabel: widget.strings.questionLabel,
                      ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const cols = 2;
                          const rows = 2;
                          const mainSpacing = 12.0;
                          const crossSpacing = 12.0;

                          final w = constraints.maxWidth;
                          final h = constraints.maxHeight;

                          final itemW = (w - (cols - 1) * crossSpacing) / cols;
                          final itemH = (h - (rows - 1) * mainSpacing) / rows;
                          final aspect = itemW / itemH;

                          return GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  mainAxisSpacing: mainSpacing,
                                  crossAxisSpacing: crossSpacing,
                                  childAspectRatio: aspect,
                                ),
                            itemCount: 4,
                            itemBuilder: (context, i) {
                              final bg = kOptionColors[i];
                              final isWrong = _wrongIndices.contains(i);
                              return AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, child) {
                                  return _AnswerTile(
                                    label: pq!.shuffledOptions[i],
                                    background: bg,
                                    isWrong: isWrong,
                                    onTap: () => _onTapOption(i),
                                    pulseScale: _pulseAnimation.value,
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (_showCorrectOverlay)
                _ResultOverlay(
                  opacity: _overlayOpacity,
                  isCorrect: true,
                  confetti: _confetti,
                  message: widget.strings.correctMessage,
                ),
              if (_showWrongOverlay)
                _ResultOverlay(
                  opacity: _wrongOverlayOpacity,
                  isCorrect: false,
                  message: widget.strings.wrongMessage,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========================= WIDGETS ===============================

class _QuestionCard extends StatelessWidget {
  final String text;
  final int index;
  final int total;
  final String questionLabel;
  const _QuestionCard({
    required this.text,
    required this.index,
    required this.total,
    required this.questionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final leftBadge = total <= 0
        ? '$questionLabel ${index + 1}'
        : '${index + 1}/$total';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Text(
              leftBadge,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  final String label;
  final Color background;
  final bool isWrong;
  final VoidCallback onTap;
  final double pulseScale;

  const _AnswerTile({
    required this.label,
    required this.background,
    required this.isWrong,
    required this.onTap,
    required this.pulseScale,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = bestTextColorFor(background);

    return GestureDetector(
      onTap: onTap,
      child: Transform.scale(
        scale: pulseScale,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Container(color: background.withOpacity(0.88)),
              BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: const SizedBox.expand(),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.18),
                      Colors.white.withOpacity(0.06),
                    ],
                  ),
                  border: Border.all(
                    color: (isWrong ? Colors.redAccent : Colors.white)
                        .withOpacity(0.28),
                    width: isWrong ? 2.5 : 1.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 64,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.20),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  final double opacity;
  final bool isCorrect;
  final String message;
  final ConfettiController? confetti;

  const _ResultOverlay({
    required this.opacity,
    required this.isCorrect,
    required this.message,
    this.confetti,
  });

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double animSide = (size.shortestSide * 0.2).clamp(220.0, 520.0);

    return IgnorePointer(
      ignoring: true,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 200),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: isCorrect
                        ? [
                            const Color(0xFF00D4AA).withOpacity(0.95),
                            const Color(0xFF06B6D4).withOpacity(0.9),
                            Colors.black.withOpacity(0.95),
                          ]
                        : [
                            Colors.amberAccent.withOpacity(0.90),
                            const ui.Color.fromARGB(255, 255, 109, 64)
                                .withOpacity(0.95),
                            Colors.black.withOpacity(0.92),
                          ],
                    center: Alignment.center,
                    radius: 2.0,
                  ),
                ),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            if (isCorrect && confetti != null) ...[
              Align(
                alignment: Alignment.topLeft,
                child: ConfettiWidget(
                  confettiController: confetti!,
                  blastDirectionality: BlastDirectionality.explosive,
                  emissionFrequency: 0.6,
                  numberOfParticles: 250,
                  gravity: 1,
                  shouldLoop: true,
                  colors: const [
                    Color(0xFFFF007F),
                    Color(0xFFFF1493),
                    Color(0xFFB026FF),
                    Color(0xFF7DF9FF),
                    Color(0xFF39FF14),
                    Color(0xFFFFAA00),
                    Color(0xFFFF4D00),
                    Color(0xFFFFD700),
                    Color(0xFF40E0D0),
                    Color(0xFFFFA6C9),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: ConfettiWidget(
                  confettiController: confetti!,
                  blastDirectionality: BlastDirectionality.explosive,
                  emissionFrequency: 0.6,
                  numberOfParticles: 250,
                  gravity: 1,
                  shouldLoop: true,
                  colors: const [
                    Color(0xFFFF007F),
                    Color(0xFFFF1493),
                    Color(0xFFB026FF),
                    Color(0xFF7DF9FF),
                    Color(0xFF39FF14),
                    Color(0xFFFFAA00),
                    Color(0xFFFF4D00),
                    Color(0xFFFFD700),
                    Color(0xFF40E0D0),
                    Color(0xFFFFA6C9),
                  ],
                ),
              ),
            ] else ...[
              Center(
                child: SizedBox(
                  width: animSide,
                  height: animSide,
                  child: Lottie.asset(
                    'assets/anim/error.json',
                    repeat: true,
                    frameRate: FrameRate.max,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
            Positioned.fill(
              child: Align(
                alignment: Alignment(0, isCorrect ? 0.1 : 0.4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCorrect)
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 800),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              padding: const EdgeInsets.all(30),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF00D4AA),
                                    Color(0xFF06B6D4),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                size: 100,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                    if (isCorrect) const SizedBox(height: 28),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 20,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}