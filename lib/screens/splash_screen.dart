import 'dart:io';
import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../services/auth_service.dart';
import '../services/config_service.dart';
import '../services/security_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'home_screen.dart';
import 'setup_screen.dart';
import 'welcome_screen.dart';
import 'pin_screen.dart';
import 'verify_email_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/database/app_database.dart';
import '../data/database/database_migration_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _iconController;
  late AnimationController _textController;
  late Animation<double> _iconScale;
  late Animation<double> _iconOpacity;
  late Animation<double> _iconRotate;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();

    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _iconRotate = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.25, 0.75, curve: Curves.easeIn),
      ),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _textController,
            curve: const Interval(0.25, 0.85, curve: Curves.easeOutCubic),
          ),
        );

    _iconController.forward();
    _textController.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (!mounted) return;
      _showNoInternetBottomSheet();
      return;
    }

    final bool configSuccess = await ConfigService.initConfig();

    if (ConfigService.isConnectionTimeout) {
      if (!mounted) return;
      _showNoInternetBottomSheet();
      return;
    }

    if (!configSuccess) {
      if (!mounted) return;
      _showNoInternetBottomSheet();
      return;
    }

    if (!kIsWeb) {
      await _requestPermissions();
      if (!mounted) return;
      await _initDatabaseAndMigrate();
      if (!mounted) return;
    }

    final results = await Future.wait([
      _authService.isLoggedIn(),
      kIsWeb ? Future.value(false) : SecurityService.isDeviceCompromised(),
      Future.delayed(Duration(seconds: kIsWeb ? 1 : 2)),
    ]);

    final bool isLoggedIn = results[0] as bool;
    final bool isCompromised = results[1] as bool;
    final prefs = await SharedPreferences.getInstance();
    final bool isSetupCompleted = prefs.getBool('is_setup_completed') ?? false;

    if (!mounted) return;

    if (isLoggedIn) {
      if (_authService.validationHadNetworkError) {
        if (!mounted) return;
        _showNoInternetBottomSheet();
        return;
      }

      if (!_authService.isEmailVerified) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
        );
        return;
      }

      if (isCompromised) {
        await _showSecurityNoticeBottomSheet();
        if (!mounted) return;
      }

      final bool isAppLockEnabled = prefs.getBool('app_lock_enabled') ?? false;

      if (isAppLockEnabled) {
        final pinTarget = isSetupCompleted ? const HomeScreen() : const SetupScreen();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PinScreen(target: pinTarget),
          ),
        );
      } else {
        if (isSetupCompleted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SetupScreen()),
          );
        }
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) return;
    if (Platform.isAndroid) {
      await [
        Permission.storage,
        Permission.photos,
        Permission.videos,
        Permission.audio,
        Permission.notification,
        Permission.manageExternalStorage,
      ].request();
    } else {
      await [Permission.photos, Permission.notification].request();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_requested', true);
  }

  Future<void> _initDatabaseAndMigrate() async {
    bool dbOk = false;
    try {
      await AppDatabase().database;
      dbOk = true;
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG: DB init error: $e');
    }
    if (!dbOk) {
      return;
    }

    final needsMigration = await DatabaseMigrationService.isMigrationNeeded();
    if (!needsMigration || !mounted) return;

    final confirmed = await _showMigrationNotice();
    if (!confirmed || !mounted) return;

    List<FailedItem>? retryItems;

    while (true) {
      if (kDebugMode) debugPrint('DEBUG: Starting migration...');
      if (!mounted) return;

      final report = await showDialog<MigrationReport?>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _MigrationProgressDialog(retryItems: retryItems),
      );
      if (!mounted || report == null) return;

      if (kDebugMode) {
        debugPrint('DEBUG: Migration done — chats: ${report.chatsMigrated}, '
            'messages: ${report.messagesMigrated}, '
            'summaries: ${report.summariesMigrated}, '
            'pins: ${report.pinnedMigrated}, '
            'errors: ${report.errors.length}, '
            'stoppedEarly: ${report.stoppedEarly}');
        for (final err in report.errors) {
          debugPrint('DEBUG: Migration error: $err');
        }
      }

      if (!report.stoppedEarly && !report.hasError) {
        await _showMigrationResult(report);
        break;
      }

      if (report.stoppedEarly) {
        retryItems = report.failedItems;
        continue;
      }

      final retryItemsResult = await _showMigrationResult(report);
      if (retryItemsResult != null) {
        retryItems = retryItemsResult;
        continue;
      }
      break;
    }
  }

  Future<bool> _showMigrationNotice() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Icon(Icons.storage_rounded, size: 64, color: colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                tr('migration_title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr('migration_desc'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  tr('migration_start'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(
                  tr('migration_later'),
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
    return result ?? false;
  }

  Future<List<FailedItem>?> _showMigrationResult(MigrationReport report) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final result = await showModalBottomSheet<List<FailedItem>?>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isSuccess = !report.hasError;
        final icon = isSuccess ? Icons.check_circle : Icons.warning_amber_rounded;
        final iconColor = isSuccess ? Colors.green : Colors.orange;
        final title = isSuccess
            ? tr('migration_result_title')
            : tr('migration_result_title_errors');

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 5,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Icon(icon, size: 64, color: iconColor),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              _resultRow(colorScheme, Icons.forum_outlined,
                  tr('migration_result_chats'), report.chatsMigrated.toString()),
              _resultRow(colorScheme, Icons.message_outlined,
                  tr('migration_result_messages'), report.messagesMigrated.toString()),
              _resultRow(colorScheme, Icons.article_outlined,
                  tr('migration_result_summaries'), report.summariesMigrated.toString()),
              _resultRow(colorScheme, Icons.push_pin_outlined,
                  tr('migration_result_pinned'), report.pinnedMigrated.toString()),
              if (report.hasError && report.errors.isNotEmpty) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text(
                      '${tr('migration_result_errors')} (${report.errors.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    children: report.errors.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        e,
                        style: TextStyle(
                          fontSize: 12, color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (!isSuccess && report.failedItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx, report.failedItems),
                      icon: const Icon(Icons.refresh),
                      label: Text(tr('migration_btn_retry_failed')),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    tr('migration_btn_ok'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
    return result;
  }

  Widget _resultRow(ColorScheme colorScheme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  void _showNoInternetBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/image/maintenance_image.png',
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                tr('no_internet_title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr('no_internet_desc'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => SystemNavigator.pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    tr('exit_app'),
                    style: TextStyle(
                      color: colorScheme.onError,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSecurityNoticeBottomSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/image/notice_image.png',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                tr('security_notice_title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.tertiary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr('security_notice_desc'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.tertiary,
                  foregroundColor: colorScheme.onTertiary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  tr('security_notice_btn'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? theme.scaffoldBackgroundColor
          : const Color(0xFF92C7FD),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _iconOpacity,
              child: ScaleTransition(
                scale: _iconScale,
                child: Transform.rotate(
                  angle: _iconRotate.value,
                  child: SvgPicture.asset(
                    'assets/icon/HaloStory.svg',
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            SlideTransition(
              position: _textSlide,
              child: FadeTransition(
                opacity: _textOpacity,
                child: Text(
                  'HaloStory',
                  style: GoogleFonts.nunito(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: isDark ? colorScheme.onSurface : Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingNoticeButton extends StatefulWidget {
  final Future<void> Function() onPressed;

  const _LoadingNoticeButton({required this.onPressed});

  @override
  State<_LoadingNoticeButton> createState() => _LoadingNoticeButtonState();
}

class _LoadingNoticeButtonState extends State<_LoadingNoticeButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ElevatedButton(
      onPressed: _isLoading
          ? null
          : () async {
              setState(() => _isLoading = true);
              await widget.onPressed();
              if (mounted) setState(() => _isLoading = false);
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.surfaceContainerHighest,
        foregroundColor: colorScheme.primary,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: _isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            )
          : Text(
              tr('system_notice_btn'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
    );
  }
}

class _MigrationProgressDialog extends StatefulWidget {
  final List<FailedItem>? retryItems;

  const _MigrationProgressDialog({this.retryItems});

  @override
  State<_MigrationProgressDialog> createState() => _MigrationProgressDialogState();
}

class _MigrationProgressDialogState extends State<_MigrationProgressDialog> {
  MigrationProgress? _progress;
  MigrationReport? _report;
  bool _isError = false;
  String? _errorMessage;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _startMigration();
    }
  }

  Future<void> _startMigration() async {
    final report = await DatabaseMigrationService.performMigration(
      onProgress: (p) {
        if (!mounted) return;
        setState(() {
          _progress = p;
          if (p.errorMessage != null) {
            _isError = true;
            _errorMessage = p.errorMessage;
          }
        });
      },
      retryItems: widget.retryItems,
    );
    if (!mounted) return;
    setState(() {
      _report = report;
      if (report.stoppedEarly && report.failedItems.isNotEmpty) {
        _isError = true;
        _errorMessage ??= report.failedItems.first.error;
      }
    });

    if (!report.stoppedEarly && !report.hasError) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.of(context).pop(report);
    }
  }

  double get _progressValue {
    if (_progress == null) return 0;
    if (_progress!.total == 0) return 0;
    return _progress!.current / _progress!.total;
  }

  String get _phaseText {
    switch (_progress?.phase) {
      case 'pinned': return tr('migration_progress_pinned');
      case 'chats':
        if (_progress!.total > 0) {
          return tr('migration_progress_chats')
              .replaceFirst('{current}', _progress!.current.toString())
              .replaceFirst('{total}', _progress!.total.toString());
        }
        return tr('migration_progress_chats');
      case 'summaries': return tr('migration_progress_summaries');
      case 'archive': return tr('migration_progress_archive');
      case 'finalize': return tr('migration_progress_finalize');
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: _isError && _report != null
            ? _buildErrorContent(colorScheme)
            : _buildProgressContent(colorScheme),
      ),
    );
  }

  Widget _buildProgressContent(ColorScheme colorScheme) {
    return SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Icon(Icons.storage_rounded, size: 48, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            tr('migration_progress_title'),
            style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progressValue > 0 ? _progressValue : null,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _phaseText,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            tr('migration_progress_wait'),
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildErrorContent(ColorScheme colorScheme) {
    return SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            tr('migration_progress_error_title'),
            style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _errorMessage ?? 'Unknown error',
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: Text(tr('btn_cancel')),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(_report),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(tr('migration_retry')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
