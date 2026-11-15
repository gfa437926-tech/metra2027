import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/catalog/observation_field_catalogs.dart';
import 'package:metra_mobile/core/widgets/metra_observation_form.dart';

void main() {
  test('hourly catalog uses only approved field ids and proven temp bounds', () {
    final ids = ObservationFieldCatalogs.hourly.map((f) => f.id).toSet();
    expect(ids.contains('dryTemp'), isTrue);
    expect(ids.contains('wetTemp'), isTrue);
    expect(ids.contains('inventedField'), isFalse);

    final dry =
        ObservationFieldCatalogs.hourly.firstWhere((f) => f.id == 'dryTemp');
    expect(dry.minimum, -20);
    expect(dry.maximum, 50);
    expect(dry.required, isTrue);
    expect(dry.kind, MetraFieldKind.decimal);
  });

  test('daily catalog enforces proven precipitation bounds', () {
    final precip = ObservationFieldCatalogs.daily
        .firstWhere((f) => f.id == 'precipitation');
    expect(precip.minimum, 0);
    expect(precip.maximum, 999.9);
    expect(precip.required, isTrue);
  });

  test('catalogs do not invent humidity bounds outside proven sources', () {
    final hourlyRh = ObservationFieldCatalogs.hourly
        .firstWhere((f) => f.id == 'relativeHumidity');
    expect(hourlyRh.minimum, 1);
    expect(hourlyRh.maximum, 100);
  });
}
