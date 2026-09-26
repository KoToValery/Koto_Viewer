import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/l10n_extensions.dart';

/// Service managing Google Play In-App Updates, background checks, and manual update requests.
///
/// Implements Google Play's recommended In-App Updates flow:
/// - Flexible Update: Downloads in background, prompts to restart when ready.
/// - Immediate Update: Blocking fullscreen dialog for critical updates (priority >= 4).
/// - Resume Flow: Completes downloaded updates on app start.
/// - Resilience: Handles debug mode, sideloaded installs, non-Android platforms, and offline states.
class AppUpdateService {
  AppUpdateService._();

  static const String _keyLastUpdateCheck = 'koto_last_update_check_time';
  static const String _playStorePackageName = 'com.koto.kotoviewer';
  static const String _playStoreWebUrl =
      'https://play.google.com/store/apps/details?id=$_playStorePackageName';
  static const String _playStoreMarketUrl =
      'market://details?id=$_playStorePackageName';

  /// How often to automatically check for updates in the background (24 hours).
  static const Duration autoCheckInterval = Duration(hours: 24);

  /// Notifier reflecting the current install status of a flexible update.
  static final ValueNotifier<InstallStatus?> installStatusNotifier =
      ValueNotifier<InstallStatus?>(null);

  /// Whether an update check is currently active.
  static final ValueNotifier<bool> isCheckingNotifier =
      ValueNotifier<bool>(false);

  /// Flag indicating an update is fully downloaded and ready for restart.
  static final ValueNotifier<bool> isUpdateDownloadedNotifier =
      ValueNotifier<bool>(false);

  static StreamSubscription<InstallStatus>? _installListenerSub;
  static bool _hasSubscribedToListener = false;

  /// Returns true if running on native Android where Google Play API is available.
  static bool get isPlayUpdateSupported => !kIsWeb && Platform.isAndroid;

  /// Initializes the update listener for flexible update progress.
  static void _ensureInstallListener(BuildContext? context, ScaffoldMessengerState? messenger) {
    if (!isPlayUpdateSupported || _hasSubscribedToListener) return;

    try {
      _hasSubscribedToListener = true;
      _installListenerSub = InAppUpdate.installUpdateListener.listen(
        (status) {
          installStatusNotifier.value = status;
          debugPrint('[AppUpdateService] Install status updated: $status');

          if (status == InstallStatus.downloaded) {
            isUpdateDownloadedNotifier.value = true;
            if (messenger != null && context != null && context.mounted) {
              showRestartSnackbar(context: context, messenger: messenger);
            }
          }
        },
        onError: (err) {
          debugPrint('[AppUpdateService] Install listener error: $err');
        },
      );
    } catch (e) {
      debugPrint('[AppUpdateService] Failed to bind installUpdateListener: $e');
    }
  }

