import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/uuid_utils.dart';
import '../core/supabase_config.dart';
import '../models/product.dart';
import 'product_service.dart';
import 'user_provider.dart';
import 'sale_provider.dart';
import 'offline_sync_service.dart';

class DefaultProductItem {
  final String name;
  final String category;
  final String unit;
  final String sku;
  final double lowStockThreshold;

  const DefaultProductItem({
    required this.name,
    required this.category,
    required this.unit,
    required this.sku,
    this.lowStockThreshold = 10.0,
  });
}

class ProductSeeder {
  final Ref ref;
  ProductSeeder(this.ref);

  /// Resets all product stock quantities (Store & Warehouse) to 0.0 Pcs
  Future<void> resetAllStockToZero() async {
    final user = ref.read(currentUserProvider);
    if (user == null || user.branchCode == null) return;

    await SupabaseConfig.client
        .from('products')
        .update({
          'stock_quantity': 0.0,
          'warehouse_quantity': 0.0,
          'daily_stock_added': 0.0,
        })
        .eq('branch_code', user.branchCode!);

    ref.invalidate(productsFutureProvider);
  }

  /// Default Zero-Price Product Catalog for Hardware & Building Materials
  static const List<DefaultProductItem> defaultCatalog = [
    // 1. BUILDING MATERIALS
    DefaultProductItem(name: 'GHACEM CEMENT 42.5N (BAG)', category: 'BUILDING MATERIALS', unit: 'Bag', sku: 'BM-CEM-01'),
    DefaultProductItem(name: 'DANGOTE CEMENT 42.5R (BAG)', category: 'BUILDING MATERIALS', unit: 'Bag', sku: 'BM-CEM-02'),
    DefaultProductItem(name: 'CIMAF CEMENT 42.5N (BAG)', category: 'BUILDING MATERIALS', unit: 'Bag', sku: 'BM-CEM-03'),
    DefaultProductItem(name: 'SUPERSET CEMENT 32.5R (BAG)', category: 'BUILDING MATERIALS', unit: 'Bag', sku: 'BM-CEM-04'),
    DefaultProductItem(name: 'WHITE CEMENT 25KG (BAG)', category: 'BUILDING MATERIALS', unit: 'Bag', sku: 'BM-CEM-05'),
    DefaultProductItem(name: 'TILE ADHESIVE (20KG BAG)', category: 'BUILDING MATERIALS', unit: 'Bag', sku: 'BM-TIL-01'),
    DefaultProductItem(name: 'TILE GROUT WHITE (5KG BAG)', category: 'BUILDING MATERIALS', unit: 'Bag', sku: 'BM-TIL-02'),
    DefaultProductItem(name: 'TILE GROUT GREY (5KG BAG)', category: 'BUILDING MATERIALS', unit: 'Bag', sku: 'BM-TIL-03'),
    DefaultProductItem(name: 'HYDRATED LIME (25KG BAG)', category: 'BUILDING MATERIALS', unit: 'Bag', sku: 'BM-LIM-01'),
    DefaultProductItem(name: 'SAND - SHARP SAND (TRUCK LOAD)', category: 'BUILDING MATERIALS', unit: 'Truck', sku: 'BM-SND-01'),
    DefaultProductItem(name: 'SAND - SOFT PLASTERING SAND (TRUCK LOAD)', category: 'BUILDING MATERIALS', unit: 'Truck', sku: 'BM-SND-02'),
    DefaultProductItem(name: 'STONES - QUARRY DUST (TRUCK LOAD)', category: 'BUILDING MATERIALS', unit: 'Truck', sku: 'BM-STN-01'),
    DefaultProductItem(name: 'STONES - 3/4 INCH GRANITE (TRUCK LOAD)', category: 'BUILDING MATERIALS', unit: 'Truck', sku: 'BM-STN-02'),
    DefaultProductItem(name: 'CONCRETE BLOCKS 5 INCH (SOLID)', category: 'BUILDING MATERIALS', unit: 'Pcs', sku: 'BM-BLK-01'),
    DefaultProductItem(name: 'CONCRETE BLOCKS 6 INCH (HOLLOW)', category: 'BUILDING MATERIALS', unit: 'Pcs', sku: 'BM-BLK-02'),
    DefaultProductItem(name: 'CONCRETE BLOCKS 9 INCH (HOLLOW)', category: 'BUILDING MATERIALS', unit: 'Pcs', sku: 'BM-BLK-03'),
    DefaultProductItem(name: 'WATERPROOFING ADMIXTURE (5L)', category: 'BUILDING MATERIALS', unit: 'Bucket', sku: 'BM-ADM-01'),

    // 2. STEEL & REBAR
    DefaultProductItem(name: 'HIGH YIELD IRON RODS 8MM (LENGTH)', category: 'STEEL & REBAR', unit: 'Length', sku: 'ST-ROD-08'),
    DefaultProductItem(name: 'HIGH YIELD IRON RODS 10MM (LENGTH)', category: 'STEEL & REBAR', unit: 'Length', sku: 'ST-ROD-10'),
    DefaultProductItem(name: 'HIGH YIELD IRON RODS 12MM (LENGTH)', category: 'STEEL & REBAR', unit: 'Length', sku: 'ST-ROD-12'),
    DefaultProductItem(name: 'HIGH YIELD IRON RODS 16MM (LENGTH)', category: 'STEEL & REBAR', unit: 'Length', sku: 'ST-ROD-16'),
    DefaultProductItem(name: 'HIGH YIELD IRON RODS 20MM (LENGTH)', category: 'STEEL & REBAR', unit: 'Length', sku: 'ST-ROD-20'),
    DefaultProductItem(name: 'BINDING WIRE (ROLL 25KG)', category: 'STEEL & REBAR', unit: 'Roll', sku: 'ST-WIR-01'),
    DefaultProductItem(name: 'BRC MESH GAUGE 6 (ROLL)', category: 'STEEL & REBAR', unit: 'Roll', sku: 'ST-MSH-01'),
    DefaultProductItem(name: 'ANGLE BARS 2" x 2" x 1/4" (LENGTH)', category: 'STEEL & REBAR', unit: 'Length', sku: 'ST-BAR-01'),
    DefaultProductItem(name: 'FLAT BARS 2" x 1/4" (LENGTH)', category: 'STEEL & REBAR', unit: 'Length', sku: 'ST-BAR-02'),
    DefaultProductItem(name: 'STEEL HOLLOW PIPES 2" (LENGTH)', category: 'STEEL & REBAR', unit: 'Length', sku: 'ST-PIP-01'),

    // 3. PLUMBING & PVC
    DefaultProductItem(name: 'PVC PRESSURE PIPE 1/2" (LENGTH)', category: 'PLUMBING & PVC', unit: 'Length', sku: 'PL-PIP-01'),
    DefaultProductItem(name: 'PVC PRESSURE PIPE 3/4" (LENGTH)', category: 'PLUMBING & PVC', unit: 'Length', sku: 'PL-PIP-02'),
    DefaultProductItem(name: 'PVC PRESSURE PIPE 1" (LENGTH)', category: 'PLUMBING & PVC', unit: 'Length', sku: 'PL-PIP-03'),
    DefaultProductItem(name: 'PVC WASTE PIPE 1.5" (LENGTH)', category: 'PLUMBING & PVC', unit: 'Length', sku: 'PL-PIP-04'),
    DefaultProductItem(name: 'PVC SOIL PIPE 4" (LENGTH)', category: 'PLUMBING & PVC', unit: 'Length', sku: 'PL-PIP-05'),
    DefaultProductItem(name: 'PVC ELBOW FITTING 1/2"', category: 'PLUMBING & PVC', unit: 'Pcs', sku: 'PL-FIT-01'),
    DefaultProductItem(name: 'PVC TEE FITTING 1/2"', category: 'PLUMBING & PVC', unit: 'Pcs', sku: 'PL-FIT-02'),
    DefaultProductItem(name: 'PVC SOCKET FITTING 1/2"', category: 'PLUMBING & PVC', unit: 'Pcs', sku: 'PL-FIT-03'),
    DefaultProductItem(name: 'PVC CEMENT SOLVENT (500ML)', category: 'PLUMBING & PVC', unit: 'Pcs', sku: 'PL-SLV-01'),
    DefaultProductItem(name: 'BRASS GATE VALVE 1/2"', category: 'PLUMBING & PVC', unit: 'Pcs', sku: 'PL-VLV-01'),
    DefaultProductItem(name: 'BRASS BALL TAP 1/2"', category: 'PLUMBING & PVC', unit: 'Pcs', sku: 'PL-TAP-01'),
    DefaultProductItem(name: 'FLEXIBLE CONNECTOR HOSE 1/2"', category: 'PLUMBING & PVC', unit: 'Pcs', sku: 'PL-HOS-01'),
    DefaultProductItem(name: 'SINK WASTE STRAINER S/STEEL', category: 'PLUMBING & PVC', unit: 'Pcs', sku: 'PL-SNK-01'),
    DefaultProductItem(name: 'POLY TANK 1000 LITRES (WATER TANK)', category: 'PLUMBING & PVC', unit: 'Pcs', sku: 'PL-TNK-01'),
    DefaultProductItem(name: 'POLY TANK 2000 LITRES (WATER TANK)', category: 'PLUMBING & PVC', unit: 'Pcs', sku: 'PL-TNK-02'),

    // 4. ELECTRICALS
    DefaultProductItem(name: 'ELECTRICAL CABLE 1.5MM SINGLE CORE (100M ROLL)', category: 'ELECTRICALS', unit: 'Roll', sku: 'EL-CBL-01'),
    DefaultProductItem(name: 'ELECTRICAL CABLE 2.5MM SINGLE CORE (100M ROLL)', category: 'ELECTRICALS', unit: 'Roll', sku: 'EL-CBL-02'),
    DefaultProductItem(name: 'ELECTRICAL CABLE 4.0MM TWIN & EARTH (100M ROLL)', category: 'ELECTRICALS', unit: 'Roll', sku: 'EL-CBL-03'),
    DefaultProductItem(name: 'FLEXIBLE CABLE 3 CORE 1.5MM (100M ROLL)', category: 'ELECTRICALS', unit: 'Roll', sku: 'EL-CBL-04'),
    DefaultProductItem(name: 'PVC CONDUIT PIPE 20MM (LENGTH)', category: 'ELECTRICALS', unit: 'Length', sku: 'EL-CND-01'),
    DefaultProductItem(name: 'CONDUIT BEND 20MM', category: 'ELECTRICALS', unit: 'Pcs', sku: 'EL-CND-02'),
    DefaultProductItem(name: '1-GANG 1-WAY SWITCH', category: 'ELECTRICALS', unit: 'Pcs', sku: 'EL-SWT-01'),
    DefaultProductItem(name: '2-GANG 1-WAY SWITCH', category: 'ELECTRICALS', unit: 'Pcs', sku: 'EL-SWT-02'),
    DefaultProductItem(name: '13A SINGLE SWITCH SOCKET', category: 'ELECTRICALS', unit: 'Pcs', sku: 'EL-SOC-01'),
    DefaultProductItem(name: '13A TWIN SWITCH SOCKET', category: 'ELECTRICALS', unit: 'Pcs', sku: 'EL-SOC-02'),
    DefaultProductItem(name: 'MCB CIRCUIT BREAKER 16A SINGLE POLE', category: 'ELECTRICALS', unit: 'Pcs', sku: 'EL-MCB-01'),
    DefaultProductItem(name: 'MCB CIRCUIT BREAKER 32A SINGLE POLE', category: 'ELECTRICALS', unit: 'Pcs', sku: 'EL-MCB-02'),
    DefaultProductItem(name: 'DISTRIBUTION BOARD 8-WAY', category: 'ELECTRICALS', unit: 'Pcs', sku: 'EL-DB-01'),
    DefaultProductItem(name: 'LED BULB 9W E27 DAYLIGHT', category: 'ELECTRICALS', unit: 'Pcs', sku: 'EL-LED-01'),
    DefaultProductItem(name: 'LED BULB 12W E27 DAYLIGHT', category: 'ELECTRICALS', unit: 'Pcs', sku: 'EL-LED-02'),
    DefaultProductItem(name: 'LED TUBE LIGHT 4FT 18W', category: 'ELECTRICALS', unit: 'Pcs', sku: 'EL-LED-03'),

    // 5. PAINTS & FINISHES
    DefaultProductItem(name: 'CORAL EMULSION PAINT WHITE (20L BUCKET)', category: 'PAINTS & FINISHES', unit: 'Bucket', sku: 'PT-EML-01'),
    DefaultProductItem(name: 'CORAL OIL PAINT GLOSS WHITE (4L)', category: 'PAINTS & FINISHES', unit: 'Pcs', sku: 'PT-GLS-01'),
    DefaultProductItem(name: 'AZAR EMULSION PAINT OFF-WHITE (20L BUCKET)', category: 'PAINTS & FINISHES', unit: 'Bucket', sku: 'PT-EML-02'),
    DefaultProductItem(name: 'AZAR GLOSS OIL PAINT (4L)', category: 'PAINTS & FINISHES', unit: 'Pcs', sku: 'PT-GLS-02'),
    DefaultProductItem(name: 'UNDERCOAT PRIMER SEALER (20L BUCKET)', category: 'PAINTS & FINISHES', unit: 'Bucket', sku: 'PT-PRM-01'),
    DefaultProductItem(name: 'PAINT THINNER (5 LITRES)', category: 'PAINTS & FINISHES', unit: 'Pcs', sku: 'PT-THN-01'),
    DefaultProductItem(name: 'PAINT ROLLER WITH TRAY 9 INCH', category: 'PAINTS & FINISHES', unit: 'Pcs', sku: 'PT-ROL-01'),
    DefaultProductItem(name: 'PAINT ROLLER REFILL SLEEVE 9 INCH', category: 'PAINTS & FINISHES', unit: 'Pcs', sku: 'PT-ROL-02'),
    DefaultProductItem(name: 'FOAM MINI PAINT ROLLER 4 INCH', category: 'PAINTS & FINISHES', unit: 'Pcs', sku: 'PT-ROL-03'),
    DefaultProductItem(name: 'PAINT BRUSH 2 INCH', category: 'PAINTS & FINISHES', unit: 'Pcs', sku: 'PT-BRS-01'),
    DefaultProductItem(name: 'PAINT BRUSH 4 INCH', category: 'PAINTS & FINISHES', unit: 'Pcs', sku: 'PT-BRS-02'),
    DefaultProductItem(name: 'SANDPAPER P100 (SHEET)', category: 'PAINTS & FINISHES', unit: 'Sheet', sku: 'PT-SND-01'),
    DefaultProductItem(name: 'SANDPAPER P80 (SHEET)', category: 'PAINTS & FINISHES', unit: 'Sheet', sku: 'PT-SND-02'),

    // 6. ROOFING & TIMBER
    DefaultProductItem(name: 'ALUZINC ROOFING SHEET 0.40MM (SHEET)', category: 'ROOFING & TIMBER', unit: 'Sheet', sku: 'RF-SHT-01'),
    DefaultProductItem(name: 'ALUMINIUM SELF-TAPPING ROOFING SCREWS (PACK)', category: 'ROOFING & TIMBER', unit: 'Pack', sku: 'RF-SCR-01'),
    DefaultProductItem(name: 'ROOFING NAILS 3 INCH (KG)', category: 'ROOFING & TIMBER', unit: 'Kg', sku: 'RF-NAL-01'),
    DefaultProductItem(name: 'TIMBER BATTENS 2" x 2" (LENGTH)', category: 'ROOFING & TIMBER', unit: 'Length', sku: 'RF-TMB-01'),
    DefaultProductItem(name: 'TIMBER BATTENS 2" x 3" (LENGTH)', category: 'ROOFING & TIMBER', unit: 'Length', sku: 'RF-TMB-02'),
    DefaultProductItem(name: 'TIMBER BOARDS 2" x 4" (LENGTH)', category: 'ROOFING & TIMBER', unit: 'Length', sku: 'RF-TMB-03'),
    DefaultProductItem(name: 'PLYWOOD 1/2 INCH (4FT x 8FT SHEET)', category: 'ROOFING & TIMBER', unit: 'Sheet', sku: 'RF-PLY-01'),
    DefaultProductItem(name: 'PLYWOOD 3/4 INCH (4FT x 8FT SHEET)', category: 'ROOFING & TIMBER', unit: 'Sheet', sku: 'RF-PLY-02'),
    DefaultProductItem(name: 'ROOFING FELT WATERPROOF (ROLL)', category: 'ROOFING & TIMBER', unit: 'Roll', sku: 'RF-FLT-01'),
    DefaultProductItem(name: 'ALUZINC RIDGE CAPS (PIECE)', category: 'ROOFING & TIMBER', unit: 'Pcs', sku: 'RF-CAP-01'),

    // 7. TOOLS & FASTENERS
    DefaultProductItem(name: 'CLAW HAMMER 16OZ WITH RUBBER GRIP', category: 'TOOLS & FASTENERS', unit: 'Pcs', sku: 'TL-HMR-01'),
    DefaultProductItem(name: 'CLUB / LUMP HAMMER 3LB', category: 'TOOLS & FASTENERS', unit: 'Pcs', sku: 'TL-HMR-02'),
    DefaultProductItem(name: 'RUBBER MALLET HAMMER 16OZ', category: 'TOOLS & FASTENERS', unit: 'Pcs', sku: 'TL-HMR-03'),
    DefaultProductItem(name: 'BRICKLAYING TROWEL 8 INCH', category: 'TOOLS & FASTENERS', unit: 'Pcs', sku: 'TL-TRW-01'),
    DefaultProductItem(name: 'STEEL TAPE MEASURE 8M / 26FT', category: 'TOOLS & FASTENERS', unit: 'Pcs', sku: 'TL-TAP-01'),
    DefaultProductItem(name: 'NYLON MASONRY / BUILDING LINE ROPE (100M ROLL)', category: 'TOOLS & FASTENERS', unit: 'Roll', sku: 'TL-ROP-01'),
    DefaultProductItem(name: 'POLYPROPYLENE HEAVY DUTY ROPE 10MM (COIL 50M)', category: 'TOOLS & FASTENERS', unit: 'Roll', sku: 'TL-ROP-02'),
    DefaultProductItem(name: 'MASONRY NAILS 3 INCH (1KG PACK)', category: 'TOOLS & FASTENERS', unit: 'Pack', sku: 'TL-NAL-01'),
    DefaultProductItem(name: 'WOOD NAILS 4 INCH (25KG BOX)', category: 'TOOLS & FASTENERS', unit: 'Box', sku: 'TL-NAL-02'),
    DefaultProductItem(name: 'WOOD NAILS 3 INCH (25KG BOX)', category: 'TOOLS & FASTENERS', unit: 'Box', sku: 'TL-NAL-03'),
    DefaultProductItem(name: 'DRYWALL SCREWS 1.5 INCH (BOX)', category: 'TOOLS & FASTENERS', unit: 'Box', sku: 'TL-SCR-01'),
    DefaultProductItem(name: 'WOOD SCREWS 2 INCH (100 PCS BOX)', category: 'TOOLS & FASTENERS', unit: 'Box', sku: 'TL-SCR-02'),
    DefaultProductItem(name: 'SELF-TAPPING SCREWS ASSORTED (BOX)', category: 'TOOLS & FASTENERS', unit: 'Box', sku: 'TL-SCR-03'),
    DefaultProductItem(name: 'CONCRETE MASONRY SCREWS WITH ANCHORS (BOX)', category: 'TOOLS & FASTENERS', unit: 'Box', sku: 'TL-SCR-04'),
    DefaultProductItem(name: 'BOLTS & NUTS 1/2" x 3" (PIECE)', category: 'TOOLS & FASTENERS', unit: 'Pcs', sku: 'TL-BLT-01'),
    DefaultProductItem(name: 'MASONRY DRILL BIT 8MM', category: 'TOOLS & FASTENERS', unit: 'Pcs', sku: 'TL-BIT-01'),
    DefaultProductItem(name: 'SAFETY HELMET (HARD HAT) YELLOW', category: 'TOOLS & FASTENERS', unit: 'Pcs', sku: 'TL-SAF-01'),
    DefaultProductItem(name: 'SAFETY BOOTS LEATHER (PAIR)', category: 'TOOLS & FASTENERS', unit: 'Pair', sku: 'TL-SAF-02'),
    DefaultProductItem(name: 'WHEELBARROW HEAVY DUTY STEEL', category: 'TOOLS & FASTENERS', unit: 'Pcs', sku: 'TL-WBL-01'),

    // 8. DOORS & HARDWARE
    DefaultProductItem(name: 'PLYWOOD FLUSH DOOR 3FT x 7FT', category: 'DOORS & HARDWARE', unit: 'Pcs', sku: 'DR-DOOR-01'),
    DefaultProductItem(name: 'STEEL SECURITY DOOR 3FT x 7FT', category: 'DOORS & HARDWARE', unit: 'Pcs', sku: 'DR-DOOR-02'),
    DefaultProductItem(name: 'STAINLESS STEEL LEVER DOOR HANDLE (SET)', category: 'DOORS & HARDWARE', unit: 'Pcs', sku: 'DR-HND-01'),
    DefaultProductItem(name: 'BRASS TUBULAR DOOR HANDLE SET', category: 'DOORS & HARDWARE', unit: 'Pcs', sku: 'DR-HND-02'),
    DefaultProductItem(name: 'ALUMINIUM FLUSH DOOR HANDLE', category: 'DOORS & HARDWARE', unit: 'Pcs', sku: 'DR-HND-03'),
    DefaultProductItem(name: 'MORTISE DOOR LOCK WITH HANDLES', category: 'DOORS & HARDWARE', unit: 'Pcs', sku: 'DR-LCK-01'),
    DefaultProductItem(name: 'HEAVY DUTY DOOR HINGES 4 INCH (PAIR)', category: 'DOORS & HARDWARE', unit: 'Pair', sku: 'DR-HNG-01'),
    DefaultProductItem(name: 'PADLOCK BRASS 50MM', category: 'DOORS & HARDWARE', unit: 'Pcs', sku: 'DR-PAD-01'),
    DefaultProductItem(name: 'DOOR CLOSER HYDRAULIC', category: 'DOORS & HARDWARE', unit: 'Pcs', sku: 'DR-CLS-01'),
  ];

