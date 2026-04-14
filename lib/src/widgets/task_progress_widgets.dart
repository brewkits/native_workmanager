import 'package:flutter/material.dart';
import '../events.dart';
import '../task_handler.dart';

/// A widget that builds itself based on the latest [TaskProgress] of a task.
///
/// Use this to easily reactive-ly update your UI as a background task
/// reports its progress, speed, and ETA.
///
/// This is a high-level wrapper around [StreamBuilder] that automatically
/// handles the [TaskHandler.progress] stream.
///
/// ## Example
///
/// ```dart
/// TaskProgressBuilder(
///   handler: myTaskHandler,
///   builder: (context, progress) {
///     if (progress == null) return Text('Waiting for progress...');
///     return LinearProgressIndicator(value: progress.progress / 100);
///   },
/// )
/// ```
class TaskProgressBuilder extends StatelessWidget {
  /// The handler for the task to track.
  final TaskHandler handler;

  /// The builder function that is called every time a new progress update arrives.
  ///
  /// [progress] is the latest update, or null if no update has arrived yet.
  final Widget Function(BuildContext context, TaskProgress? progress) builder;

  /// An optional initial progress value to use before the first update arrives.
  final TaskProgress? initialProgress;

  const TaskProgressBuilder({
    super.key,
    required this.handler,
    required this.builder,
    this.initialProgress,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TaskProgress>(
      stream: handler.progress,
      initialData: initialProgress,
      builder: (context, snapshot) {
        return builder(context, snapshot.data);
      },
    );
  }
}

/// A pre-styled Material 3 card that displays the progress of a background task.
///
/// Displays:
/// - A title and optional subtitle/message.
/// - A progress bar.
/// - Percentage, network speed, and time remaining (ETA).
/// - Current step information (if available).
///
/// Perfect for download managers, file processing screens, or any
/// task-heavy application.
class TaskProgressCard extends StatelessWidget {
  /// The handler for the task to display.
  final TaskHandler handler;

  /// An optional title for the card. Defaults to the task ID.
  final String? title;

  /// An optional icon to display in the header.
  final Widget? icon;

  /// Whether to show the network speed and time remaining.
  final bool showMetrics;

  /// Whether to show the current message from the task.
  final bool showMessage;

  /// Optional padding for the card content.
  final EdgeInsetsGeometry padding;

  const TaskProgressCard({
    super.key,
    required this.handler,
    this.title,
    this.icon,
    this.showMetrics = true,
    this.showMessage = true,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TaskProgressBuilder(
      handler: handler,
      builder: (context, progress) {
        final p = progress;
        final pct = (p?.progress ?? 0) / 100.0;
        final hasMetrics = p?.networkSpeed != null || p?.timeRemaining != null;
        final hasSteps = p?.currentStep != null && p?.totalSteps != null;

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    if (icon != null) ...[
                      icon!,
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title ?? handler.taskId,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (showMessage && p?.message != null)
                            Text(
                              p!.message!,
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(pct * 100).toInt()}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Progress Bar
                LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),

                // Footer Metrics
                if (showMetrics && (hasMetrics || hasSteps)) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (hasSteps) ...[
                        Icon(Icons.layers_outlined,
                            size: 14, color: theme.hintColor),
                        const SizedBox(width: 4),
                        Text(
                          'Step ${p!.currentStep}/${p.totalSteps}',
                          style: theme.textTheme.labelSmall,
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (p?.networkSpeed != null) ...[
                        Icon(Icons.speed, size: 14, color: theme.hintColor),
                        const SizedBox(width: 4),
                        Text(
                          p!.networkSpeedHuman,
                          style: theme.textTheme.labelSmall,
                        ),
                        const Spacer(),
                      ],
                      if (p?.timeRemaining != null) ...[
                        Icon(Icons.timer_outlined,
                            size: 14, color: theme.hintColor),
                        const SizedBox(width: 4),
                        Text(
                          p!.timeRemainingHuman,
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
