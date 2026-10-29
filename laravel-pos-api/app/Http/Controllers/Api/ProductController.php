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
        $validated = $request->validate([
            'id' => 'required|string',
            'branch_code' => 'required|string',
            'name' => 'required|string',
            'retail_price' => 'numeric',
            'wholesale_price' => 'numeric',
            'cost_price' => 'numeric',
            'category' => 'required|string',
            'stock_quantity' => 'numeric',
            'warehouse_quantity' => 'numeric',
            'sku' => 'nullable|string',
            'unit' => 'nullable|string',
        ]);

        $product = Product::updateOrCreate(
            ['id' => $validated['id']],
            $validated
        );

        return response()->json([
            'status' => 'success',
            'product' => $product,
        ], 201);
    }
}
