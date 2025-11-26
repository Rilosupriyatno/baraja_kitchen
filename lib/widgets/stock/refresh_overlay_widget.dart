// widgets/stock/refresh_overlay_widget.dart
import 'package:flutter/material.dart';

class RefreshOverlayWidget extends StatelessWidget {
  final bool isRefreshing;
  final double loadingProgress;
  final String loadingMessage;
  final String workstation;
  final Color brandColor;

  const RefreshOverlayWidget({
    super.key,
    required this.isRefreshing,
    required this.loadingProgress,
    required this.loadingMessage,
    required this.workstation,
    required this.brandColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!isRefreshing) return const SizedBox.shrink();

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 250,
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: loadingProgress,
                          backgroundColor: Colors.grey.shade200,
                          color: workstation == 'bar'
                              ? Colors.blue[700]
                              : brandColor,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${(loadingProgress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: workstation == 'bar'
                                ? Colors.blue[700]
                                : brandColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loadingMessage,
                          style: TextStyle(
                            fontSize: 12,
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
        ),
      ),
    );
  }
}