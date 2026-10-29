<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Sale extends Model {
    public $incrementing = false;
    protected $keyType = 'string';

    protected $fillable = [
        'id', 'branch_code', 'cashier_id', 'cashier_name', 'customer_id',
        'customer_name', 'customer_phone', 'total_amount', 'amount_paid',
        'balance', 'discount_amount', 'status', 'payments', 'items', 'timestamp', 'is_active'
    ];

    protected $casts = [
        'total_amount' => 'decimal:2',
        'amount_paid' => 'decimal:2',
        'balance' => 'decimal:2',
        'discount_amount' => 'decimal:2',
        'payments' => 'array',
        'items' => 'array',
        'is_active' => 'boolean',
        'timestamp' => 'datetime',
    ];
}
