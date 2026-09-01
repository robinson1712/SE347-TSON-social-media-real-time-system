import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/enums.dart';
import '../../core/models/moderation.dart';
import '../../shared/widgets/user_inline.dart';
import 'moderation_provider.dart';

class AdminReportsPage extends ConsumerStatefulWidget {
  const AdminReportsPage({super.key});

  @override
  ConsumerState<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends ConsumerState<AdminReportsPage> {
  ReportStatus? _statusFilter = ReportStatus.pending;

  @override
  Widget build(BuildContext context) {
    final filter = (
      status: _statusFilter?.toJson(),
      targetType: null,
    );
    final asyncReports = ref.watch(allReportsProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duyệt báo cáo'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Tất cả'),
                  selected: _statusFilter == null,
                  onSelected: (_) => setState(() => _statusFilter = null),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Chờ xử lý'),
                  selected: _statusFilter == ReportStatus.pending,
                  onSelected: (_) => setState(() => _statusFilter = ReportStatus.pending),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Đã xử lý'),
                  selected: _statusFilter == ReportStatus.actionTaken,
                  onSelected: (_) => setState(() => _statusFilter = ReportStatus.actionTaken),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Đã bỏ qua'),
                  selected: _statusFilter == ReportStatus.dismissed,
                  onSelected: (_) => setState(() => _statusFilter = ReportStatus.dismissed),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: asyncReports.when(
            data: (page) => page.content.isEmpty
                ? Center(child: Text('Không có báo cáo nào', style: TextStyle(color: Colors.grey.shade600)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: page.content.length,
                    itemBuilder: (context, index) => _ReportCard(report: page.content[index]),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Lỗi: $e')),
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  final Report report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(label: Text(report.targetType.name.toUpperCase())),
                const SizedBox(width: 6),
                Chip(label: Text(report.reason.label)),
                const Spacer(),
                Chip(
                  label: Text(report.status.label),
                  backgroundColor: report.status == ReportStatus.pending
                      ? Colors.orange.shade100
                      : report.status == ReportStatus.actionTaken
                          ? Colors.red.shade100
                          : Colors.grey.shade200,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Người báo cáo: '),
                UserNameText(userId: report.reporterId),
              ],
            ),
            Text('Đối tượng: ${report.targetId}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            if (report.description != null && report.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(report.description!),
              ),
            if (report.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(DateFormat('dd/MM/yyyy HH:mm').format(report.createdAt!),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ),
            if (report.status == ReportStatus.pending) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => ref.read(moderationActionsProvider).resolve(
                        report.id,
                        const ResolveReportRequest(action: ModerationAction.dismiss)),
                    child: const Text('Bỏ qua'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => ref.read(moderationActionsProvider).resolve(
                        report.id,
                        const ResolveReportRequest(action: ModerationAction.removeContent)),
                    child: const Text('Gỡ nội dung'),
                  ),
                ],
              ),
            ] else if (report.resolutionNote != null && report.resolutionNote!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Ghi chú xử lý: ${report.resolutionNote}',
                    style: const TextStyle(fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      ),
    );
  }
}
