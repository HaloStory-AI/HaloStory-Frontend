import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'auth_service.dart';
import 'localization_service.dart';
import 'config_service.dart';

/// Hasil konsumsi SSE /chat/stream/:uuid.
enum StreamOutcomeKind {
  /// Event `done` valid diterima (hasil akhir bersih, sudah di-unwrap).
  done,
  /// User menekan Stop: koneksi ditutup, teks parsial tetap tersimpan.
  stopped,
  /// Koneksi gagal/terputus: caller fallback ke polling.
  failed,
}

class StreamOutcome {
  final StreamOutcomeKind kind;
  final Map<String, dynamic>? result;
  const StreamOutcome._(this.kind, this.result);
  const StreamOutcome.done(Map<String, dynamic> result)
      : this._(StreamOutcomeKind.done, result);
  const StreamOutcome.stopped()
      : this._(StreamOutcomeKind.stopped, null);
  const StreamOutcome.failed()
      : this._(StreamOutcomeKind.failed, null);
}

class AIService {
  static const _removedProviders = {
    'groq', 'novel', 'horde', 'venus', 'nanogpt', 'chutes', 'featherless', 'mancer', 'arli',
  };

  static String _normalizeByokProvider(String? provider) {
    if (provider == null || _removedProviders.contains(provider)) return 'gemini';
    return provider;
  }

