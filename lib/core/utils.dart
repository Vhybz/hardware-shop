enum WeightUnit { pcs, bag, bundle, length, bucket, litre, kg, metre, roll, pack, box, lb, g, unit }

extension WeightUnitExtension on WeightUnit {
  String get label {
    switch (this) {
      case WeightUnit.pcs:
      case WeightUnit.unit:
        return 'pcs';
      case WeightUnit.bag:
        return 'bag';
      case WeightUnit.bundle:
        return 'bundle';
      case WeightUnit.length:
        return 'length';
      case WeightUnit.bucket:
        return 'bucket';
      case WeightUnit.litre:
        return 'litre';
      case WeightUnit.kg:
        return 'kg';
      case WeightUnit.metre:
        return 'metre';
      case WeightUnit.roll:
        return 'roll';
      case WeightUnit.pack:
        return 'pack';
      case WeightUnit.box:
        return 'box';
      case WeightUnit.lb:
        return 'lb';
      case WeightUnit.g:
        return 'g';
    }
  }

  String get displayName {
    switch (this) {
      case WeightUnit.pcs:
      case WeightUnit.unit:
        return 'PCS';
      case WeightUnit.bag:
        return 'BAGS';
      case WeightUnit.bundle:
        return 'BUNDLES';
      case WeightUnit.length:
        return 'LENGTHS';
      case WeightUnit.bucket:
        return 'BUCKETS';
      case WeightUnit.litre:
        return 'LITRES';
      case WeightUnit.kg:
        return 'KG';
      case WeightUnit.metre:
        return 'METRES';
      case WeightUnit.roll:
        return 'ROLLS';
      case WeightUnit.pack:
        return 'PACKS';
      case WeightUnit.box:
        return 'BOXES';
      case WeightUnit.lb:
        return 'LB';
      case WeightUnit.g:
        return 'G';
    }
  }
}

class WeightConverter {
  static double toKg(double lbs) => lbs * 0.453592;
  static double toLbs(double kgs) => kgs * 2.20462;
  static double toLb(double kgs) => toLbs(kgs);
  static double fromG(double g) => g / 1000;
  static double toG(double kg) => kg * 1000;

  static double convert({
    required double value,
    required WeightUnit from,
    required WeightUnit to,
  }) {
    if (from == to) return value;
    
    // Normalize value
    double base;
    switch (from) {
      case WeightUnit.pcs:
      case WeightUnit.bag:
      case WeightUnit.bundle:
      case WeightUnit.length:
      case WeightUnit.bucket:
      case WeightUnit.litre:
      case WeightUnit.metre:
      case WeightUnit.roll:
      case WeightUnit.pack:
      case WeightUnit.unit:
      case WeightUnit.box:
      case WeightUnit.kg: base = value; break;
      case WeightUnit.lb: base = toKg(value); break;
      case WeightUnit.g: base = fromG(value); break;
    }

    // Convert to target
    switch (to) {
      case WeightUnit.pcs:
      case WeightUnit.bag:
      case WeightUnit.bundle:
      case WeightUnit.length:
      case WeightUnit.bucket:
      case WeightUnit.litre:
      case WeightUnit.metre:
      case WeightUnit.roll:
      case WeightUnit.pack:
      case WeightUnit.unit:
      case WeightUnit.box:
      case WeightUnit.kg: return base;
      case WeightUnit.lb: return toLbs(base);
      case WeightUnit.g: return toG(base);
    }
  }

  static String formatShort(double weight, {String? unit}) {
    final lowerUnit = unit?.toLowerCase();
    final isInt = weight == weight.roundToDouble();
    final qtyStr = isInt ? weight.toStringAsFixed(0) : weight.toStringAsFixed(1);

    if (lowerUnit == 'box' || lowerUnit == 'boxes' || lowerUnit == 'carton') {
      return '$qtyStr ${weight == 1 ? 'box' : 'boxes'}';
    }
    if (lowerUnit == 'lb' || lowerUnit == 'lbs') {
      final lbs = toLbs(weight);
      final isLbsInt = lbs == lbs.roundToDouble();
      return '${isLbsInt ? lbs.toStringAsFixed(0) : lbs.toStringAsFixed(1)} lb';
    }
    if (lowerUnit == 'g') {
      final grams = toG(weight);
      return '${grams.toStringAsFixed(0)}g';
    }
    if (lowerUnit == 'kg') {
      return '$qtyStr kg';
    }
    if (lowerUnit != null && lowerUnit.isNotEmpty && lowerUnit != 'unit' && lowerUnit != 'qty' && lowerUnit != 'pcs') {
      return '$qtyStr $unit';
    }
    return '$qtyStr pcs';
  }
}

class IdGenerator {
  static String generate({String prefix = 'ID'}) {
    final now = DateTime.now();
    final dateStr = '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final random = (100 + (now.microsecond % 900)).toString();
    return '$prefix-$dateStr-$timeStr-$random';
  }
}
