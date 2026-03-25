import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';
import '../models/pdf_file.dart';
import '../models/bookmark.dart';
import '../models/reading_mode.dart';
import '../services/bookmark_service.dart';
import '../services/settings_service.dart';

class PdfViewerScreen extends StatefulWidget {
  final PdfFile file;
  const PdfViewerScreen({super.key, required this.file});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final PdfViewerController _pdfController;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showBars = true;
  ReadingMode _readingMode = ReadingMode.light;

  bool _isCurrentPageBookmarked = false;
  List<Bookmark> _bookmarks = [];

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    debugPrint('PdfViewer: Initializing with pdfrx for ${widget.file.path}');
    _init();
  }

  Future<void> _init() async {
    _readingMode = await SettingsService.getReadingMode();
    final lastPage = await SettingsService.getLastPage(widget.file.id);
    _currentPage = lastPage;
    
    await _loadBookmarks();
    if (mounted) setState(() {});
  }

  Future<void> _loadBookmarks() async {
    final bm = await BookmarkService.getBookmarks(widget.file.id);
    final isBookmarked = await BookmarkService.isBookmarked(widget.file.id, _currentPage);
    if (mounted) {
      setState(() {
        _bookmarks = bm;
        _isCurrentPageBookmarked = isBookmarked;
      });
    }
  }

  @override
  void dispose() {
    // PdfViewerController doesn't need explicit dispose in this version
    super.dispose();
  }

  // ──────────────── Reading Mode Styles ────────────────
  Color get _bgColor => _readingMode == ReadingMode.dark ? Colors.black : (_readingMode == ReadingMode.sepia ? const Color(0xFFF4E4C1) : Colors.white);
  Color get _barBg => _readingMode == ReadingMode.dark ? const Color(0xFF141414) : (_readingMode == ReadingMode.sepia ? const Color(0xFFEDD9A3) : Colors.white);
  Color get _textColor => _readingMode == ReadingMode.dark ? Colors.white : (_readingMode == ReadingMode.sepia ? const Color(0xFF4A3728) : Colors.black);
  Color get _borderColor => _readingMode == ReadingMode.dark ? const Color(0xFF333333) : (_readingMode == ReadingMode.sepia ? const Color(0xFFD4B483) : const Color(0xFFDDDDDD));

  // Color Filter for Reading Modes
  ColorFilter? get _readingFilter {
    if (_readingMode == ReadingMode.dark) {
      return const ColorFilter.matrix([
        -1.0, 0.0, 0.0, 0.0, 255.0,
        0.0, -1.0, 0.0, 0.0, 255.0,
        0.0, 0.0, -1.0, 0.0, 255.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]);
    }
    if (_readingMode == ReadingMode.sepia) {
      return const ColorFilter.matrix([
        0.393, 0.769, 0.189, 0, 0,
        0.349, 0.686, 0.168, 0, 0,
        0.272, 0.534, 0.131, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    }
    return null;
  }

  void _toggleBars() => setState(() => _showBars = !_showBars);

  void _onPageChanged(int? page) {
    if (page == null) return;
    setState(() {
      _currentPage = page - 1;
    });
    SettingsService.setLastPage(widget.file.id, _currentPage);
    _checkBookmark();
  }

  Future<void> _checkBookmark() async {
    final bookmarked = await BookmarkService.isBookmarked(widget.file.id, _currentPage);
    if (mounted) setState(() => _isCurrentPageBookmarked = bookmarked);
  }

  Future<void> _toggleBookmark() async {
    if (_isCurrentPageBookmarked) {
      await BookmarkService.removeBookmark(widget.file.id, _currentPage);
    } else {
      await BookmarkService.addBookmark(Bookmark(
        fileId: widget.file.id,
        page: _currentPage,
        title: 'Page ${_currentPage + 1}',
        createdAt: DateTime.now(),
      ));
    }
    _loadBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          GestureDetector(
            onTap: _toggleBars,
            child: ColorFiltered(
              colorFilter: _readingFilter ?? const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
              child: PdfViewer.file(
                widget.file.path,
                controller: _pdfController,
                params: PdfViewerParams(
                  backgroundColor: _bgColor,
                  onDocumentChanged: (document) {
                    debugPrint('PdfViewer: Document loaded. Pages: ${document?.pages.length}');
                    if (mounted) {
                      setState(() {
                        _totalPages = document?.pages.length ?? 0;
                        _isLoading = false;
                        _errorMessage = null;
                      });
                    }
                    if (_currentPage > 0) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _pdfController.goToPage(pageNumber: _currentPage + 1);
                      });
                    }
                  },
                  onPageChanged: _onPageChanged,
                ),
              ),
            ),
          ),
          
          if (_isLoading) Container(color: _bgColor, child: const Center(child: CircularProgressIndicator())),

          if (_errorMessage != null)
            Container(
              color: _bgColor,
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Could not load PDF',
                      style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: _textColor.withOpacity(0.7), fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _barBg,
                        foregroundColor: _textColor,
                        side: BorderSide(color: _borderColor),
                      ),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),

          // Top Header
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _showBars ? 0 : -100,
            left: 0, right: 0,
            child: _buildTopBar(),
          ),

          // Bottom Bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            bottom: _showBars ? 0 : -100,
            left: 0, right: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      decoration: BoxDecoration(
        color: _barBg.withOpacity(0.95),
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      padding: const EdgeInsets.only(top: 40, bottom: 8),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back_ios_new_rounded, color: _textColor, size: 20)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.file.name, style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('Page ${_currentPage + 1} of $_totalPages', style: TextStyle(color: _textColor.withOpacity(0.6), fontSize: 10)),
              ],
            ),
          ),
          IconButton(
            onPressed: _toggleBookmark, 
            icon: Icon(_isCurrentPageBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: _isCurrentPageBookmarked ? const Color(0xFF4A9EFF) : _textColor)
          ),
          IconButton(onPressed: _showMoreOptions, icon: Icon(Icons.more_vert_rounded, color: _textColor)),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: _barBg.withOpacity(0.95),
        border: Border(top: BorderSide(color: _borderColor)),
      ),
      padding: const EdgeInsets.only(bottom: 24, top: 8, left: 16, right: 16),
      child: Row(
        children: [
          IconButton(
            onPressed: _currentPage > 0 ? () => _pdfController.goToPage(pageNumber: _currentPage) : null, 
            icon: Icon(Icons.chevron_left_rounded, color: _textColor)
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(activeTrackColor: const Color(0xFF4A9EFF), thumbColor: const Color(0xFF4A9EFF)),
              child: Slider(
                value: _currentPage.toDouble().clamp(0, (_totalPages > 0 ? _totalPages - 1 : 0).toDouble()),
                min: 0,
                max: (_totalPages > 0 ? _totalPages - 1 : 0).toDouble(),
                onChanged: _totalPages > 0 ? (v) => _pdfController.goToPage(pageNumber: v.toInt() + 1) : null,
              ),
            ),
          ),
          IconButton(
            onPressed: _currentPage < _totalPages - 1 ? () => _pdfController.goToPage(pageNumber: _currentPage + 2) : null, 
            icon: Icon(Icons.chevron_right_rounded, color: _textColor)
          ),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _barBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: Icon(Icons.bookmark_added_rounded, color: _textColor), title: Text('My Bookmarks', style: TextStyle(color: _textColor)), onTap: () { Navigator.pop(ctx); _showBookmarksList(); }),
          ListTile(leading: Icon(Icons.brightness_medium_rounded, color: _textColor), title: Text('Reading Mode', style: TextStyle(color: _textColor)), onTap: () { Navigator.pop(ctx); _showReadingModeSelector(); }),
          ListTile(
            leading: Icon(Icons.share_rounded, color: _textColor), 
            title: Text('Share PDF', style: TextStyle(color: _textColor)), 
            onTap: () { 
              Navigator.pop(ctx); 
              if (Platform.isLinux) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sharing files is not supported on Linux.')),
                );
              } else {
                Share.shareXFiles([XFile(widget.file.path)]);
              }
            }
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showReadingModeSelector() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _barBg,
        title: Text('Reading Mode', style: TextStyle(color: _textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ReadingMode.values.map((m) => ListTile(
            title: Text(m.label, style: TextStyle(color: _textColor)),
            leading: Icon(Icons.circle, color: m == ReadingMode.dark ? Colors.black : (m == ReadingMode.sepia ? const Color(0xFFF4E4C1) : Colors.white)),
            onTap: () {
              setState(() => _readingMode = m);
              SettingsService.setReadingMode(m);
              Navigator.pop(ctx);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showBookmarksList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _barBg,
      builder: (ctx) => ListView.builder(
        itemCount: _bookmarks.length,
        itemBuilder: (context, index) => ListTile(
          title: Text(_bookmarks[index].title, style: TextStyle(color: _textColor)),
          onTap: () { Navigator.pop(ctx); _pdfController.goToPage(pageNumber: _bookmarks[index].page + 1); },
          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () async { await BookmarkService.removeBookmark(widget.file.id, _bookmarks[index].page); _loadBookmarks(); }),
        ),
      ),
    );
  }
}
