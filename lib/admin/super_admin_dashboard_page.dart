import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'super_admin_controller.dart';

class SuperAdminDashboardPage extends GetView<SuperAdminController> {
  const SuperAdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFEAF8EF),
    appBar: AppBar(title: const Text('PlayPlace Super Admin'), actions: [
      Obx(() => IconButton(onPressed: controller.isLoading.value ? null : controller.refreshAll,
        icon: const Icon(Icons.refresh))),
      IconButton(onPressed: controller.signOut, icon: const Icon(Icons.logout)),
    ]),
    body: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFF2FBF5), Color(0xFFE2F4E8), Color(0xFFD5EEDD)])),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100),
        child: Obx(() {
          if (controller.isLoading.value && controller.packages.isEmpty &&
              controller.admins.isEmpty && controller.invitations.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF328B55)));
          }
          return ListView(padding: const EdgeInsets.all(22), children: [
            const Text('Platform control center', style: TextStyle(fontSize: 28,
              fontWeight: FontWeight.w800, color: Color(0xFF17452D))),
            const Text('Approve administrators and manage subscription plans.',
              style: TextStyle(color: Color(0xFF64816D))),
            if (controller.loadError.isNotEmpty)
              Text(controller.loadError.value, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 22),
            Row(children: [
              const Expanded(child: Text('Subscription packages',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
              FilledButton.icon(onPressed: () => Get.dialog(const _PackageDialog(),
                barrierDismissible: false), icon: const Icon(Icons.add), label: const Text('Create package')),
            ]),
            const SizedBox(height: 10),
            if (controller.packages.isEmpty) const _Panel(child: Text('No packages yet. Create your first subscription package.')),
            for (final item in controller.packages) Padding(padding: const EdgeInsets.only(bottom: 8),
              child: _Panel(child: ListTile(contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(backgroundColor: Color(0xFFDDF2E3),
                  child: Icon(Icons.card_membership, color: Color(0xFF328B55))),
                title: Text(item.data()['name']?.toString() ?? 'Package',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('₹${item.data()['price'] ?? 0} · ${item.data()['durationDays'] ?? 30} days · ${item.data()['maxBuses'] ?? 1} buses · ${item.data()['active'] == true ? 'Active' : 'Disabled'}'),
                trailing: Wrap(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(tooltip: 'Edit', onPressed: () => Get.dialog(_PackageDialog(item: item),
                    barrierDismissible: false), icon: const Icon(Icons.edit_outlined)),
                  IconButton(tooltip: 'Enable/disable', onPressed: () => controller.togglePackage(item),
                    icon: Icon(item.data()['active'] == true ? Icons.pause_circle_outline : Icons.play_circle_outline)),
                  IconButton(tooltip: 'Delete', onPressed: () => Get.dialog(AlertDialog(
                    title: const Text('Delete package?'),
                    content: Text('Delete "${item.data()['name'] ?? 'this package'}"?'),
                    actions: [TextButton(onPressed: Get.back, child: const Text('Cancel')),
                      FilledButton(onPressed: () { Get.back(); controller.deletePackage(item); },
                        child: const Text('Delete'))])),
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
                ])))),
            const SizedBox(height: 24),
            const Text('Administrator accounts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (controller.admins.isEmpty) const _Panel(child: Text('No administrator accounts yet.')),
            for (final admin in controller.admins) Padding(padding: const EdgeInsets.only(bottom: 8),
              child: _AdminTile(admin: admin)),
            const SizedBox(height: 24),
            const Text('Pending invitations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (controller.invitations.isEmpty) const _Panel(child: Text('No pending administrator invitations.')),
            if (controller.invitations.isNotEmpty) _Panel(child: Column(children: [
              for (final invite in controller.invitations) ListTile(contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mail_outline, color: Color(0xFF328B55)),
                title: Text(invite.id), subtitle: const Text('Waiting for the invited user to register'),
                trailing: IconButton(onPressed: () => controller.deleteInvitation(invite),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent))),
            ])),
          ]);
        }),
      )),
    ),
  );
}

class _AdminTile extends GetView<SuperAdminController> {
  const _AdminTile({required this.admin});
  final QueryDocumentSnapshot<Map<String, dynamic>> admin;

