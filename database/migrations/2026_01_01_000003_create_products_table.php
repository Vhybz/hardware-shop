<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('products', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('branch_code');
            $table->string('name');
            $table->decimal('retail_price', 12, 2)->default(0);
            $table->decimal('wholesale_price', 12, 2)->default(0);
            $table->decimal('cost_price', 12, 2)->default(0);
            $table->string('category');
            $table->decimal('stock_quantity', 12, 2)->default(0);
            $table->decimal('warehouse_quantity', 12, 2)->default(0);
            $table->string('sku')->nullable();
            $table->string('unit')->default('pcs');
            $table->text('image_url')->nullable();
            $table->boolean('is_deleted')->default(false);
            $table->timestamps();

            $table->index(['branch_code', 'category']);
            $table->index('sku');
            $table->index('is_deleted');
        });
    }

    public function down(): void {
        Schema::dropIfExists('products');
    }
};
