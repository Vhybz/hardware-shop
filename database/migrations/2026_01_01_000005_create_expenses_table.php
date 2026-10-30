<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('expenses', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('branch_code');
            $table->string('category');
            $table->decimal('amount', 12, 2)->default(0);
            $table->text('description')->nullable();
            $table->string('recorded_by');
            $table->timestamp('timestamp')->useCurrent();
            $table->timestamps();

            $table->index(['branch_code', 'category']);
        });
    }

    public function down(): void {
        Schema::dropIfExists('expenses');
    }
};
