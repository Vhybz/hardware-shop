<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use App\Models\User;

class AuthController extends Controller {

    public function login(Request $request) {
        $credentials = $request->validate([
            'email' => 'required|email',
            'password' => 'required',
        ]);

        $email = strtolower(trim($credentials['email']));
        $password = $credentials['password'];

        if (!Auth::attempt(['email' => $email, 'password' => $password])) {
            return response()->json([
                'status' => 'error',
                'message' => 'Invalid email address or password'
            ], 401);
        }

        $user = Auth::user();

        if (isset($user->status) && in_array(strtolower($user->status), ['suspended', 'deleted'])) {
            return response()->json([
                'status' => 'error',
                'message' => 'This account has been deleted or suspended.'
            ], 403);
        }

        if (isset($user->status) && $user->status !== 'approved') {
            return response()->json([
                'status' => 'error',
                'message' => 'Your staff account is pending approval.'
            ], 403);
        }

        $token = bin2hex(random_bytes(32));

        return response()->json([
            'status' => 'success',
            'token' => $token,
            'user' => $user,
        ]);
    }

    public function register(Request $request) {
        $validated = $request->validate([
            'first_name' => 'required|string',
            'surname' => 'required|string',
            'email' => 'required|email|unique:users,email',
            'password' => 'required|string|min:6',
            'phone' => 'nullable|string',
            'gender' => 'nullable|string',
            'dob' => 'nullable|string',
            'role' => 'nullable|string',
            'branch_code' => 'nullable|string',
            'status' => 'nullable|string',
            'enabled_permissions' => 'nullable|array',
        ]);

        $firstName = $validated['first_name'];
        $surname = $validated['surname'];
        $email = strtolower(trim($validated['email']));

        $user = User::create([
            'name' => trim("$firstName $surname"),
            'first_name' => $firstName,
            'surname' => $surname,
            'email' => $email,
            'password' => $validated['password'],
            'phone' => $validated['phone'] ?? null,
            'gender' => $validated['gender'] ?? null,
            'dob' => $validated['dob'] ?? null,
            'role' => $validated['role'] ?? 'cashier',
            'branch_code' => $validated['branch_code'] ?? null,
            'status' => $validated['status'] ?? 'pending',
            'enabled_permissions' => $validated['enabled_permissions'] ?? null,
        ]);

        $token = bin2hex(random_bytes(32));

        return response()->json([
            'status' => 'success',
            'token' => $token,
            'user' => $user,
        ], 201);
    }

    public function getUsers(Request $request) {
        $users = User::all();
        return response()->json([
            'status' => 'success',
            'data' => $users,
        ]);
    }

    public function me(Request $request) {
        return response()->json([
            'status' => 'success',
            'user' => $request->user(),
        ]);
    }
}
