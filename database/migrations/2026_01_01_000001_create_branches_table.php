<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('branches', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('code')->unique();
            $table->string('name');
            $table->string('location')->default('Zongo One Way, Sunyani, Ghana');
            $table->decimal('latitude', 10, 7)->default(7.3349);
            $table->decimal('longitude', 10, 7)->default(-2.3123);
            $table->decimal('radius_meters', 10, 2)->default(500.0);
            $table->timestamps();
        });
    }

    public function down(): void {
        Schema::dropIfExists('branches');
    }
};
