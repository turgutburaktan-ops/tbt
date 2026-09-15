import '../models/photo_spot.dart';
import 'place_catalog_service.dart';

Future<List<PhotoSpot>> loadRouteStopCatalog(String city, int category) async {
  final records = await PlaceCatalogService.instance.city(
    city,
    catalogKinds[category],
  );
  return records.map((r) => r.spot).toList();
}
