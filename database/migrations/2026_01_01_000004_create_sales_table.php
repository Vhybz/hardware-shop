<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('sales', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('branch_code');
            $table->string('cashier_id')->nullable();
            $table->string('cashier_name');
            $table->string('customer_id')->nullable();
            $table->string('customer_name')->nullable();
            $table->string('customer_phone')->nullable();
            $table->decimal('total_amount', 12, 2)->default(0);
            $table->decimal('amount_paid', 12, 2)->default(0);
            $table->decimal('balance', 12, 2)->default(0);
            $table->decimal('discount_amount', 12, 2)->default(0);
            $table->string('status')->default('completed');
            $table->jsonb('payments')->default('[]');
            $table->jsonb('items')->default('[]');
            $table->timestamp('timestamp')->useCurrent();
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->index(['branch_code', 'timestamp']);
            $table->index('cashier_id');
            $table->index('status');
        });
    }

    public function down(): void {
        Schema::dropIfExists('sales');
    }
};
