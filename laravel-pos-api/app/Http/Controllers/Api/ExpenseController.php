<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Expense;

class ExpenseController extends Controller {

    public function index(Request $request) {
        $branchCode = $request->query('branch_code', 'MAIN');
        $expenses = Expense::where('branch_code', $branchCode)
            ->orderBy('timestamp', 'desc')
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $expenses,
        ]);
    }

    public function store(Request $request) {
        $data = $request->all();
        $id = $data['id'] ?? uniqid('exp_');

        $expense = Expense::updateOrCreate(
            ['id' => $id],
            [
                'id' => $id,
                'branch_code' => $data['branch_code'] ?? $data['branchCode'] ?? 'MAIN',
                'category' => $data['category'] ?? 'General',
                'amount' => $data['amount'] ?? 0,
                'description' => $data['description'] ?? $data['title'] ?? 'Expense',
                'recorded_by' => $data['recorded_by'] ?? $data['recordedBy'] ?? 'Staff',
                'timestamp' => $data['timestamp'] ?? $data['date'] ?? now(),
            ]
        );

        return response()->json([
            'status' => 'success',
            'expense' => $expense,
        ], 201);
    }
}
