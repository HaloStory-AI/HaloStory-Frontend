import 'dart:async';
import 'ai_service.dart';
import 'local_chat_service.dart';

enum TaskType { aiResponse, summary }

enum TaskStatus { polling, processing, progress, completed, failed, retrying }

class ChatTaskEvent {
  final TaskType type;
  final TaskStatus status;
  final String botId;
  final String? taskId;
  final Map<String, dynamic>? data;
  final String? errorMessage;

  ChatTaskEvent({
    required this.type,
    required this.status,
    required this.botId,
    this.taskId,
    this.data,
    this.errorMessage,
  });
}

class _PollingTask {
  final String taskId;
  final String botId;
  final TaskType type;
  final String timestamp;
  bool isActive = true;

  _PollingTask({
    required this.taskId,
    required this.botId,
    required this.type,
    required this.timestamp,
  });

  void cancel() => isActive = false;
}

class _SummaryTask {
  final String botId;
  final String provider;
  final List<Map<String, dynamic>> messages;
  final Map<int, String> initialSummaries;
  Map<int, String> summaries;
  List<String> memories;
  bool isActive = true;

  _SummaryTask({
    required this.botId,
    required this.provider,
    required this.messages,
    required this.initialSummaries,
  })  : summaries = Map.from(initialSummaries),
        memories = [];

  void cancel() => isActive = false;
}

class ChatTaskService {
  static final ChatTaskService _instance = ChatTaskService._();
  factory ChatTaskService() => _instance;
  ChatTaskService._();

  final Map<String, _PollingTask> _tasks = {};
  final Map<String, _SummaryTask> _summaryTasks = {};
  final StreamController<ChatTaskEvent> _controller =
      StreamController<ChatTaskEvent>.broadcast();
  Stream<ChatTaskEvent> get events => _controller.stream;

  final AIService _aiService = AIService();
  final LocalChatService _localChatService = LocalChatService();

  static const int _maxRetries = 5;
  static const int _maxPollChecks = 60;
  static const Duration _pollInterval = Duration(seconds: 3);

  static const int _maxSummaryRetries = 5;
  static const int _summaryBatchSize = 20;
  static const int _summaryPollChecks = 30;

  void _emit(ChatTaskEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  void startAiPolling({
    required String uuid,
    required String botId,
    required String timestamp,
    String? responderBotId,
  }) {
    if (_tasks.containsKey(uuid)) return;

    final task = _PollingTask(
      taskId: uuid,
      botId: botId,
      type: TaskType.aiResponse,
      timestamp: timestamp,
    );
    _tasks[uuid] = task;

    _runAiPolling(task, responderBotId: responderBotId ?? botId);
  }

  Future<void> _runAiPolling(
    _PollingTask task, {
    String? responderBotId,
  }) async {
    final uuid = task.taskId;
    final botId = task.botId;
    final actualResponderId = responderBotId ?? botId;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      if (!task.isActive) return;

      for (int check = 0; check < _maxPollChecks && task.isActive; check++) {
        await Future.delayed(_pollInterval);
        if (!task.isActive) return;

        final response = await _aiService.checkChatStatus(uuid);
        if (response == null) continue;

        final status = response['status'] as String?;

        if (status == 'processing' || status == 'queued') {
          _emit(ChatTaskEvent(
            type: TaskType.aiResponse,
            status: TaskStatus.processing,
            botId: botId,
            taskId: uuid,
          ));
          continue;
        }

        // Completed or error
        if (response['error'] != null || status == 'not_found' || status == 'failed') {
          final statusCode = (response['error_status_code'] ?? 0) as int;
          final delay = _getRetryDelay(statusCode);

          if (delay < 0 || attempt >= _maxRetries) {
            _emit(ChatTaskEvent(
              type: TaskType.aiResponse,
              status: TaskStatus.failed,
              botId: botId,
              taskId: uuid,
              data: response,
              errorMessage: response['summary']?.toString(),
            ));
            _tasks.remove(uuid);
            return;
          }

          for (int s = delay; s > 0 && task.isActive; s--) {
            _emit(ChatTaskEvent(
              type: TaskType.aiResponse,
              status: TaskStatus.retrying,
              botId: botId,
              taskId: uuid,
              data: {'retryDelay': s},
            ));
            await Future.delayed(const Duration(seconds: 1));
          }
          break; // retry outer loop
        }

        // Success
        await _saveAiResponse(response, botId, responderBotId: actualResponderId);

        response['_msgTimestamp'] = task.timestamp;
        final bubbleContent = response['choices']?[0]?['message']?['content'] as String?;
        if (bubbleContent != null && bubbleContent.isNotEmpty) {
          final parts = bubbleContent
              .split(RegExp(r'\n\n'))
              .where((p) => p.trim().isNotEmpty)
              .length;
          response['_bubbleCount'] = parts > 0 ? parts : 1;
        } else {
          response['_bubbleCount'] = 1;
        }
        _emit(ChatTaskEvent(
          type: TaskType.aiResponse,
          status: TaskStatus.completed,
          botId: botId,
          taskId: uuid,
          data: response,
        ));
        _tasks.remove(uuid);
        return;
      }
    }

    _emit(ChatTaskEvent(
      type: TaskType.aiResponse,
      status: TaskStatus.failed,
      botId: botId,
      taskId: uuid,
      errorMessage: 'Max retries exceeded',
    ));
    _tasks.remove(uuid);
  }

