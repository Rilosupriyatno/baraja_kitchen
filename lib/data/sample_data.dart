// data/sample_data.dart
import '../models/order.dart';
import '../models/item.dart';

class SampleData {
  static List<Order> getSampleOrders() => [
    Order('Andi', 'C022', 'Dine-in', [
      Item('Flat White', 2),
      Item('Americano', 1),
    ]),
    Order('Andi', 'J003', 'Delivery', [
      Item('Coffee Late (iced)', 1),
      Item('Hellbraun', 1),
    ], start: DateTime.now().subtract(Duration(seconds: 35))),
    Order('Citra', 'A033', 'Dine-in', [
      Item('Flat White', 1),
      Item('Mocha', 1),
    ]),
  ];
}