  static String normalizeProvider(String? p) {
    // BYOM + System dihapus total — semua fallback ke BYOK
    return 'BYOK';
  }

  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>?> sendMessage({
    required String provider, // always BYOK (legacy System/BYOM migrated)
    required List<Map<String, String>> messages,
    String? botId,
    List<String>? botIds,
    String? language,
    String? summary,
    String? persona,
    bool isGroup = false,
  }) async {
    final token = await _authService.getToken();
    if (token == null) return null;

    final actualLanguage =
        language ?? LocalizationService().currentLanguageName;
    final prefs = await SharedPreferences.getInstance();

    // Load user persona: prefer per-chat override, fallback to global profile
    final userProfile = await _authService.getUserProfile();
    final globalPersona = userProfile?['persona'] as String?;
    final userPersona = persona ?? globalPersona;

    // Advanced params — BYOK defaults
    final double temp = prefs.getDouble('ai_temp') ?? _getDefault('temp');
    final int responseLength =
        prefs.getInt('ai_response_length') ?? _getDefault('max_token');
    final int maxTokens =
        prefs.getInt('ai_max_token') ?? _getDefault('max_token');
    final double topP =
        prefs.getDouble('ai_top_p') ?? _getDefault('top_p');
    final double topA =
        prefs.getDouble('ai_top_a') ?? _getDefault('top_a');
    final int topK = prefs.getInt('ai_top_k') ?? _getDefault('top_k');
    final double repPenalty =
        prefs.getDouble('ai_rep_penalty') ?? _getDefault('rep_penalty');

    final int contextLimit =
        prefs.getInt('ai_context_limit') ?? _getDefault('context_limit');
    final int ltmBudget =
        prefs.getInt('ai_ltm_budget') ?? _getDefault('ltm_budget');
    final int embedBudget =
        prefs.getInt('ai_embed_budget') ?? _getDefault('embed_budget');
    final int historyDepth =
        prefs.getInt('ai_history_depth') ?? _getDefault('history_depth');
    final bool reasoningEnabled =
        prefs.getBool('ai_reasoning_enabled') ?? false;
    final bool streamEnabled = prefs.getBool('ai_stream_enabled') ?? true;

    final Map<String, dynamic> advancedParams = {
      'temperature': temp,
      'response_length': responseLength,
      'max_tokens': maxTokens,
      'top_p': topP,
      'top_a': topA,
      'top_k': topK,
      'repetition_penalty': repPenalty,
      'context_limit': contextLimit,
      'ltm_budget': ltmBudget,
      'embedding_budget': embedBudget,
      'history_depth': historyDepth,
      'reasoning': {'enabled': reasoningEnabled},
      'reasoning_enabled': reasoningEnabled,
      'stream': streamEnabled,
    };

    try {
      final apiKey = prefs.getString('byok_api_key') ?? '';
      final model = prefs.getString('byok_model') ?? 'openai/gpt-3.5-turbo';
      final byokProvider = _normalizeByokProvider(prefs.getString('byok_provider'));
      final baseUrl = prefs.getString('byok_base_url') ?? '';

      return await _sendByokMessage(
        token,
        messages,
        botId,
        botIds,
        actualLanguage,
        apiKey,
        model,
        byokProvider,
        baseUrl,
        advancedParams,
        summary,
        isGroup,
        userPersona,
      );
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: AIService Error: $e');
      }
    }
    return null;
  }

  dynamic _getDefault(String param) {
    switch (param) {
      case 'temp':
        return 0.7;
      case 'max_token':
        return 4096;
      case 'top_p':
        return 1.0;
      case 'top_a':
        return 0.0;
      case 'top_k':
        return 50;
      case 'rep_penalty':
        return 1.0;
      case 'context_limit':
        return 3000;
      case 'ltm_budget':
        return 1000;
      case 'embed_budget':
        return 500;
      case 'history_depth':
        return 15;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _sendByokMessage(
    String token,
    List<Map<String, String>> messages,
    String? botId,
    List<String>? botIds,
    String? language,
    String apiKey,
    String model,
    String byokProvider,
    String baseUrl,
    Map<String, dynamic> advancedParams,
    String? summary,
    bool isGroup,
    String? userPersona,
  ) async {
    final endpoint = '${AppConstants.apiUrl}/byok/$byokProvider/chat';

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'messages': messages,
        'bot_id': botId,
        'bot_ids': botIds,
        'language': language,
        'api_key': apiKey,
        'model': model,
        'base_url': baseUrl,
        'summary': summary,
        if (isGroup) 'is_group': true,
        if (userPersona != null && userPersona.isNotEmpty)
          'user_persona': userPersona,
        ...advancedParams,
      }),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    if (response.statusCode == 503) {
      ConfigService.enterMaintenance();
    }

    dynamic parsedBody;
    try {
      parsedBody = jsonDecode(response.body);
    } catch (_) {}

    return {
      'error': true,
      'status_code': response.statusCode,
      'raw_error': parsedBody ?? response.body,
      'message': 'Server returned ${response.statusCode}',
    };
  }

  Future<Map<String, dynamic>?> summarizeChat({
    required List<Map<String, String>> messages,
    String? botId,
    String? language,
    String? provider,
    List<String>? existingMemories,
  }) async {
    final token = await _authService.getToken();
    if (token == null) return null;

    final actualLanguage =
        language ?? LocalizationService().currentLanguageName;

    try {
      final body = <String, dynamic>{
        'messages': messages,
        'bot_id': botId,
        'language': actualLanguage,
      };
      if (existingMemories != null && existingMemories.isNotEmpty) {
        body['existing_memories'] = existingMemories;
      }

      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('byok_api_key') ?? '';
      final model = prefs.getString('byok_model') ?? '';
      final byokProvider = _normalizeByokProvider(prefs.getString('byok_provider'));
      final baseUrl = prefs.getString('byok_base_url') ?? '';
      final endpoint = '${AppConstants.apiUrl}/byok/$byokProvider/chat';

      body.addAll({
        'api_key': apiKey,
        'model': model,
        'base_url': baseUrl,
        'is_summarize': true,
      });

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return _errorResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: AIService summarizeChat Error: $e');
      }
      return {
        'error': true,
        'error_status_code': 0,
        'summary': '[ERROR: Network error - ${e.toString()}]',
      };
    }
  }

  Map<String, dynamic> _errorResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        body['error'] = true;
        body['error_status_code'] = response.statusCode;
        return body;
      }
    } catch (_) {}
    return {
      'error': true,
      'error_status_code': response.statusCode,
      'summary': '[ERROR ${response.statusCode}] Failed to summarize',
    };
  }

  Future<Map<String, dynamic>?> checkChatStatus(String uuid) async {
    final token = await _authService.getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiUrl}/chat/status/$uuid'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      if (response.statusCode == 404) return {'status': 'not_found'};

      try {
        final body = jsonDecode(response.body);
        return body is Map<String, dynamic> ? body : {'status': 'not_found'};
      } catch (_) {
        return {'status': 'not_found', 'raw_error': response.body};
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: AIService checkChatStatus Error: $e');
      }
    }
    return null;
  }

  /// SSE client untuk mode stream: GET /chat/stream/:uuid.
  Future<StreamOutcome> streamChatStatus(
    String uuid, {
    void Function(String delta)? onDelta,
    bool Function()? isCancelled,
    Duration timeout = const Duration(seconds: 210),
  }) async {
    final token = await _authService.getToken();
    if (token == null) return const StreamOutcome.failed();

    http.StreamedResponse? streamed;
    try {
      final client = http.Client();
      try {
        final request = http.Request(
          'GET',
          Uri.parse('${AppConstants.apiUrl}/chat/stream/$uuid'),
        );
        request.headers.addAll({
          'Accept': 'text/event-stream',
          'Authorization': 'Bearer $token',
        });
        streamed =
            await client.send(request).timeout(const Duration(seconds: 60));

        if (streamed.statusCode != 200) {
          await streamed.stream.drain();
          return const StreamOutcome.failed();
        }

        String? event;
        final buffer = StringBuffer();
        Map<String, dynamic>? doneEnvelope;

        await for (final chunk
            in streamed.stream.transform(utf8.decoder).timeout(
                  timeout,
                  onTimeout: (sink) => sink.close(),
                )) {
          if (isCancelled?.call() == true) {
            return const StreamOutcome.stopped();
          }
          buffer.write(chunk);
        var text = buffer.toString();
        var idx = text.indexOf('\n\n');
        while (idx != -1) {
          final rawEvent = text.substring(0, idx);
          text = text.substring(idx + 2);
          for (final line in rawEvent.split('\n')) {
            final trimmed = line.trim();
            if (trimmed.startsWith('event:')) {
              event = trimmed.substring(6).trim();
            } else if (trimmed.startsWith('data:')) {
              final data = trimmed.substring(5).trim();
              if (event == 'delta' && onDelta != null) {
                try {
                  final parsed = jsonDecode(data);
                  final content = parsed is Map
                      ? parsed['content']?.toString() ?? ''
                      : data;
                  if (content.isNotEmpty) onDelta(content);
                } catch (_) {
                  if (data.isNotEmpty) onDelta(data);
                }
              } else if (event == 'done') {
                try {
                  final parsed = jsonDecode(data);
                  if (parsed is Map<String, dynamic>) {
                    doneEnvelope = _unwrapDoneEnvelope(parsed);
                  } else if (parsed is Map) {
                    doneEnvelope =
                        _unwrapDoneEnvelope(Map<String, dynamic>.from(parsed));
                  }
                } catch (_) {
                  doneEnvelope = {'uuid': uuid};
                }
              }
            }
          }
          idx = text.indexOf('\n\n');
        }
        buffer.clear();
        buffer.write(text);
        if (doneEnvelope != null) break;
      }
      if (isCancelled?.call() == true) {
        return const StreamOutcome.stopped();
      }
      if (doneEnvelope == null) return const StreamOutcome.failed();
      return StreamOutcome.done(doneEnvelope);
      } finally {
        client.close();
      }
    } catch (e) {
      if (isCancelled?.call() == true) {
        return const StreamOutcome.stopped();
      }
      if (kDebugMode) {
        print('DEBUG: AIService streamChatStatus Error: $e');
      }
    } finally {
      try {
        await streamed?.stream.drain();
      } catch (_) {}
    }
    return const StreamOutcome.failed();
  }

  Map<String, dynamic> _unwrapDoneEnvelope(Map<String, dynamic> envelope) {
    final inner = envelope['response'];
    if (inner is Map<String, dynamic>) {
      final result = Map<String, dynamic>.from(inner);
      result['status_code'] = _asInt(envelope['status_code']) ?? 200;
      return result;
    }
    if (inner is Map) {
      final result = Map<String, dynamic>.from(inner);
      result['status_code'] = _asInt(envelope['status_code']) ?? 200;
      return result;
    }
    return envelope;
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// True jika mode stream aktif (default true untuk instalasi baru).
  static Future<bool> isStreamEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('ai_stream_enabled') ?? true;
  }
}
