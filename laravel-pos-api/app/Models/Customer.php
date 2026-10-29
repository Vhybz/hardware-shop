<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Customer extends Model {
    public $incrementing = false;
    protected $keyType = 'string';

    protected $fillable = [
        'id', 'branch_code', 'name', 'phone', 'email', 'loyalty_points', 'visit_count'
    ];

    protected $casts = [
        'loyalty_points' => 'decimal:2',
        'visit_count' => 'integer',
    ];
}
