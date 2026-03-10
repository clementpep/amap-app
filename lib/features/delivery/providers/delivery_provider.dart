import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/delivery_repository.dart';
import '../models/delivery.dart';

part 'delivery_provider.g.dart';

@riverpod
Future<List<Delivery>> deliveryList(Ref ref) {
  return ref.watch(deliveryRepositoryProvider).getDeliveries();
}

@riverpod
Future<Delivery?> deliveryDetail(Ref ref, String deliveryId) {
  return ref.watch(deliveryRepositoryProvider).getDelivery(deliveryId);
}
