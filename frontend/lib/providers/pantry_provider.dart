import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/device_user_id.dart';
import '../models/recipe_model.dart';
import '../models/recipe_details_model.dart';

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8100',
);

class PantryItem {
  final int id;
  final String itemName;
  final String? category;
  final int? estimatedExpiryDays;
  final DateTime? expiryDate;
  final DateTime createdAt;

  PantryItem({
    required this.id,
    required this.itemName,
    this.category,
    this.estimatedExpiryDays,
    this.expiryDate,
    required this.createdAt,
  });

  factory PantryItem.fromJson(Map<String, dynamic> json) {
    return PantryItem(
      id: json['id'] as int,
      itemName: json['item_name'] as String,
      category: json['category'] as String?,
      estimatedExpiryDays: json['estimated_expiry_days'] as int?,
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item_name': itemName,
      'category': category,
      'estimated_expiry_days': estimatedExpiryDays,
      'expiry_date': expiryDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class PantryState {
  final List<PantryItem> items;
  final bool isLoading;
  final String? errorMessage;

  const PantryState({
    required this.items,
    required this.isLoading,
    this.errorMessage,
  });

  PantryState copyWith({
    List<PantryItem>? items,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PantryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  factory PantryState.initial() => const PantryState(
        items: [],
        isLoading: false,
        errorMessage: null,
      );
}

abstract class PantryLocalCache {
  Future<void> saveItems(List<PantryItem> items);
  Future<List<PantryItem>> loadItems();
}

class PantryApi {
  final Dio _dio;

  PantryApi(this._dio);

  Future<List<PantryItem>> fetchPantry({required String userId}) async {
    final res = await _dio.get<List<dynamic>>(
      '/pantry',
      queryParameters: {'user_id': userId},
    );
    final data = res.data ?? [];
    return data
        .map((e) => PantryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PantryItem>> ingestReceiptText({
    required String userId,
    required String rawText,
  }) async {
    final res = await _dio.post<List<dynamic>>(
      '/pantry/ingest-receipt-text',
      data: jsonEncode({
        'user_id': userId,
        'raw_text': rawText,
      }),
      options: Options(
        headers: {'Content-Type': 'application/json'},
      ),
    );
    final data = res.data ?? [];
    return data
        .map((e) => PantryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Upload a receipt image; backend runs OCR and adds items to pantry.
  /// Prefer [uploadReceiptImageBytes] when you have bytes (e.g. from web).
  Future<List<PantryItem>> uploadReceiptImage({
    required String userId,
    required String filePath,
  }) async {
    final formData = FormData.fromMap({
      'user_id': userId,
      'file': await MultipartFile.fromFile(
        filePath,
        filename: 'receipt.jpg',
      ),
    });
    return _uploadReceiptFormData(formData);
  }

  /// Upload receipt image from bytes (works on web where file path may be unavailable).
  Future<List<PantryItem>> uploadReceiptImageBytes({
    required String userId,
    required List<int> imageBytes,
  }) async {
    final formData = FormData.fromMap({
      'user_id': userId,
      'file': MultipartFile.fromBytes(
        imageBytes,
        filename: 'receipt.jpg',
      ),
    });
    return _uploadReceiptFormData(formData);
  }

  Future<List<PantryItem>> _uploadReceiptFormData(FormData formData) async {
    final res = await _dio.post<List<dynamic>>(
      '/pantry/upload-receipt',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
    );
    final data = res.data ?? [];
    return data
        .map((e) => PantryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PantryItem> createPantryItem({
    required String userId,
    required String itemName,
    String? category,
    int? estimatedExpiryDays,
    DateTime? expiryDate,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/pantry',
      queryParameters: {'user_id': userId},
      data: jsonEncode({
        'item_name': itemName,
        'category': category,
        'estimated_expiry_days': estimatedExpiryDays,
        if (expiryDate != null) 'expiry_date': expiryDate.toUtc().toIso8601String(),
      }),
      options: Options(
        headers: {'Content-Type': 'application/json'},
      ),
    );
    final data = res.data!;
    return PantryItem.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> parseReceiptText({
    required String userId,
    required String rawText,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/pantry/parse-receipt-text',
      data: jsonEncode({
        'user_id': userId,
        'raw_text': rawText,
      }),
      options: Options(
        headers: {'Content-Type': 'application/json'},
      ),
    );
    final data = res.data?['items'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Recipe>> fetchRecipeSuggestions({
    required String userId,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/recipes/suggestions',
      queryParameters: {'user_id': userId},
    );
    final data = res.data ?? [];
    return data.map((e) {
      final json = e as Map<String, dynamic>;
      final rawUrl = json['image_url'] as String? ?? '';
      final proxiedUrl =
          '$apiBaseUrl/image-proxy?url=${Uri.encodeComponent(rawUrl)}';
      return Recipe(
        id: json['id'].toString(),
        title: json['title'] as String,
        imageUrl: proxiedUrl,
        ownedIngredients: json['owned_ingredients'] as int? ?? 0,
        totalIngredients: json['total_ingredients'] as int? ?? 0,
        matchPercentage:
            (json['match_percentage'] as num?)?.toDouble() ?? 0.0,
        tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
      );
    }).toList();
  }

  Future<RecipeDetails> fetchRecipeAiDetails({
    required String recipeTitle,
    required List<String> pantryItems,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/recipes/ai-details',
      data: jsonEncode({
        'recipe_title': recipeTitle,
        'pantry_items': pantryItems,
      }),
      options: Options(
        headers: {'Content-Type': 'application/json'},
      ),
    );
    final data = res.data!;
    return RecipeDetails.fromJson(data);
  }
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      contentType: 'application/json',
      responseType: ResponseType.json,
    ),
  );

  return dio;
});

final pantryApiProvider = Provider<PantryApi>((ref) {
  final dio = ref.watch(dioProvider);
  return PantryApi(dio);
});

final pantryLocalCacheProvider = Provider<PantryLocalCache?>((ref) {
  return null;
});

final isOnlineProvider = StateProvider<bool>((ref) {
  return true;
});

/// Per-device user ID: generated once per installation and stored locally.
/// Each user/device sees only their own pantry and recipes.
final deviceUserIdProvider = FutureProvider<String>((ref) => getOrCreateDeviceUserId());

/// Current user ID for API calls. Empty until device ID is loaded.
final userIdProvider = Provider<String>((ref) {
  return ref.watch(deviceUserIdProvider).valueOrNull ?? '';
});

class PantryNotifier extends StateNotifier<PantryState> {
  final PantryApi _api;
  final PantryLocalCache? _cache;
  final Ref _ref;
  final String _userId;

  PantryNotifier({
    required PantryApi api,
    required Ref ref,
    required String userId,
    PantryLocalCache? cache,
  })  : _api = api,
        _cache = cache,
        _ref = ref,
        _userId = userId,
        super(PantryState.initial());

  Future<void> loadPantry() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final online = _ref.read(isOnlineProvider);

    if (!online && _cache != null) {
      final cached = await _cache.loadItems();
      state = state.copyWith(items: cached, isLoading: false);
      return;
    }

    try {
      final items = await _api.fetchPantry(userId: _userId);
      state = state.copyWith(items: items, isLoading: false);

      if (_cache != null) {
        await _cache.saveItems(items);
      }
    } on DioException catch (e) {
      final message = e.response?.data is Map<String, dynamic>
          ? (e.response!.data['detail']?.toString() ??
              'Failed to load pantry items.')
          : 'Failed to load pantry items.';

      if (_cache != null) {
        final cached = await _cache.loadItems();
        if (cached.isNotEmpty) {
          state = state.copyWith(
            items: cached,
            isLoading: false,
            errorMessage: message,
          );
          return;
        }
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: message,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unexpected error loading pantry.',
      );
    }
  }

  Future<void> addItemsFromReceipt(String rawOcrText) async {
    if (rawOcrText.trim().isEmpty) {
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final newItems = await _api.ingestReceiptText(
        userId: _userId,
        rawText: rawOcrText,
      );

      final combined = [...state.items, ...newItems];
      state = state.copyWith(items: combined, isLoading: false);

      if (_cache != null) {
        await _cache.saveItems(combined);
      }
    } on DioException catch (e) {
      final message = e.response?.data is Map<String, dynamic>
          ? (e.response!.data['detail']?.toString() ??
              'Failed to process receipt.')
          : 'Failed to process receipt.';
      state = state.copyWith(
        isLoading: false,
        errorMessage: message,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unexpected error processing receipt.',
      );
    }
  }

  /// Scan receipt from camera image: upload image to backend for OCR and add items.
  Future<void> addItemsFromReceiptImage(String imageFilePath) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final newItems = await _api.uploadReceiptImage(
        userId: _userId,
        filePath: imageFilePath,
      );

      final combined = [...state.items, ...newItems];
      state = state.copyWith(items: combined, isLoading: false);

      if (_cache != null) {
        await _cache.saveItems(combined);
      }
    } on DioException catch (e) {
      final message = e.response?.data is Map<String, dynamic>
          ? (e.response!.data['detail']?.toString() ??
              'Failed to scan receipt.')
          : 'Failed to scan receipt.';
      state = state.copyWith(
        isLoading: false,
        errorMessage: message,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unexpected error scanning receipt.',
      );
    }
  }

  /// Scan receipt from image bytes (e.g. from web file picker or after reading XFile).
  Future<void> addItemsFromReceiptImageBytes(List<int> imageBytes) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final newItems = await _api.uploadReceiptImageBytes(
        userId: _userId,
        imageBytes: imageBytes,
      );

      final combined = [...state.items, ...newItems];
      state = state.copyWith(items: combined, isLoading: false);

      if (_cache != null) {
        await _cache.saveItems(combined);
      }
    } on DioException catch (e) {
      final message = e.response?.data is Map<String, dynamic>
          ? (e.response!.data['detail']?.toString() ??
              'Failed to scan receipt.')
          : 'Failed to scan receipt.';
      state = state.copyWith(
        isLoading: false,
        errorMessage: message,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unexpected error scanning receipt.',
      );
    }
  }

  /// Add a single pantry item (e.g. from barcode scan). Returns the created item or null on error.
  Future<PantryItem?> addSingleItem({
    required String itemName,
    String? category,
    int? estimatedExpiryDays,
  }) async {
    try {
      final item = await _api.createPantryItem(
        userId: _userId,
        itemName: itemName,
        category: category,
        estimatedExpiryDays: estimatedExpiryDays,
      );
      final combined = [...state.items, item];
      state = state.copyWith(items: combined);
      if (_cache != null) {
        await _cache.saveItems(combined);
      }
      return item;
    } on DioException catch (e) {
      final message = e.response?.data is Map<String, dynamic>
          ? (e.response!.data['detail']?.toString() ?? 'Failed to add item.')
          : 'Failed to add item.';
      state = state.copyWith(errorMessage: message);
      return null;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Unexpected error adding item.');
      return null;
    }
  }

  /// Returns true if delete succeeded, false on API/network error.
  Future<bool> deleteItem(int id) async {
    try {
      await _api._dio.delete(
        '/pantry/$id',
        queryParameters: {'user_id': _userId},
      );
      final updated = state.items.where((p) => p.id != id).toList();
      state = state.copyWith(items: updated);
      if (_cache != null) {
        await _cache.saveItems(updated);
      }
      return true;
    } on DioException {
      return false;
    }
  }

  void addLocalItem(PantryItem item) {
    final updated = [...state.items, item];
    state = state.copyWith(items: updated);

    if (_cache != null) {
      _cache.saveItems(updated);
    }
  }
}

final pantryNotifierProvider =
    StateNotifierProvider.family<PantryNotifier, PantryState, String>(
  (ref, userId) {
    final api = ref.watch(pantryApiProvider);
    final cache = ref.watch(pantryLocalCacheProvider);
    return PantryNotifier(
      api: api,
      ref: ref,
      userId: userId,
      cache: cache,
    );
  },
);

// --- Demo UI data for recipe screens (until real API is wired) ---
final dashboardRecipesProvider =
    FutureProvider<List<Recipe>>((ref) async {
  final userId = ref.watch(userIdProvider);
  if (userId.isEmpty) return <Recipe>[];

  final api = ref.watch(pantryApiProvider);
  final pantryState = ref.watch(pantryNotifierProvider(userId));
  if (pantryState.items.isEmpty) return <Recipe>[];

  return api.fetchRecipeSuggestions(userId: userId);
});

final recipeDetailsProvider =
    FutureProvider.family<RecipeDetails, Recipe>((ref, recipe) async {
  final api = ref.watch(pantryApiProvider);
  final userId = ref.watch(userIdProvider);
  final pantryState = ref.watch(pantryNotifierProvider(userId));
  final pantryItems =
      pantryState.items.map((p) => p.itemName).toList(growable: false);

  return api.fetchRecipeAiDetails(
    recipeTitle: recipe.title,
    pantryItems: pantryItems,
  );
});
