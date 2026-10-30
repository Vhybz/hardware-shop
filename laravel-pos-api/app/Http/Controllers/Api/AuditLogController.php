<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\AuditLog;

class AuditLogController extends Controller {

    public function index(Request $request) {
        $logs = AuditLog::orderBy('timestamp', 'desc')->paginate(100);

        return response()->json([
            'status' => 'success',
            'data' => $logs->items(),
        ]);
    }

    public function store(Request $request) {
        $data = $request->all();
        $id = $data['id'] ?? uniqid('audit_');

        $log = AuditLog::updateOrCreate(
            ['id' => $id],
            [
                'id' => $id,
                'branch_code' => $data['branch_code'] ?? $data['branchCode'] ?? null,
                'user_id' => $data['user_id'] ?? $data['userId'] ?? null,
                'user_name' => $data['user_name'] ?? $data['userName'] ?? null,
                'action' => $data['action'] ?? 'ACTION',
                'entity_type' => $data['entity_type'] ?? $data['entityType'] ?? 'SYSTEM',
                'entity_id' => $data['entity_id'] ?? $data['entityId'] ?? null,
                'old_data' => $data['old_data'] ?? $data['oldData'] ?? null,
                'new_data' => $data['new_data'] ?? $data['newData'] ?? null,
                'timestamp' => $data['timestamp'] ?? now(),
            ]
        );

        return response()->json([
            'status' => 'success',
            'log' => $log,
        ], 201);
    }
}
