// // widgets/order_column.dart
// import 'package:flutter/material.dart';
// import '../models/order.dart';
// import '../widgets/order_card.dart';
// import '../config/app_theme.dart';
//
// class OrderColumn extends StatelessWidget {
//   final String title;
//   final List<Order> orders;
//   final Function(Order) onAction;
//   final String searchQuery;
//   final bool showTimer;
//   final bool isFinished;
//   final bool isReservation; // ✅ Flag untuk tampilan reservasi
//   final Function(Order, int)? onAddTime;
//
//   const OrderColumn({
//     super.key,
//     required this.title,
//     required this.orders,
//     required this.onAction,
//     required this.searchQuery,
//     this.showTimer = false,
//     this.isFinished = false,
//     this.isReservation = false, // ✅ Default false
//     this.onAddTime,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final filteredOrders = orders.where((order) {
//       final lowerQuery = searchQuery.toLowerCase();
//       return order.name.toLowerCase().contains(lowerQuery) ||
//           order.items.any(
//                 (item) => item.name.toLowerCase().contains(lowerQuery),
//           );
//     }).toList();
//
//     return Container( // ❌ Tidak dibungkus Expanded
//       margin: const EdgeInsets.all(8),
//       decoration: BoxDecoration(
//         color: isReservation
//             ? Colors.orange.shade50 // ✅ Background khusus reservasi
//             : Colors.grey[200],
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         children: [
//           // Header
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: isReservation
//                   ? Colors.orange // ✅ Warna header khusus reservasi
//                   : AppTheme.primaryColor,
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(12),
//                 topRight: Radius.circular(12),
//               ),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 12,
//                     vertical: 4,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.3),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Text(
//                     '${filteredOrders.length}',
//                     style: const TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           // Isi
//           Expanded(
//             child: filteredOrders.isEmpty
//                 ? Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(
//                     isReservation
//                         ? Icons.event_available // ✅ Icon khusus reservasi
//                         : Icons.inbox,
//                     size: 64,
//                     color: Colors.grey,
//                   ),
//                   const SizedBox(height: 12),
//                   Text(
//                     isReservation
//                         ? 'Tidak ada reservasi'
//                         : 'Tidak ada pesanan',
//                     style: TextStyle(color: Colors.grey[600]),
//                   ),
//                 ],
//               ),
//             )
//                 : ListView.builder(
//               padding: const EdgeInsets.all(8),
//               itemCount: filteredOrders.length,
//               itemBuilder: (context, index) {
//                 return OrderCard(
//                   order: filteredOrders[index],
//                   onAction: () => onAction(filteredOrders[index]),
//                   showTimer: showTimer,
//                   isFinished: isFinished,
//                   isReservation: isReservation, // ✅ Pass flag ke OrderCard
//                   onAddTime: onAddTime ?? (_, __) {},
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
