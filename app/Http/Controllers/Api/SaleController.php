<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Models\Sale;
use App\Models\Product;

class SaleController extends Controller {

    public function store(Request $request) {
        $data = $request->all();
        $id = $data['id'] ?? uniqid('sale_');
        $totalAmount = $data['total_amount'] ?? $data['totalAmount'] ?? 0;
        $payments = $data['payments'] ?? [];
        $amountPaid = $data['amount_paid'] ?? $data['amountPaid'] ?? $totalAmount;
        $balance = $data['balance'] ?? 0;

        return DB::transaction(function () use ($data, $id, $totalAmount, $payments, $amountPaid, $balance) {
            $sale = Sale::updateOrCreate(
                ['id' => $id],
                [
                    'id' => $id,
                    'branch_code' => $data['branch_code'] ?? $data['branchCode'] ?? 'MAIN',
                    'cashier_id' => $data['cashier_id'] ?? $data['cashierId'] ?? null,
                    'cashier_name' => $data['cashier_name'] ?? $data['cashierName'] ?? 'Cashier',
                    'customer_id' => $data['customer_id'] ?? $data['customerId'] ?? null,
                    'customer_name' => $data['customer_name'] ?? $data['customerName'] ?? null,
                    'customer_phone' => $data['customer_phone'] ?? $data['customerPhone'] ?? null,
                    'total_amount' => $totalAmount,
                    'amount_paid' => $amountPaid,
                    'balance' => $balance,
                    'discount_amount' => $data['total_discount'] ?? $data['discount_amount'] ?? 0,
                    'status' => $data['status'] ?? 'completed',
                    'items' => $data['items'] ?? [],
                    'payments' => $payments,
                    'timestamp' => $data['timestamp'] ?? now(),
                ]
            );

            // Atomic stock decrement
            $items = $data['items'] ?? [];
            if (is_array($items)) {
                foreach ($items as $item) {
                    $prodId = $item['product_id'] ?? $item['product']['id'] ?? null;
                    $qty = $item['quantity'] ?? 0;
                    if ($prodId && $qty > 0) {
                        Product::where('id', $prodId)->decrement('stock_quantity', $qty);
                    }
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
