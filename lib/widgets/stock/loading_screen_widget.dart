// widgets/stock/loading_screen_widget.dart
import 'package:flutter/material.dart';

class LoadingScreenWidget extends StatelessWidget {
  final String workstation;
  final bool isLoadingFromCache;
  final double loadingProgress;
  final String loadingMessage;
  final Color brandColor;
  final bool canContinue;
  final VoidCallback? onContinue;
  final VoidCallback? onCancel;

  const LoadingScreenWidget({
    super.key,
    required this.workstation,
    required this.isLoadingFromCache,
    required this.loadingProgress,
    required this.loadingMessage,
    required this.brandColor,
    this.canContinue = false,
    this.onContinue,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isLoadingFromCache
                    ? Icons.cached
                    : canContinue
                    ? Icons.sync_problem
                    : Icons.inventory_2_outlined,
                size: 80,
                color: canContinue
                    ? Colors.orange
                    : workstation == 'bar'
                    ? Colors.blue[700]
                    : brandColor.withOpacity(0.5),
              ),
              const SizedBox(height: 32),
              Text(
                isLoadingFromCache
                    ? 'Memuat dari Cache'
                    : canContinue
                    ? 'Download Terputus'
                    : 'Memuat Data Stok',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: canContinue
                      ? Colors.orange
                      : workstation == 'bar'
                      ? Colors.blue[700]
                      : brandColor,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 300,
                child: Column(
                  children: [
                    if (!isLoadingFromCache && !canContinue) ...[
                      LinearProgressIndicator(
                        value: loadingProgress,
                        backgroundColor: Colors.grey.shade200,
                        color: workstation == 'bar' ? Colors.blue[700] : brandColor,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${(loadingProgress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: workstation == 'bar' ? Colors.blue[700] : brandColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (isLoadingFromCache && !canContinue)
                      const CircularProgressIndicator(),
                    if (canContinue) ...[
                      Icon(
                        Icons.warning_rounded,
                        size: 48,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Koneksi terputus saat mengunduh data',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Progress: ${(loadingProgress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: onCancel,
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Gunakan Data'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: onContinue,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Lanjutkan'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (!canContinue) ...[
                      const SizedBox(height: 8),
                      Text(
                        loadingMessage,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}