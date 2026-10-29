<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Product extends Model {
    public $incrementing = false;
    protected $keyType = 'string';

    protected $fillable = [
        'id', 'branch_code', 'name', 'retail_price', 'wholesale_price', 'cost_price',
        'category', 'stock_quantity', 'warehouse_quantity', 'sku', 'unit', 'image_url', 'is_deleted'
    ];

    protected $casts = [
        'retail_price' => 'decimal:2',
        'wholesale_price' => 'decimal:2',
        'cost_price' => 'decimal:2',
        'stock_quantity' => 'decimal:2',
        'warehouse_quantity' => 'decimal:2',
        'is_deleted' => 'boolean',
    ];
}
