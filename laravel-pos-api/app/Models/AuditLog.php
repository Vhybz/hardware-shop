<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AuditLog extends Model {
    public $incrementing = false;
    protected $keyType = 'string';

    protected $fillable = [
        'id', 'branch_code', 'user_id', 'user_name', 'user_role', 'action',
        'entity_type', 'entity_id', 'old_data', 'new_data', 'timestamp'
    ];

    protected $casts = [
        'old_data' => 'array',
        'new_data' => 'array',
        'timestamp' => 'datetime',
    ];
}
