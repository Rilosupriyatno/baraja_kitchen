import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DigitalClockWidget extends StatefulWidget {
  final Color color;
  final TextStyle? style;

  const DigitalClockWidget({
    super.key,
    required this.color,
    this.style,
  });

  @override
  State<DigitalClockWidget> createState() => _DigitalClockWidgetState();
}

class _DigitalClockWidgetState extends State<DigitalClockWidget> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, color: widget.color, size: 18),
          const SizedBox(width: 6),
          Text(
            DateFormat('HH:mm:ss').format(_currentTime),
            style: widget.style ?? TextStyle(
              color: widget.color,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
