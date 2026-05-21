import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
  //static bool isMockData = false;
static bool isMockData = true;

  //static const String baseUrl = 'https://utmhackathon-ecopal-1.onrender.com';
   static const String baseUrl = 'http://127.0.0.1:8000';

  static String? _getAuthToken() {
    final session = Supabase.instance.client.auth.currentSession;
    return session?.accessToken;
  }

  static final Dio _dio = Dio();

  // ===========================================================================
  // 1. AI REALITY CHECK (Insights)
  // ===========================================================================
  static Future<String> getRealityCheck() async {
    if (isMockData) {
      final String jsonString = await rootBundle.loadString('assets/backend/data/ai_insights.json');
      final List<dynamic> data = jsonDecode(jsonString);
      return data[0]['message']; 
    }

    final token = _getAuthToken();
    if (token == null) throw Exception('User is not logged in.');

    final response = await http.get(
      Uri.parse('$baseUrl/ai/reality-check'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['message'];
    } else {
      throw Exception('Backend error: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> getProfile() async {
    if (isMockData) {
      final String jsonString = await rootBundle.loadString('assets/backend/data/profiles.json');
      return jsonDecode(jsonString); 
    }

    final token = _getAuthToken();
    final response = await http.get(Uri.parse('$baseUrl/profile'), headers: {'Authorization': 'Bearer $token'});
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getPockets() async {
    if (isMockData) {
      final String jsonString = await rootBundle.loadString('assets/backend/data/pockets.json');
      return jsonDecode(jsonString); 
    }

    final token = _getAuthToken();
    final response = await http.get(Uri.parse('$baseUrl/pockets'), headers: {'Authorization': 'Bearer $token'});
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getPetStatus() async {
    if (isMockData) {
      final String jsonString = await rootBundle.loadString('assets/backend/data/pets.json');
      return jsonDecode(jsonString); 
    }

    final token = _getAuthToken();
    final response = await http.get(Uri.parse('$baseUrl/pet'), headers: {'Authorization': 'Bearer $token'});
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getTransactions() async {
    if (isMockData) {
      final String jsonString = await rootBundle.loadString('assets/backend/data/transactions.json');
      return jsonDecode(jsonString); 
    }

    final token = _getAuthToken();
    final response = await http.get(Uri.parse('$baseUrl/transactions'), headers: {'Authorization': 'Bearer $token'});
    return jsonDecode(response.body);
  }

  static Future<void> postTransaction(Map<String, dynamic> data) async {
    if (isMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return; 
    }
    
    final token = _getAuthToken();
    final response = await http.post(
      Uri.parse('$baseUrl/transactions'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    );
    if (response.statusCode != 200 && response.statusCode != 201) throw Exception('Backend error');
  }

  static Future<void> updatePetStatus(Map<String, dynamic> data) async {
    if (isMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return; 
    }
    
    final token = _getAuthToken();
    final response = await http.post(
      Uri.parse('$baseUrl/pet/update'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) throw Exception('Backend error');
  }

  static Future<void> updateProfile(Map<String, dynamic> data) async {
    if (data.containsKey('safe_to_spend_balance')) {
      final balance = data['safe_to_spend_balance'];
      if (balance is! num) {
        throw Exception('Validation Error: safe_to_spend_balance must be a number');
      }
      if (balance < 0) {
        throw Exception('Validation Error: safe_to_spend_balance cannot be negative');
      }
    }

    if (data.containsKey('reward_points')) {
      final points = data['reward_points'];
      if (points is! int) {
        throw Exception('Validation Error: reward_points must be an integer');
      }
      if (points < 0) {
        throw Exception('Validation Error: reward_points cannot be negative');
      }
    }

    if (isMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return; 
    }
    
    final token = _getAuthToken();
    final response = await http.post(
      Uri.parse('$baseUrl/profile/update'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Backend error: ${response.statusCode}');
    }
  }

  static Future<void> interactWithPet(String action) async {
    if (isMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return; 
    }
    
    final token = _getAuthToken();
    final response = await http.post(
      Uri.parse('$baseUrl/pet/interact'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'action': action}),
    );
    if (response.statusCode != 200) throw Exception('Backend error');
  }

  static Future<String> createPocket(Map<String, dynamic> data) async {
    if (isMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return data['id']; 
    }
    
    final token = _getAuthToken();
    final response = await http.post(
      Uri.parse('$baseUrl/pockets'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    );
    
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Backend error');
    }
    
    return jsonDecode(response.body)['data']['id'];
  }

  static Future<void> updatePocket(String id, Map<String, dynamic> data) async {
    if (isMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }
    final token = _getAuthToken();
    final response = await http.put(
      Uri.parse('$baseUrl/pockets/$id'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) throw Exception('Backend error');
  }

  static Future<void> releasePartialPocket(String pocketId, double amount) async {
    if (isMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }
    
    final token = _getAuthToken();
    final response = await http.post(
      Uri.parse('$baseUrl/pockets/$pocketId/release-partial'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'amount': amount}),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to release partial pocket: ${response.statusCode}');
    }
  }

  static Future<void> deletePocket(String id) async {
    if (isMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }
    final token = _getAuthToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/pockets/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200 && response.statusCode != 204) throw Exception('Backend error');
  }

  static Future<void> releasePocket(String id, double amountToRelease) async {
    if (isMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      return;
    }
    final token = _getAuthToken();
    final response = await http.post(
      Uri.parse('$baseUrl/pockets/$id/release'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'amount': amountToRelease})
    );
    if (response.statusCode != 200 && response.statusCode != 204) throw Exception('Backend error');
  }

  static Future<double> getSafeToSpendBalance() async {
    if (isMockData) {
      final String jsonString = await rootBundle.loadString('assets/backend/data/profiles.json');
      final data = jsonDecode(jsonString);
      return (data['safe_to_spend_balance'] as num).toDouble();
    }

    final token = _getAuthToken();
    if (token == null) throw Exception('User is not logged in.');

    final response = await http.get(
      Uri.parse('$baseUrl/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['safe_to_spend_balance'] as num).toDouble();
    } else {
      throw Exception('Backend error: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> getHabitTax() async {
    if (isMockData) {
      final String jsonString = await rootBundle.loadString('assets/backend/data/habit_tax.json');
      final data = jsonDecode(jsonString);
      return data;
    }

    final token = _getAuthToken();
    if (token == null) throw Exception('User is not logged in.');

    final response = await http.get(
      Uri.parse('$baseUrl/habit-tax'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Backend error: ${response.statusCode}');
    }
  }

  static Future<void> updateHabitTax(bool isAvailable) async {
    if (isMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return; 
    }
    
    final token = _getAuthToken();
    final response = await http.post(
      Uri.parse('$baseUrl/habit-tax/update'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({"available": isAvailable}),
    );
    if (response.statusCode != 200) throw Exception('Backend error');
  }

  static Future<String> getBehaviorAnalysis() async {
    if (isMockData) {
      return "Your recent grocery run at Market Street was excellent! By choosing seasonal vegetables, you've saved 15% compared to last week.";
    }

    final token = _getAuthToken();
    final response = await http.get(Uri.parse('$baseUrl/ai/behavior'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['analysis'] ?? 'Mochi is still calculating...';
    }
    throw Exception('Backend error');
  }

  static final List<String> _savingsTips = [
    "Track every expense using a budgeting app or notebook daily.",
    "Cook meals at home instead of ordering food frequently.",
    "Set monthly savings goals and reward yourself responsibly afterward.",
    "Avoid impulse purchases by waiting 24 hours before buying anything.",
    "Use student discounts whenever shopping, dining, or subscribing online.",
    "Bring a reusable water bottle and avoid buying expensive drinks.",
    "Save spare change and small notes in a separate container.",
    "Compare prices online before purchasing gadgets, clothes, or accessories.",
    "Limit entertainment subscriptions and share family plans when possible.",
    "Use public transport or carpool to reduce transportation expenses.",
    "Sedikit-dikit, lama-lama menjadi bukit!",
    "Gong Xi Fa Cai!"
  ];

  static Future<String> getSavingsTip() async {
    if (isMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    _savingsTips.shuffle();
    return _savingsTips.first;
  }

  static Future<Map<String, dynamic>> scanReceipt(dynamic file) async {
    if (isMockData) {
      await Future.delayed(const Duration(seconds: 2));
      return {
        "items": [
          {"name": "Mock Item 1", "price": 12.50},
          {"name": "Mock Item 2", "price": 8.00}
        ],
        "total": 20.50
      };
    }

    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;

    if (token == null) throw Exception('User not logged in');

    final uri = Uri.parse('$baseUrl/ai/scan-receipt');
    
    var request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    if (file is String) {
      request.files.add(await http.MultipartFile.fromPath('file', file));
    } else if (file.path != null) {
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
    } else {
      throw Exception('Unsupported file format sent to scanner');
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Backend AI scan failed: ${response.statusCode}');
    }
  }

  static String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'image/jpeg';
    }
  }

  static Future<Map<String, dynamic>> scanReceiptWeb(String fileName, Uint8List bytes) async {
    if (isMockData) {
      await Future.delayed(const Duration(seconds: 2));
      return {
        "items": [
          {"name": "Mock Web Item", "price": 15.00}
        ],
        "total": 15.00
      };
    }

    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;
    if (token == null) throw Exception('User not logged in');

    final uri = Uri.parse('$baseUrl/ai/scan-receipt');
    var request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: fileName,
      contentType: MediaType.parse(_getMimeType(fileName)),
    );
    request.files.add(multipartFile);

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Backend AI scan failed: ${response.statusCode}');
    }
  }

  static Future<List<dynamic>> getLeaderboard() async {
    if (isMockData) {
      final String jsonString = await rootBundle.loadString('assets/backend/data/leaderboard.json'); 
      return jsonDecode(jsonString);
    }

    final token = _getAuthToken();
    if (token == null) throw Exception('User is not logged in.');

    final response = await http.get(
      Uri.parse('$baseUrl/community/leaderboard'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load leaderboard: ${response.statusCode}');
    }
  }

  static List<dynamic>? _mockFriendsCache;
    static List<dynamic>? _mockRequestsCache;

    static Future<void> _initMockFriendsData() async {
      if (_mockFriendsCache == null || _mockRequestsCache == null) {
        final String jsonString =
            await rootBundle.loadString('assets/backend/data/friends.json');
        final data = jsonDecode(jsonString);
        // 从 JSON 读取后存入内存，之后的操作都在内存里改
        _mockFriendsCache = List<dynamic>.from(data['friends']);
        _mockRequestsCache = List<dynamic>.from(data['requests']);
      }
    }

    static Future<List<dynamic>> getFriends() async {
      if (isMockData) {
        await _initMockFriendsData();
        return _mockFriendsCache!;
      }
      final token = _getAuthToken();
      final response = await http.get(
        Uri.parse('$baseUrl/friends'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) throw Exception('Failed to load friends');
      return jsonDecode(response.body) as List<dynamic>;
    }

    static Future<List<dynamic>> getFriendRequests() async {
      if (isMockData) {
        await _initMockFriendsData();
        return _mockRequestsCache!;
      }
      final token = _getAuthToken();
      final response = await http.get(
        Uri.parse('$baseUrl/friends/requests'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) throw Exception('Failed to load requests');
      return jsonDecode(response.body) as List<dynamic>;
    }

    static Future<Map<String, dynamic>?> searchUser(String username) async {
      if (isMockData) {
        await Future.delayed(const Duration(milliseconds: 500));
        return {
          "uid": "u999-mock-search",
          "username": username,
          "pet_name": "Ghost",
          "species": "tabby",
          "level": 99
        };
      }
      final token = _getAuthToken();
      final uri = Uri.parse('$baseUrl/users/search')
          .replace(queryParameters: {'username': username});
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) throw Exception('Search failed');
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    static Future<void> sendFriendRequest(String targetUid) async {
      if (isMockData) {
        await Future.delayed(const Duration(milliseconds: 300));
        return;
      }
      final token = _getAuthToken();
      final response = await http.post(
        Uri.parse('$baseUrl/friends/request'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'target_uid': targetUid}),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to send request');
      }
    }

    static Future<void> acceptFriendRequest(String senderUid) async {
      if (isMockData) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (_mockRequestsCache != null) {
          final requestIndex = _mockRequestsCache!.indexWhere((r) => r['uid'] == senderUid);
          if (requestIndex != -1) {
            final acceptedUser = _mockRequestsCache!.removeAt(requestIndex);
            acceptedUser['streak'] = 0; 
            _mockFriendsCache?.add(acceptedUser);
          }
        }
        return;
      }
      final token = _getAuthToken();
      final response = await http.post(
        Uri.parse('$baseUrl/friends/accept'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'sender_uid': senderUid}),
      );
      if (response.statusCode != 200) throw Exception('Failed to accept');
    }

    static Future<void> ignoreFriendRequest(String senderUid) async {
      if (isMockData) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (_mockRequestsCache != null) {
          _mockRequestsCache!.removeWhere((r) => r['uid'] == senderUid);
        }
        return;
      }
      final token = _getAuthToken();
      final response = await http.post(
        Uri.parse('$baseUrl/friends/ignore'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'sender_uid': senderUid}),
      );
      if (response.statusCode != 200) throw Exception('Failed to ignore');
    }
}