  void startSummary({
    required String botId,
    required String provider,
    required List<Map<String, dynamic>> messages,
    Map<int, String>? existingSummaries,
  }) {
    final taskId = 'summary_$botId';
    if (_summaryTasks.containsKey(taskId)) return;

    final task = _SummaryTask(
      botId: botId,
      provider: provider,
      messages: messages,
      initialSummaries: existingSummaries ?? {},
    );
    _summaryTasks[taskId] = task;
    _runSummaryTask(task, taskId);
  }

  Future<void> _runSummaryTask(_SummaryTask task, String taskId) async {
    final botId = task.botId;
    final batchSize = _summaryBatchSize;

    final realMessages = task.messages
        .where(
          (m) =>
              m['content'] != null &&
              m['role'] != 'system' &&
              m['isTempSummary'] != true,
        )
        .toList();

    // Retry last 1-2 failed batches
    final sortedKeys = task.summaries.keys.toList()..sort();
    int retried = 0;
    for (int k = sortedKeys.length - 1; k >= 0 && retried < 2; k--) {
      final idx = sortedKeys[k];
      if (task.summaries[idx] == '[...]') {
        task.summaries.remove(idx);
        retried++;
      } else {
        break;
      }
    }

    int totalBatchesToSummarize = 0;
    for (int i = 0; i <= realMessages.length - batchSize; i += batchSize) {
      if (!task.summaries.containsKey(i)) {
        totalBatchesToSummarize++;
      }
    }

    if (totalBatchesToSummarize == 0) {
      _summaryTasks.remove(taskId);
      return;
    }

    task.memories =
        List<String>.from(await _localChatService.loadMemories(botId));

    _emit(ChatTaskEvent(
      type: TaskType.summary,
      status: TaskStatus.processing,
      botId: botId,
      taskId: taskId,
      data: {
        'totalBatches': totalBatchesToSummarize,
        'summaries': Map.from(task.summaries),
      },
    ));

    int processedBatches = 0;

    for (int i = 0;
        i <= realMessages.length - batchSize && task.isActive;
        i += batchSize) {
      if (!task.summaries.containsKey(i)) {
        bool batchDone = false;

        for (int attempt = 1;
            attempt <= _maxSummaryRetries && !batchDone && task.isActive;
            attempt++) {
          try {
            final List<Map<String, String>> batch = realMessages
                .sublist(i, i + batchSize)
                .map(
                  (m) => {
                    'role': m['role'] as String,
                    'content': m['content'] as String,
                  },
                )
                .toList();

            final result = await _aiService.summarizeChat(
              messages: batch,
              botId: botId,
              provider: task.provider,
              existingMemories: task.memories,
            );

            if (!task.isActive) return;

            if (result != null &&
                result['status'] == 'queued' &&
                result['uuid'] != null) {
              final pollResult =
                  await _pollSummaryUuid(result['uuid'], task);
              if (!task.isActive) return;

              if (pollResult == null) {
                if (attempt >= _maxSummaryRetries) {
                  task.summaries[i] = '[...]';
                  batchDone = true;
                }
                continue;
              }

              if (pollResult['error'] != null ||
                  pollResult['status'] == 'not_found' ||
                  pollResult['status'] == 'failed') {
                final errorStatusCode =
                    pollResult['error_status_code'] ?? 0;
                final delay = _getRetryDelay(errorStatusCode);

                if (delay < 0 || attempt >= _maxSummaryRetries) {
                  task.summaries[i] = '[...]';
                  batchDone = true;
                  break;
                }

                for (int s = delay; s > 0 && task.isActive; s--) {
                  _emit(ChatTaskEvent(
                    type: TaskType.summary,
                    status: TaskStatus.retrying,
                    botId: botId,
                    taskId: taskId,
                    data: {
                      'batch': processedBatches + 1,
                      'total': totalBatchesToSummarize,
                      'retryDelay': s,
                    },
                  ));
                  await Future.delayed(const Duration(seconds: 1));
                }
                continue;
              } else {
                final summaryText = pollResult['summary'] ??
                    pollResult['response']?['summary'];
                if (summaryText != null && summaryText.isNotEmpty) {
                  task.summaries[i] = summaryText;
                }
                final mems = pollResult['memory_worth_keeping'] ??
                    pollResult['response']?['memory_worth_keeping'];
                if (mems is List && mems.isNotEmpty) {
                  task.memories = List<String>.from(mems);
                  await _localChatService.saveMemories(
                      botId, task.memories);
                }
                batchDone = true;
              }
            } else if (result != null &&
                result['summary'] != null &&
                (result['summary'] as String).isNotEmpty &&
                result['error'] != true) {
              task.summaries[i] = result['summary'];
              if (result['memory_worth_keeping'] is List) {
                task.memories =
                    List<String>.from(result['memory_worth_keeping']);
                await _localChatService.saveMemories(
                    botId, task.memories);
              }
              batchDone = true;
            } else {
              final errorStatusCode =
                  result != null ? (result['error_status_code'] ?? 0) : 0;
              final delay = _getRetryDelay(errorStatusCode);

              if (delay < 0 || attempt >= _maxSummaryRetries) {
                task.summaries[i] = '[...]';
                batchDone = true;
                break;
              }

              for (int s = delay; s > 0 && task.isActive; s--) {
                _emit(ChatTaskEvent(
                  type: TaskType.summary,
                  status: TaskStatus.retrying,
                  botId: botId,
                  taskId: taskId,
                  data: {
                    'batch': processedBatches + 1,
                    'total': totalBatchesToSummarize,
                    'retryDelay': s,
                  },
                ));
                await Future.delayed(const Duration(seconds: 1));
              }
            }
          } catch (e) {
            if (attempt >= _maxSummaryRetries) {
              task.summaries[i] = '[...]';
              batchDone = true;
            }
          }
        }

        processedBatches++;
        await _localChatService.saveSummaries(botId, task.summaries);

        _emit(ChatTaskEvent(
          type: TaskType.summary,
          status: TaskStatus.progress,
          botId: botId,
          taskId: taskId,
          data: {
            'batch': processedBatches,
            'total': totalBatchesToSummarize,
            'summaries': Map.from(task.summaries),
            'memories': List.from(task.memories),
          },
        ));
      }
    }

    _emit(ChatTaskEvent(
      type: TaskType.summary,
      status: TaskStatus.completed,
      botId: botId,
      taskId: taskId,
      data: {
        'totalBatches': totalBatchesToSummarize,
        'summaries': Map.from(task.summaries),
        'memories': List.from(task.memories),
      },
    ));
    _summaryTasks.remove(taskId);
  }

