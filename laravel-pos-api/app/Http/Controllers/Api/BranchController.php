<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Branch;

class BranchController extends Controller {

    public function index() {
        $branches = Branch::where('is_active', true)->get();

        return response()->json([
            'status' => 'success',
            'data' => $branches,
        ]);
    }

    public function store(Request $request) {
        $data = $request->all();
        $code = $data['code'] ?? $data['id'] ?? uniqid('branch_');

        $branch = Branch::updateOrCreate(
            ['code' => $code],
            [
                'code' => $code,
                'name' => $data['name'] ?? 'Branch',
                'location' => $data['location'] ?? 'Ghana',
                'admin_id' => $data['admin_id'] ?? $data['adminId'] ?? null,
            ]
        );

        return response()->json([
            'status' => 'success',
            'branch' => $branch,
        ], 201);
    }
}
