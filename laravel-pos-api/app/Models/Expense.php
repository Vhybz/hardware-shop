<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Expense extends Model {
    public $incrementing = false;
    protected $keyType = 'string';

    protected $fillable = [
        'id', 'branch_code', 'category', 'amount', 'description', 'recorded_by', 'timestamp'
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'timestamp' => 'datetime',
    ];
}