  Future<Map<String, dynamic>?> _pollSummaryUuid(
      String uuid, _SummaryTask task) async {
    int checks = _summaryPollChecks;
    while (task.isActive && checks > 0) {
      await Future.delayed(const Duration(seconds: 3));
      if (!task.isActive) return null;
      final status = await _aiService.checkChatStatus(uuid);
      if (status == null) {
        checks--;
        continue;
      }
      if (status['status'] == 'processing' ||
          status['status'] == 'queued') {
        checks--;
        continue;
      }
      return status;
    }
    return null;
  }

  Future<void> _saveAiResponse(
    Map<String, dynamic> response,
    String botId, {
    String? responderBotId,
  }) async {
    if (response['choices'] == null) return;

    final content = response['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.isEmpty) return;

    await _localChatService.insertMessage(botId, {
      'role': 'assistant',
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
      'bot_id': responderBotId ?? botId,
    });
  }

  int _getRetryDelay(int statusCode) {
    if (statusCode == 429) return 30;
    if (statusCode == 500 || statusCode == 503) return 15;
    if (statusCode == 422) return -1;
    if (statusCode == 400 || statusCode == 401) return 10;
    return 15;
  }

  bool hasActiveTask(String botId) {
    return _tasks.values.any(
          (t) => t.botId == botId && t.isActive,
        ) ||
        _summaryTasks.containsKey('summary_$botId');
  }

  void cancel(String taskId) {
    _tasks[taskId]?.cancel();
    _tasks.remove(taskId);
  }

  void cancelAllForBot(String botId) {
    final toRemove = _tasks.values
        .where((t) => t.botId == botId)
        .map((t) => t.taskId)
        .toList();
    for (final id in toRemove) {
      _tasks[id]?.cancel();
      _tasks.remove(id);
    }
    _summaryTasks['summary_$botId']?.cancel();
    _summaryTasks.remove('summary_$botId');
  }

  void dispose() {
    for (final task in _tasks.values) {
      task.cancel();
    }
    _tasks.clear();
    for (final task in _summaryTasks.values) {
      task.cancel();
    }
    _summaryTasks.clear();
    _controller.close();
  }
}
