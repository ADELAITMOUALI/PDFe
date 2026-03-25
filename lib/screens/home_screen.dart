import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/pdf_file.dart';
import '../services/file_service.dart';
import '../services/settings_service.dart';
import 'pdf_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showAbout = false;
  List<PdfFile> _recentFiles = [];
  bool _isLoading = true;
  bool _isPickingFile = false;

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
  }

  Future<void> _loadRecentFiles() async {
    final files = await FileService.getRecentFiles();
    if (mounted) {
      setState(() {
        _recentFiles = files;
        _isLoading = false;
      });
    }
  }

  Future<void> _openFilePicker() async {
    if (_isPickingFile) return;
    setState(() => _isPickingFile = true);

    try {
      // Storage permissions handled more robustly for different versions
      if (Platform.isAndroid) {
        if (await Permission.storage.isDenied) {
          await Permission.storage.request();
        }
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final file = File(filePath);
        
        if (!await file.exists()) {
          throw Exception('Selected file does not exist at path: $filePath');
        }

        final stat = await file.stat();
        debugPrint('FilePicker: Selected $filePath (${stat.size} bytes)');

        final pdfFile = PdfFile(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: result.files.single.name,
          path: filePath,
          openedAt: DateTime.now(),
          sizeBytes: stat.size,
        );

        await FileService.addRecentFile(pdfFile);
        await _loadRecentFiles();

        if (mounted) {
          _openPdf(pdfFile);
        }
      } else {
        debugPrint('FilePicker: No file selected');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error opening file: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingFile = false);
      }
    }
  }

  void _openPdf(PdfFile file) {
    // Update the "opened at" timestamp
    final updated = PdfFile(
      id: file.id,
      name: file.name,
      path: file.path,
      openedAt: DateTime.now(),
      sizeBytes: file.sizeBytes,
    );
    
    // Check if file still exists before navigating
    if (!File(file.path).existsSync()) {
      _showSnackBar('File no longer exists: ${file.name}');
      FileService.removeRecentFile(file.id);
      _loadRecentFiles();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(file: updated),
      ),
    ).then((_) => _loadRecentFiles());
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1E1E1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF333333)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _showAbout ? _buildAboutSection() : _buildDashboard(),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF333333), width: 1),
        ),
        color: Color(0xFF141414),
      ),
      padding: const EdgeInsets.fromLTRB(16, 44, 16, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'P',
                style: TextStyle(
                  color: Color(0xFF141414),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PDFEngine',
                style: TextStyle(
                  color: Color(0xFFF2F2F2),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'v1.0',
                style: TextStyle(
                  color: Color(0xFF999999),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => setState(() => _showAbout = !_showAbout),
            icon: Icon(
              _showAbout ? Icons.home_rounded : Icons.settings_rounded,
              color: const Color(0xFFF2F2F2),
              size: 22,
            ),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFF333333)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFF2F2F2)),
      );
    }

    final totalSize = FileService.getTotalSize(_recentFiles);
    final totalSizeStr = FileService.formatTotalSize(totalSize);

    return RefreshIndicator(
      color: const Color(0xFFF2F2F2),
      backgroundColor: const Color(0xFF1E1E1E),
      onRefresh: _loadRecentFiles,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to PDFEngine',
              style: TextStyle(
                color: Color(0xFFF2F2F2),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Blazing-fast PDF rendering. Zero bloat. Full fidelity.',
              style: TextStyle(
                color: Color(0xFF999999),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),

            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '${_recentFiles.length}',
                    'Recent Files',
                    Icons.history_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    totalSizeStr,
                    'Total Size',
                    Icons.sd_storage_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Recently Viewed Header
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  color: Color(0xFFF2F2F2),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Recently Viewed',
                  style: TextStyle(
                    color: Color(0xFFF2F2F2),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                if (_recentFiles.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      final confirmed = await _confirmClear();
                      if (confirmed == true) {
                        await FileService.clearRecentFiles();
                        _loadRecentFiles();
                      }
                    },
                    child: const Text('Clear all',
                        style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (_recentFiles.isEmpty)
              _buildEmptyState()
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentFiles.length,
                itemBuilder: (context, index) =>
                    _buildRecentFileItem(_recentFiles[index]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF999999), size: 16),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFF2F2F2),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF999999),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                color: Color(0xFF999999),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No recent PDF files',
              style: TextStyle(
                color: Color(0xFFF2F2F2),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Files you open will appear here for\nquick access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF999999),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentFileItem(PdfFile pdf) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openPdf(pdf),
        onLongPress: () => _showFileOptions(pdf),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFFF2F2F2),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pdf.name,
                      style: const TextStyle(
                        color: Color(0xFFF2F2F2),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pdf.formattedSize} • ${pdf.timeAgo}',
                      style: const TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showFileOptions(pdf),
                icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF999999), size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFileOptions(PdfFile pdf) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFF333333), borderRadius: BorderRadius.circular(2)),
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new_rounded, color: Color(0xFFF2F2F2)),
            title: const Text('Open File', style: TextStyle(color: Color(0xFFF2F2F2))),
            onTap: () {
              Navigator.pop(ctx);
              _openPdf(pdf);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
            title: const Text('Remove from Recent', style: TextStyle(color: Color(0xFFEF4444))),
            onTap: () async {
              Navigator.pop(ctx);
              await FileService.removeRecentFile(pdf.id);
              _loadRecentFiles();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<bool?> _confirmClear() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Clear History?', style: TextStyle(color: Color(0xFFF2F2F2))),
        content: const Text('This will remove all files from your recent list.', style: TextStyle(color: Color(0xFF999999))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF333333)),
            ),
            child: const Text('P', style: TextStyle(color: Color(0xFFF2F2F2), fontSize: 40, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 24),
          const Text('PDFEngine', style: TextStyle(color: Color(0xFFF2F2F2), fontSize: 28, fontWeight: FontWeight.bold)),
          const Text('Version 1.0.0', style: TextStyle(color: Color(0xFF999999), fontSize: 14)),
          const SizedBox(height: 40),
          _aboutTile('Developer', 'Adel Mouali'),
          _aboutTile('License', 'MIT Open Source'),
          _aboutTile('Source', 'github.com/ADELAITMOUALI'),
          const SizedBox(height: 40),
          const Text(
            'Built with Flutter. Blazing-fast PDF rendering engine with zero bloat.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF999999), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _aboutTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF999999), fontSize: 14)),
          Text(value, style: const TextStyle(color: Color(0xFFF2F2F2), fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        border: Border(top: BorderSide(color: Color(0xFF333333))),
      ),
      child: ElevatedButton.icon(
        onPressed: _isPickingFile ? null : _openFilePicker,
        icon: _isPickingFile 
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
            : const Icon(Icons.add_rounded),
        label: Text(_isPickingFile ? 'Picking...' : 'Open New PDF'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF2F2F2),
          foregroundColor: const Color(0xFF141414),
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
