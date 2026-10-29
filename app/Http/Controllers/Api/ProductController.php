<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Product;

class ProductController extends Controller {

    public function index(Request $request) {
        $branchCode = $request->query('branch_code', 'MAIN');
        $products = Product::where('branch_code', $branchCode)
            ->where('is_deleted', false)
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $products,
        ]);
    }

    public function store(Request $request) {
        $data = $request->all();
        $id = $data['id'] ?? $data['sku'] ?? uniqid('prod_');
        $branchCode = $data['branch_code'] ?? $data['branchCode'] ?? 'MAIN';

        $product = Product::updateOrCreate(
            ['id' => $id],
            [
                'id' => $id,
                'branch_code' => $branchCode,
                'name' => $data['name'] ?? 'New Product',
                'retail_price' => $data['retail_price'] ?? $data['retailPrice'] ?? 0,
                'wholesale_price' => $data['wholesale_price'] ?? $data['wholesalePrice'] ?? 0,
                'cost_price' => $data['cost_price'] ?? $data['costPrice'] ?? 0,
                'category' => $data['category'] ?? 'General',
                'stock_quantity' => $data['stock_quantity'] ?? $data['stockQuantity'] ?? 0,
                'warehouse_quantity' => $data['warehouse_quantity'] ?? $data['warehouseQuantity'] ?? 0,
                'sku' => $data['sku'] ?? null,
                'unit' => $data['unit'] ?? 'pcs',
                'is_deleted' => $data['is_deleted'] ?? false,
            ]
        );

        return response()->json([
            'status' => 'success',
            'product' => $product,
        ], 201);
    }
}
