<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Models\Sale;
use App\Models\Product;

class SaleController extends Controller {

    public function store(Request $request) {
        $validated = $request->validate([
            'id' => 'required|string',
            'branch_code' => 'required|string',
            'cashier_id' => 'nullable|string',
            'cashier_name' => 'required|string',
            'total_amount' => 'required|numeric',
            'amount_paid' => 'required|numeric',
            'balance' => 'required|numeric',
            'status' => 'required|string',
            'items' => 'required|array',
            'payments' => 'required|array',
        ]);

        return DB::transaction(function () use ($validated, $request) {
            $sale = Sale::updateOrCreate(
                ['id' => $validated['id']],
                [
                    'branch_code' => $validated['branch_code'],
                    'cashier_id' => $validated['cashier_id'],
                    'cashier_name' => $validated['cashier_name'],
                    'customer_id' => $request->input('customer_id'),
                    'customer_name' => $request->input('customer_name'),
                    'customer_phone' => $request->input('customer_phone'),
                    'total_amount' => $validated['total_amount'],
                    'amount_paid' => $validated['amount_paid'],
                    'balance' => $validated['balance'],
                    'discount_amount' => $request->input('discount_amount', 0),
                    'status' => $validated['status'],
                    'items' => $validated['items'],
                    'payments' => $validated['payments'],
                    'timestamp' => now(),
                ]
            );

            // Atomic stock decrement
            foreach ($validated['items'] as $item) {
                if (isset($item['product_id']) && isset($item['quantity'])) {
                    Product::where('id', $item['product_id'])
                        ->decrement('stock_quantity', $item['quantity']);
                }
            }

            return response()->json([
                'status' => 'success',
                'message' => 'Sale recorded successfully',
                'sale' => $sale,
            ], 201);
        });
    }

    public function index(Request $request) {
        $branchCode = $request->query('branch_code', 'MAIN');
        $sales = Sale::where('branch_code', $branchCode)
            ->where('is_active', true)
            ->orderBy('timestamp', 'desc')
            ->paginate(50);

        return response()->json([
            'status' => 'success',
            'data' => $sales,
        ]);
    }
}
