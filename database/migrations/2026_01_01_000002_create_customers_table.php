<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('customers', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('branch_code');
            $table->string('name');
            $table->string('phone')->nullable();
            $table->string('email')->nullable();
            $table->decimal('loyalty_points', 12, 2)->default(0);
            $table->integer('visit_count')->default(0);
            $table->timestamps();

            $table->index(['branch_code', 'phone']);
        });
    }

    public function down(): void {
        Schema::dropIfExists('customers');
    }
};
