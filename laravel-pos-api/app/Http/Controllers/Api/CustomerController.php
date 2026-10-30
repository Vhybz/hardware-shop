<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Customer;

class CustomerController extends Controller {

    public function index(Request $request) {
        $branchCode = $request->query('branch_code', 'MAIN');
        $customers = Customer::where('branch_code', $branchCode)->get();

        return response()->json([
            'status' => 'success',
            'data' => $customers,
        ]);
    }

    public function store(Request $request) {
        $data = $request->all();
        $id = $data['id'] ?? uniqid('cust_');

        $customer = Customer::updateOrCreate(
            ['id' => $id],
            [
                'id' => $id,
                'branch_code' => $data['branch_code'] ?? $data['branchCode'] ?? 'MAIN',
                'name' => $data['name'] ?? 'Customer',
                'phone' => $data['phone'] ?? null,
                'email' => $data['email'] ?? null,
                'address' => $data['address'] ?? null,
                'total_purchases' => $data['total_purchases'] ?? $data['totalPurchases'] ?? 0,
                'debt_amount' => $data['debt_amount'] ?? $data['debtAmount'] ?? 0,
            ]
        );

        return response()->json([
            'status' => 'success',
            'customer' => $customer,
        ], 201);
    }
}