  /// Automatic silent check called at application startup.
  ///
  /// Checks throttling (once per 24 hours), checks if an update was already
  /// downloaded in the background, or triggers a flexible update if available.
  static Future<void> checkForUpdateAtStartup({
    required BuildContext context,
    ScaffoldMessengerState? messenger,
  }) async {
    if (!isPlayUpdateSupported) return;

    _ensureInstallListener(context, messenger);

    try {
      // 1. First check if we previously downloaded an update that wasn't finalized.
      final info = await InAppUpdate.checkForUpdate();

      if (info.installStatus == InstallStatus.downloaded) {
        debugPrint('[AppUpdateService] Previously downloaded update found. Prompting restart.');
        isUpdateDownloadedNotifier.value = true;
        if (context.mounted && messenger != null) {
          showRestartSnackbar(context: context, messenger: messenger);
        }
        return;
      }

      // If an immediate update was triggered and paused, resume it.
      if (info.updateAvailability ==
              UpdateAvailability.developerTriggeredUpdateInProgress &&
          info.immediateUpdateAllowed) {
        debugPrint('[AppUpdateService] Resuming immediate update.');
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      // 2. Throttle check for new updates
      final prefs = await SharedPreferences.getInstance();
      final lastCheckMillis = prefs.getInt(_keyLastUpdateCheck) ?? 0;
      final lastCheckTime = DateTime.fromMillisecondsSinceEpoch(lastCheckMillis);

      if (DateTime.now().difference(lastCheckTime) < autoCheckInterval) {
        debugPrint('[AppUpdateService] Startup update check throttled (checked ${DateTime.now().difference(lastCheckTime).inHours}h ago).');
        return;
      }

      // Record this check time
      await prefs.setInt(_keyLastUpdateCheck, DateTime.now().millisecondsSinceEpoch);

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        debugPrint(
          '[AppUpdateService] Update available! Priority: ${info.updatePriority}, '
          'Flexible allowed: ${info.flexibleUpdateAllowed}, Immediate allowed: ${info.immediateUpdateAllowed}',
        );

        // Immediate update for critical priority (>= 4)
        if (info.updatePriority >= 4 && info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          // Flexible update starts background download after Play's native prompt
          final result = await InAppUpdate.startFlexibleUpdate();
          debugPrint('[AppUpdateService] Flexible update started with result: $result');
        } else if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        }
      } else {
        debugPrint('[AppUpdateService] No update available.');
      }
    } catch (e) {
      // In debug mode, local builds, or non-Play installs, Google Play API throws TASK_FAILURE.
      // We log silently without disrupting the user.
      debugPrint('[AppUpdateService] Startup update check completed with note: $e');
    }
  }

  /// Manual check initiated by the user (e.g. from the About dialog).
  ///
  /// Bypasses throttling and provides explicit feedback (snackbar or dialog).
  static Future<void> checkForUpdateManually({
    required BuildContext context,
    required ScaffoldMessengerState messenger,
  }) async {
    if (!context.mounted) return;

    if (!isPlayUpdateSupported) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.l10n.appUpToDate),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _ensureInstallListener(context, messenger);
    isCheckingNotifier.value = true;

    try {
      final info = await InAppUpdate.checkForUpdate();
      isCheckingNotifier.value = false;

      // 1. Update already downloaded
      if (info.installStatus == InstallStatus.downloaded) {
        isUpdateDownloadedNotifier.value = true;
        if (context.mounted) {
          showRestartSnackbar(context: context, messenger: messenger);
        }
        return;
      }

      // 2. Update is available
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.updatePriority >= 4 && info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          final result = await InAppUpdate.startFlexibleUpdate();
          debugPrint('[AppUpdateService] Manual flexible update result: $result');
        } else if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else {
          // Fallback to Google Play Store listing
          await openPlayStoreListing();
        }
        return;
      }

      // 3. No update available
      if (info.updateAvailability == UpdateAvailability.updateNotAvailable) {
        if (context.mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(context.l10n.appUpToDate),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    } catch (e) {
      isCheckingNotifier.value = false;
      debugPrint('[AppUpdateService] Manual check exception: $e');

      if (!context.mounted) return;

      // In debug mode or when running a local sideloaded APK, Google Play returns TASK_FAILURE.
      if (kDebugMode) {
        _showDebugTestingDialog(context);
      } else {
        // Production fallback: explain and offer to open Play Store
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.updateCheckFailed),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: context.l10n.openPlayStore,
              onPressed: () => openPlayStoreListing(),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Displays the restart SnackBar when a flexible update is downloaded.
  static void showRestartSnackbar({
    required BuildContext context,
    required ScaffoldMessengerState messenger,
  }) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.system_update_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.updateDownloadedSnackbar,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: context.l10n.restartToUpdate,
          textColor: Colors.amberAccent,
          onPressed: () async {
            await completeUpdate();
          },
        ),
        duration: const Duration(seconds: 25),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Completes a flexible update by restarting the app via Google Play Core.
  static Future<void> completeUpdate() async {
    if (!isPlayUpdateSupported) return;
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      debugPrint('[AppUpdateService] Failed to completeFlexibleUpdate: $e');
    }
  }

  /// Opens the app's listing directly on Google Play Store (market:// with web fallback).
  static Future<void> openPlayStoreListing() async {
    final marketUri = Uri.parse(_playStoreMarketUrl);
    final webUri = Uri.parse(_playStoreWebUrl);

    try {
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[AppUpdateService] Failed to launch Play Store URL: $e');
    }
  }

  /// Displays developer dialog in debug mode explaining local testing requirements
  /// and offering a simulation action to test the UI flow.
  static void _showDebugTestingDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.developer_mode_rounded, color: Colors.orange),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Google Play In-App Updates',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.debugTestingNote,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'За реално тестване:\n'
                  '1. Качете .aab в Google Play Console (Internal App Sharing или Internal Testing).\n'
                  '2. Инсталирайте приложението от тестовия линк на Play Store.\n'
                  '3. Качете по-нова версия (по-голям versionCode) в конзолата.\n'
                  '4. Отворете инсталираното приложение за тестване на диалозите.',
                  style: TextStyle(fontSize: 11.5, height: 1.4),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // Simulate update downloaded to verify SnackBar and UI
                simulateDownloadedUpdateForTesting(context);
              },
              child: Text(l10n.simulateUpdate),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                openPlayStoreListing();
              },
              child: Text(l10n.openPlayStore),
            ),
          ],
        );
      },
    );
  }

  /// Simulates a completed flexible update download for testing UI & restart SnackBar.
  static void simulateDownloadedUpdateForTesting(BuildContext context) {
    isUpdateDownloadedNotifier.value = true;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      showRestartSnackbar(context: context, messenger: messenger);
    }
  }

  /// Disposes background streams.
  static void dispose() {
    _installListenerSub?.cancel();
    _installListenerSub = null;
    _hasSubscribedToListener = false;
  }
}
