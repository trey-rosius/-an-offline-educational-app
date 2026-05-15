import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/glass_theme.dart';
import 'models/entities.dart';
import 'services/rag_service.dart';
import 'pdf_rag_screen.dart';
import 'screens/study_hub_screen.dart';
import 'screens/analytics_screen.dart';
import 'services/study_material_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';
import 'objectbox.g.dart';

class CategoryBrowserScreen extends StatefulWidget {
  final RagService ragService;

  const CategoryBrowserScreen({super.key, required this.ragService});

  @override
  State<CategoryBrowserScreen> createState() => _CategoryBrowserScreenState();
}

class _CategoryBrowserScreenState extends State<CategoryBrowserScreen> {
  static const _viewPrefKey = 'library_grid_view';

  List<SubjectCategory> _categories = [];
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _restoreViewPreference();
  }

  void _loadCategories() {
    setState(() {
      _categories = widget.ragService.getAllCategories();
    });
  }

  Future<void> _restoreViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isGridView = prefs.getBool(_viewPrefKey) ?? false;
    });
  }

  Future<void> _toggleView() async {
    setState(() {
      _isGridView = !_isGridView;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_viewPrefKey, _isGridView);
  }

  void _scanKnowledge() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );

    if (result != null) {
      try {
        String jsonStr = result;

        // If it's a sharing URL, download the full content
        if (result.startsWith('lgshare://')) {
          final url = result.replaceFirst('lgshare://', 'http://');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Connecting to friend\'s phone...')),
            );
          }

          final response = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            jsonStr = response.body;
          } else {
            throw Exception('Failed to connect to sender');
          }
        }

        final Map<String, dynamic> data = jsonDecode(jsonStr);
        if (data['origin'] == 'LocalGemma') {
          final categoryBox = objectBox.store.box<SubjectCategory>();
          SubjectCategory? sharedCat = categoryBox
              .query(SubjectCategory_.name.equals('Shared Knowledge'))
              .build()
              .findFirst();

          if (sharedCat == null) {
            sharedCat = SubjectCategory(name: 'Shared Knowledge');
            categoryBox.put(sharedCat);
          }

          final material = GeneratedStudyMaterial(
            type: data['type'],
            title: data['title'],
            contentJson: data['content'],
            dateCreated: DateTime.now(),
          );
          material.category.target = sharedCat;

          objectBox.store.box<GeneratedStudyMaterial>().put(material);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Imported "${data['title']}" successfully!')),
            );
            _loadCategories();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Import Error: $e')),
          );
        }
      }
    }
  }

  void _deleteCategory(SubjectCategory category) {
    showDialog(
      context: context,
      builder: (context) => _GlassDialog(
        title: 'Delete Subject?',
        content: 'This will remove "${category.name}" and all its documents.',
        confirmLabel: 'Delete',
        confirmColor: const Color(0xFFFF5C7A),
        onConfirm: () {
          widget.ragService.categoryBox.remove(category.id);
          _loadCategories();
        },
      ),
    );
  }

  void _confirmWipe() {
    showDialog(
      context: context,
      builder: (context) => _GlassDialog(
        title: 'Wipe Library?',
        content:
            'This will erase ALL subjects and PDFs. This cannot be undone.',
        confirmLabel: 'Wipe All',
        confirmColor: const Color(0xFFFF5C7A),
        onConfirm: () async {
          await widget.ragService.clearAllData();
          _loadCategories();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/bg.jpg"),
          fit: BoxFit.cover,
        ),
      ),
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _buildGlassAppBar(),
      body: _categories.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              color: GlassTheme.accentBlue,
              backgroundColor: GlassTheme.surfaceStrong,
              onRefresh: () async {
                _loadCategories();
              },
              child: _isGridView ? _buildGrid() : _buildList(),
            ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + kToolbarHeight + 12,
        16,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        final docs = widget.ragService.getDocumentsForCategory(category.id);
        return _SubjectCard(
          category: category,
          documents: docs,
          onDelete: () => _deleteCategory(category),
          onOpenStudyHub: () => _openStudyHub(category),
          onQuery: () => _openQuery(category),
          onTapDocument: (doc) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('File path: ${doc.localFilePath}')),
            );
          },
        );
      },
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Aim for ~150px tile width, but never fewer than 2 columns and
        // adapt up on tablets / landscape.
        final width = constraints.maxWidth;
        final columns = width >= 900
            ? 6
            : width >= 700
                ? 5
                : width >= 500
                    ? 4
                    : width >= 360
                        ? 3
                        : 2;

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + kToolbarHeight + 12,
            16,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.92,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            final docs =
                widget.ragService.getDocumentsForCategory(category.id);
            return _SubjectGridTile(
              category: category,
              documentCount: docs.length,
              onTap: () => _showCategoryActions(category, docs.length),
            );
          },
        );
      },
    );
  }

  void _openStudyHub(SubjectCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudyHubScreen(
          category: category,
          materialService:
              StudyMaterialService(widget.ragService, objectBox.store),
          ragService: widget.ragService,
        ),
      ),
    );
  }

  void _openQuery(SubjectCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PdfRagScreen(preSelectedCategory: category.name),
      ),
    );
  }

  void _showCategoryActions(SubjectCategory category, int documentCount) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      isScrollControlled: true,
      builder: (sheetContext) => _CategoryActionsSheet(
        category: category,
        documentCount: documentCount,
        onOpenStudyHub: () {
          Navigator.pop(sheetContext);
          _openStudyHub(category);
        },
        onQuery: () {
          Navigator.pop(sheetContext);
          _openQuery(category);
        },
        onDelete: () {
          Navigator.pop(sheetContext);
          _deleteCategory(category);
        },
      ),
    );
  }

  PreferredSizeWidget _buildGlassAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: AppBar(
            title: const Text(
              'Educational Library',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            backgroundColor: Colors.white.withOpacity(0.06),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              _buildAppBarAction(
                icon: Icons.qr_code_scanner,
                tooltip: 'Import Shared Knowledge',
                onTap: _scanKnowledge,
              ),
              _buildAppBarAction(
                icon: Icons.analytics_outlined,
                tooltip: 'View Stats',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AnalyticsScreen()),
                  );
                },
              ),
              _buildAppBarAction(
                icon: _isGridView
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded,
                tooltip:
                    _isGridView ? 'Switch to list view' : 'Switch to grid view',
                onTap: _toggleView,
              ),
              _buildAppBarAction(
                icon: Icons.delete_sweep,
                tooltip: 'Erase All Data',
                tint: const Color(0xFFFF6B81),
                onTap: _confirmWipe,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color tint = Colors.white,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(icon, color: tint, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              decoration: GlassTheme.panel(radius: 28, strong: true),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/folder.svg',
                    width: 96,
                    height: 96,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Your library is empty',
                    style: TextStyle(
                      color: GlassTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ingest a PDF to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: GlassTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted glass card that represents a single subject (folder) and its docs.
class _SubjectCard extends StatefulWidget {
  final SubjectCategory category;
  final List<StudyDocument> documents;
  final VoidCallback onDelete;
  final VoidCallback onOpenStudyHub;
  final VoidCallback onQuery;
  final void Function(StudyDocument doc) onTapDocument;

  const _SubjectCard({
    required this.category,
    required this.documents,
    required this.onDelete,
    required this.onOpenStudyHub,
    required this.onQuery,
    required this.onTapDocument,
  });

  @override
  State<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<_SubjectCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: GlassTheme.panel(radius: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: _expanded ? _buildBody() : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/folder.svg',
                width: 130,
                height: 130,
                colorFilter: ColorFilter.mode(
                  GlassTheme.folderColor(
                    id: widget.category.id,
                    name: widget.category.name,
                  ),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.category.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.documents.length} document${widget.documents.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: 1,
            color: Colors.white.withOpacity(0.10),
          ),
          ...widget.documents.map((doc) => _buildDocumentTile(doc)),
          if (widget.documents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Text(
                'No documents yet.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _GlassPillButton(
                  icon: Icons.hub_rounded,
                  label: 'Study Hub',
                  accent: const Color(0xFFB388FF),
                  onTap: widget.onOpenStudyHub,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GlassPillButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  accent: const Color(0xFFFF6B81),
                  onTap: widget.onDelete,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _GlassPillButton(
            icon: Icons.search_rounded,
            label: 'Query ${widget.category.name}',
            accent: const Color(0xFF82B1FF),
            filled: true,
            onTap: widget.onQuery,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentTile(StudyDocument doc) {
    final uploaded = doc.uploadTimestamp.toString().split('.')[0];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onTapDocument(doc),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: Color(0xFF82B1FF),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Uploaded: $uploaded',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable frosted-glass pill button.
class _GlassPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accent;
  final bool filled;

  const _GlassPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.accent,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                gradient: filled
                    ? LinearGradient(
                        colors: [
                          accent.withOpacity(0.35),
                          accent.withOpacity(0.18),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: filled ? null : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accent.withOpacity(filled ? 0.55 : 0.30),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: accent),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted-glass dialog used for Delete / Wipe confirmations.
class _GlassDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;

  const _GlassDialog({
    required this.title,
    required this.content,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  content,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withOpacity(0.85),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onConfirm();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: confirmColor,
                        backgroundColor: confirmColor.withOpacity(0.14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: confirmColor.withOpacity(0.55)),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact grid-mode folder tile. Tap opens a glass action sheet.
class _SubjectGridTile extends StatelessWidget {
  final SubjectCategory category;
  final int documentCount;
  final VoidCallback onTap;

  const _SubjectGridTile({
    required this.category,
    required this.documentCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Plain transparent tile — no glass panel, no backdrop blur. The
    // tinted folder icon carries the visual weight on its own, and the
    // pink/orange gradient shows through cleanly.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: SvgPicture.asset(
                    'assets/folder.svg',
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                    colorFilter: ColorFilter.mode(
                      GlassTheme.folderColor(
                        id: category.id,
                        name: category.name,
                      ),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: GlassTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$documentCount doc${documentCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: GlassTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glass bottom sheet shown when a grid tile is tapped.
class _CategoryActionsSheet extends StatelessWidget {
  final SubjectCategory category;
  final int documentCount;
  final VoidCallback onOpenStudyHub;
  final VoidCallback onQuery;
  final VoidCallback onDelete;

  const _CategoryActionsSheet({
    required this.category,
    required this.documentCount,
    required this.onOpenStudyHub,
    required this.onQuery,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: GlassTheme.panel(radius: 28, strong: true),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SvgPicture.asset(
                        'assets/folder.svg',
                        width: 48,
                        height: 48,
                        colorFilter: ColorFilter.mode(
                          GlassTheme.folderColor(
                            id: category.id,
                            name: category.name,
                          ),
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              style: const TextStyle(
                                color: GlassTheme.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$documentCount document${documentCount == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: GlassTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SheetAction(
                    icon: Icons.search_rounded,
                    label: 'Query ${category.name}',
                    accent: GlassTheme.accentBlue,
                    filled: true,
                    onTap: onQuery,
                  ),
                  const SizedBox(height: 10),
                  _SheetAction(
                    icon: Icons.hub_rounded,
                    label: 'Open Study Hub',
                    accent: GlassTheme.accentPurple,
                    onTap: onOpenStudyHub,
                  ),
                  const SizedBox(height: 10),
                  _SheetAction(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete subject',
                    accent: GlassTheme.danger,
                    onTap: onDelete,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final bool filled;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: filled
                ? LinearGradient(
                    colors: [
                      accent.withOpacity(0.35),
                      accent.withOpacity(0.18),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: filled ? null : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accent.withOpacity(filled ? 0.55 : 0.30),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: accent, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: GlassTheme.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(0.55),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController controller = MobileScannerController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Knowledge QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              Navigator.pop(context, barcode.rawValue);
              break;
            }
          }
        },
      ),
    );
  }
}
