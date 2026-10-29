<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Sale;
use App\Models\Product;
use App\Models\Customer;
use App\Models\Expense;
use App\Models\AuditLog;
use App\Models\User;
use App\Models\Branch;

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
                    case 'USER':
                        if (isset($payload['email'])) {
                            $fName = $payload['first_name'] ?? $payload['firstName'] ?? '';
                            $sName = $payload['surname'] ?? '';
                            User::updateOrCreate(
                                ['email' => $payload['email']],
                                [
                                    'name' => trim("$fName $sName"),
                                    'first_name' => $fName,
                                    'surname' => $sName,
                                    'email' => $payload['email'],
                                    'password' => $payload['password'] ?? bcrypt('password123'),
                                    'phone' => $payload['phone'] ?? null,
                                    'gender' => $payload['gender'] ?? null,
                                    'dob' => $payload['dob'] ?? null,
                                    'role' => $payload['role'] ?? 'cashier',
                                    'branch_code' => $payload['branch_code'] ?? $payload['branchCode'] ?? null,
                                    'status' => $payload['status'] ?? 'approved',
                                    'enabled_permissions' => $payload['enabled_permissions'] ?? $payload['enabledPermissions'] ?? null,
                                ]
                            );
                        }
                        break;
                    case 'BRANCH':
                        if (isset($payload['code']) || isset($payload['id'])) {
                            Branch::updateOrCreate(['code' => $payload['code'] ?? $payload['id']], $payload);
                        }
                        break;
                    case 'SALE':
                        if (isset($payload['id'])) {
                            Sale::updateOrCreate(['id' => $payload['id']], $payload);
                        }
                        break;
                    case 'UPDATE_PRODUCT':
                        if (isset($payload['id'])) {
                            Product::updateOrCreate(['id' => $payload['id']], $payload);
                        }
                        break;
                    case 'CUSTOMER':
                        if (isset($payload['id'])) {
                            Customer::updateOrCreate(['id' => $payload['id']], $payload);
                        }
                        break;
                    case 'EXPENSE':
                        if (isset($payload['id'])) {
                            Expense::updateOrCreate(['id' => $payload['id']], $payload);
                        }
                        break;
                    case 'AUDIT':
                        if (isset($payload['id'])) {
                            AuditLog::updateOrCreate(['id' => $payload['id']], $payload);
                        }
                        break;
                }
                $processed++;
            } catch (\Exception $e) {
                // Log and continue processing
            }
        }

        return response()->json([
            'status' => 'success',
            'processed_count' => $processed,
        ]);
    }
}