  @override
  Widget build(BuildContext context) {
    final data = admin.data();
    final subscription = data['subscription'] is Map
      ? Map<String, dynamic>.from(data['subscription']) : <String, dynamic>{};
    final pending = data['approvalStatus'] == 'pending';
    return _Panel(child: ListTile(contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Icon(data['active'] == true ? Icons.person : Icons.person_off_outlined)),
      title: Text(data['email']?.toString() ?? admin.id),
      subtitle: Text('Status: ${data['active'] == true ? 'Active' : (pending ? 'Awaiting approval' : (data['approvalStatus'] == 'rejected' ? 'Rejected' : 'Disabled'))} · Plan: ${subscription['packageName'] ?? 'No plan'}'),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'approve') await controller.approveAdmin(admin, true);
          if (value == 'reject') await controller.approveAdmin(admin, false);
          if (value == 'toggle') await controller.toggleAdmin(admin);
          if (value == 'assign') {
            final plans = await controller.activePackages();
            Get.dialog(_AssignDialog(admin: admin, packages: plans), barrierDismissible: false);
          }
        },
        itemBuilder: (_) => [
          if (pending) const PopupMenuItem(value: 'approve', child: Text('Approve admin')),
          if (pending) const PopupMenuItem(value: 'reject', child: Text('Reject admin')),
          if (!pending) PopupMenuItem(value: 'toggle', child: Text(data['active'] == true ? 'Disable admin' : 'Enable admin')),
          const PopupMenuItem(value: 'assign', child: Text('Assign subscription')),
        ],
      ),
    ));
  }
}

class _PackageDialog extends StatefulWidget {
  const _PackageDialog({this.item});
  final QueryDocumentSnapshot<Map<String, dynamic>>? item;
  @override State<_PackageDialog> createState() => _PackageDialogState();
}

class _PackageDialogState extends State<_PackageDialog> {
  late final name = TextEditingController(text: widget.item?.data()['name']?.toString() ?? '');
  late final price = TextEditingController(text: widget.item?.data()['price']?.toString() ?? '');
  late final days = TextEditingController(text: widget.item?.data()['durationDays']?.toString() ?? '30');
  late final buses = TextEditingController(text: widget.item?.data()['maxBuses']?.toString() ?? '1');
  late final features = TextEditingController(text: (widget.item?.data()['features'] as List?)?.join(', ') ?? '');
  bool active = true, saving = false;
  @override void initState() { super.initState(); active = widget.item?.data()['active'] != false; }
  @override void dispose() { name.dispose(); price.dispose(); days.dispose(); buses.dispose(); features.dispose(); super.dispose(); }

  Future<void> save() async {
    final p = double.tryParse(price.text.trim()), d = int.tryParse(days.text.trim()), b = int.tryParse(buses.text.trim());
    if (name.text.trim().isEmpty || p == null || p < 0 || d == null || d < 1 || b == null || b < 1) {
      Get.snackbar('Check package details', 'Enter a name, valid price, duration and bus limit.'); return;
    }
    setState(() => saving = true);
    final ok = await Get.find<SuperAdminController>().savePackage(id: widget.item?.id,
      name: name.text, price: p, durationDays: d, maxBuses: b,
      features: features.text.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList(),
      active: active);
    if (mounted) { setState(() => saving = false); if (ok) Get.back(); }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item == null ? 'Create subscription package' : 'Edit subscription package'),
    content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Package name')),
      TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Price (₹)')),
      TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (days)')),
      TextField(controller: buses, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Maximum buses')),
      TextField(controller: features, maxLines: 2, decoration: const InputDecoration(labelText: 'Features (comma separated)')),
      SwitchListTile(value: active, onChanged: (v) => setState(() => active = v), title: const Text('Package active')),
    ]))),
    actions: [
      TextButton(onPressed: saving ? null : Get.back, child: const Text('Cancel')),
      FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Saving…' : 'Save package')),
    ],
  );
}

class _AssignDialog extends StatefulWidget {
  const _AssignDialog({required this.admin, required this.packages});
  final QueryDocumentSnapshot<Map<String, dynamic>> admin;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> packages;
  @override State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  String? selected; bool saving = false;
  Future<void> save() async {
    if (selected == null) return;
    setState(() => saving = true);
    final item = widget.packages.firstWhere((p) => p.id == selected);
    final ok = await Get.find<SuperAdminController>().assignPackage(widget.admin, item);
    if (mounted) { setState(() => saving = false); if (ok) Get.back(); }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Assign subscription'),
    content: SizedBox(width: 360, child: widget.packages.isEmpty
      ? const Text('Create an active package first.')
      : DropdownButtonFormField<String>(value: selected,
        decoration: const InputDecoration(labelText: 'Package'),
        items: [for (final p in widget.packages) DropdownMenuItem(value: p.id,
          child: Text('${p.data()['name']} · ₹${p.data()['price']}'))],
        onChanged: saving ? null : (v) => setState(() => selected = v))),
    actions: [
      TextButton(onPressed: saving ? null : Get.back, child: const Text('Cancel')),
      FilledButton(onPressed: saving || widget.packages.isEmpty ? null : save,
        child: Text(saving ? 'Assigning…' : 'Assign')),
    ],
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .78),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF80B996).withValues(alpha: .3))),
    child: child);
}
