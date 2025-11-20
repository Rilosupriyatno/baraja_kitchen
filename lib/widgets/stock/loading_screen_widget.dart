// widgets/stock/loading_screen_widget.dart
import 'package:flutter/material.dart';

class LoadingScreenWidget extends StatelessWidget {
  final String workstation;
  final bool isLoadingFromCache;
  final double loadingProgress;
  final String loadingMessage;
  final Color brandColor;

  const LoadingScreenWidget({
    super.key,
    required this.workstation,
    required this.isLoadingFromCache,
    required this.loadingProgress,
    required this.loadingMessage,
    required this.brandColor,
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
                isLoadingFromCache ? Icons.cached : Icons.inventory_2_outlined,
                size: 80,
                color: workstation == 'bar'
                    ? Colors.blue[700]
                    : brandColor.withOpacity(0.5),
              ),
              const SizedBox(height: 32),
              Text(
                isLoadingFromCache ? 'Memuat dari Cache' : 'Memuat Data Stok',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: workstation == 'bar' ? Colors.blue[700] : brandColor,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 300,
                child: Column(
                  children: [
                    if (!isLoadingFromCache) ...[
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
                    if (isLoadingFromCache) const CircularProgressIndicator(),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}