  Future<void> seedProducts({bool resetExistingToZero = false}) async {
    final user = ref.read(currentUserProvider);
    if (user == null || user.branchCode == null) return;

    if (resetExistingToZero) {
      await resetAllStockToZero();
    }

    // Get existing products to avoid duplicates
    final existingProductsAsync = ref.read(productsFutureProvider);
    final existingNames = existingProductsAsync.value?.map((p) => p.name.toLowerCase()).toSet() ?? {};
    final existingSkus = existingProductsAsync.value?.map((p) => p.sku?.toLowerCase()).whereType<String>().toSet() ?? {};

    final List<Product> newProducts = [];
    final List<Map<String, dynamic>> newProductJsons = [];

    for (var item in defaultCatalog) {
      if (existingNames.contains(item.name.toLowerCase())) continue;
      if (existingSkus.contains(item.sku.toLowerCase())) continue;

      final String validUuid = UuidUtils.generate();

      final product = Product(
        id: validUuid,
        branchCode: user.branchCode,
        name: item.name,
        retailPrice: 0.0,
        wholesalePrice: 0.0,
        costPrice: 0.0,
        imageUrl: '',
        category: item.category,
        stockQuantity: 0.0, // Default store stock set to 0.0
        warehouseQuantity: 0.0, // Default warehouse stock set to 0.0
        unit: item.unit,
        sku: item.sku,
        lowStockThreshold: item.lowStockThreshold,
        minStoreStock: item.lowStockThreshold,
      );

      newProducts.add(product);
      newProductJsons.add(product.toJson());
    }

    if (newProducts.isEmpty) return;

    // 1. Save instantly to local Hive cache
    try {
      final box = Hive.box(OfflineSyncService.productsBoxName);
      for (var product in newProducts) {
        box.put(product.id, product.toJson());
      }
    } catch (e) {
      debugPrint('Seeder Hive Cache Error: $e');
    }

    // 2. Refresh local Riverpod notifier immediately so products show up instantly on UI
    ref.read(productsFutureProvider.notifier).refreshFromCache();

    // 3. Batch bulk insert to Supabase Cloud in chunks of 50
    try {
      for (var i = 0; i < newProductJsons.length; i += 50) {
        final chunk = newProductJsons.sublist(
          i, 
          (i + 50 > newProductJsons.length) ? newProductJsons.length : i + 50
        );
        await SupabaseConfig.client.from('products').insert(chunk);
      }
    } catch (e) {
      debugPrint('Seeder Supabase Bulk Insert Error (saved to local cache): $e');
    }

    ref.invalidate(productsFutureProvider);
  }

  /// Purges old cosmetics products and legacy cosmetics sales records from local Hive cache and Supabase
  Future<void> purgeLegacyCosmeticsData() async {
    final user = ref.read(currentUserProvider);
    final branchCode = user?.branchCode;

    // 1. Clear local Hive cache boxes
    await OfflineSyncService.clearAllCache();

    // 2. Remove legacy cosmetics products from Supabase
    if (branchCode != null && branchCode.isNotEmpty) {
      try {
        await SupabaseConfig.client
            .from('products')
            .delete()
            .eq('branch_code', branchCode)
            .or('category.ilike.%skincare%,category.ilike.%cosmetics%,category.ilike.%makeup%,category.ilike.%perfume%,category.ilike.%fragrance%,category.ilike.%haircare%');
      } catch (e) {
        debugPrint('Purge cosmetics products note: $e');
      }
    }

    ref.invalidate(productsFutureProvider);
    ref.invalidate(saleHistoryProvider);
  }
}

final productSeederProvider = Provider<ProductSeeder>((ref) => ProductSeeder(ref));
