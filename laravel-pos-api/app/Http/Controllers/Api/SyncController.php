<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Sale;
use App\Models\Product;
use App\Models\Customer;
use App\Models\Expense;
use App\Models\AuditLog;

class SyncController extends Controller {

    public function processBatch(Request $request) {
        $batch = $request->input('batch', []);
        $processed = 0;

        foreach ($batch as $item) {
            $type = $item['type'] ?? '';
            $payload = $item['payload'] ?? [];

            if (empty($type) || empty($payload)) continue;

            try {
                switch ($type) {
                    case 'SALE':
                        Sale::updateOrCreate(['id' => $payload['id']], $payload);
                        break;
                    case 'UPDATE_PRODUCT':
                        Product::updateOrCreate(['id' => $payload['id']], $payload);
                        break;
                    case 'CUSTOMER':
                        Customer::updateOrCreate(['id' => $payload['id']], $payload);
                        break;
                    case 'EXPENSE':
                        Expense::updateOrCreate(['id' => $payload['id']], $payload);
                        break;
                    case 'AUDIT':
                        AuditLog::updateOrCreate(['id' => $payload['id']], $payload);
                        break;
                }
                $processed++;
            } catch (\Exception $e) {
                // Log and continue processing rest of batch
            }
        }

        return response()->json([
            'status' => 'success',
            'processed_count' => $processed,
        ]);
    }
}
