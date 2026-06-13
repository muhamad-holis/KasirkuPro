import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../providers/auth_provider.dart';
import '../../providers/database_provider.dart';

class KasirManagementScreen extends ConsumerWidget {
  const KasirManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final users  = ref.watch(allUsersProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.bg,
      appBar: AppBar(
        title: const Text('Kelola Kasir',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: AppColors.primary),
            onPressed: () => _showAddEdit(context, ref, null),
          ),
        ],
      ),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator(
            color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? _Empty(isDark: isDark)
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _UserCard(
                  user: list[i],
                  isDark: isDark,
                  onEdit: () => _showAddEdit(context, ref, list[i]),
                  onDelete: () => _confirmDelete(context, ref, list[i]),
                  onResetPin: () => _showResetPin(context, ref, list[i]),
                ),
              ),
      ),
    );
  }

  // ── Tambah / Edit kasir ───────────────────────────────────────────────────

  void _showAddEdit(BuildContext context, WidgetRef ref, User? user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _AddEditSheet(user: user),
      ),
    );
  }

  // ── Reset PIN ─────────────────────────────────────────────────────────────

  void _showResetPin(BuildContext context, WidgetRef ref, User user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _ResetPinSheet(user: user),
      ),
    );
  }

  // ── Hapus kasir ───────────────────────────────────────────────────────────

  void _confirmDelete(BuildContext context, WidgetRef ref, User user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Kasir',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Hapus akun "${user.name}"? Data transaksinya tetap tersimpan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(databaseProvider).usersDao
                  .softDeleteUser(user.id);
              ref.invalidate(allUsersProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Kasir dihapus'),
                  backgroundColor: AppColors.success,
                ));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

// ─── Card kasir ───────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final User user;
  final bool isDark;
  final VoidCallback onEdit, onDelete, onResetPin;
  const _UserCard({
    required this.user, required this.isDark,
    required this.onEdit, required this.onDelete,
    required this.onResetPin,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin  = user.role == 'admin';
    final roleColor = isAdmin ? AppColors.primary : AppColors.success;
    final roleLabel = isAdmin ? 'Admin' : 'Kasir';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 0.5,
        ),
      ),
      child: Row(children: [
        // Avatar
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: roleColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: roleColor),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Info
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.name,
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                )),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(roleLabel,
                    style: TextStyle(
                        fontSize: 11, color: roleColor,
                        fontWeight: FontWeight.w700)),
              ),
              if (!user.isActive) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Nonaktif',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.danger,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
          ]),
        ),

        // Menu
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded,
              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
          onSelected: (v) {
            if (v == 'edit')      onEdit();
            if (v == 'pin')       onResetPin();
            if (v == 'delete')    onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                  SizedBox(width: 8), Text('Edit nama & role'),
                ])),
            const PopupMenuItem(value: 'pin',
                child: Row(children: [
                  Icon(Icons.lock_reset_rounded, size: 18,
                      color: AppColors.warning),
                  SizedBox(width: 8), Text('Reset PIN'),
                ])),
            const PopupMenuItem(value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, size: 18,
                      color: AppColors.danger),
                  SizedBox(width: 8),
                  Text('Hapus', style: TextStyle(color: AppColors.danger)),
                ])),
          ],
        ),
      ]),
    );
  }
}

// ─── Sheet tambah / edit ──────────────────────────────────────────────────────

class _AddEditSheet extends ConsumerStatefulWidget {
  final User? user;
  const _AddEditSheet({this.user});

  @override
  ConsumerState<_AddEditSheet> createState() => _AddEditSheetState();
}

class _AddEditSheetState extends ConsumerState<_AddEditSheet> {
  final _nameCtrl = TextEditingController();
  String _pin     = '';
  String _role    = 'kasir';
  bool _saving    = false;

  bool get isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _nameCtrl.text = widget.user!.name;
      _role = widget.user!.role;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onKey(String d) {
    if (_pin.length >= 6) return;
    setState(() => _pin += d);
  }

  void _onDel() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nama tidak boleh kosong'),
          backgroundColor: AppColors.danger));
      return;
    }
    if (!isEdit && _pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PIN minimal 4 digit'),
          backgroundColor: AppColors.danger));
      return;
    }

    setState(() => _saving = true);
    final db = ref.read(databaseProvider);

    if (isEdit) {
      await db.usersDao.updateUser(UsersCompanion(
        id:   Value(widget.user!.id),
        name: Value(name),
        role: Value(_role),
      ));
    } else {
      await db.usersDao.insertUser(UsersCompanion.insert(
        name: name,
        pin:  hashPin(_pin),
        role: Value(_role),
      ));
    }

    ref.invalidate(allUsersProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppColors.darkSurface : Colors.white;
    final handle  = isDark ? AppColors.darkBorder : Colors.grey.shade300;
    final text    = isDark ? Colors.white : AppColors.textPrimary;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: handle,
                borderRadius: BorderRadius.circular(2)),
          ),
          Text(isEdit ? 'Edit Kasir' : 'Tambah Kasir',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: text)),
          const SizedBox(height: 20),

          // Nama
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Nama kasir',
              prefixIcon: const Icon(Icons.person_outline_rounded,
                  color: AppColors.primary),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),

          // Role
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Kasir', style: TextStyle(fontSize: 14)),
                  value: 'kasir',
                  groupValue: _role,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _role = v!),
                  dense: true,
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Admin', style: TextStyle(fontSize: 14)),
                  value: 'admin',
                  groupValue: _role,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _role = v!),
                  dense: true,
                ),
              ),
            ]),
          ),

          // PIN (hanya saat tambah baru)
          if (!isEdit) ...[
            const SizedBox(height: 20),
            Text('PIN (${_pin.length}/6)',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : AppColors.textSecondary)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) {
                final filled = i < _pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: filled
                          ? AppColors.primary
                          : isDark
                              ? const Color(0xFF475569)
                              : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            _MiniNumpad(onKey: _onKey, onDel: _onDel),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(isEdit ? 'Simpan Perubahan' : 'Tambah Kasir',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Sheet reset PIN ──────────────────────────────────────────────────────────

class _ResetPinSheet extends ConsumerStatefulWidget {
  final User user;
  const _ResetPinSheet({required this.user});

  @override
  ConsumerState<_ResetPinSheet> createState() => _ResetPinSheetState();
}

class _ResetPinSheetState extends ConsumerState<_ResetPinSheet> {
  String _pin  = '';
  bool _saving = false;

  void _onKey(String d) {
    if (_pin.length >= 6) return;
    setState(() => _pin += d);
  }

  void _onDel() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _save() async {
    if (_pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PIN minimal 4 digit'),
          backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _saving = true);
    await ref.read(databaseProvider).usersDao.updateUser(UsersCompanion(
      id:  Value(widget.user.id),
      pin: Value(hashPin(_pin)),
    ));
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('PIN ${widget.user.name} berhasil direset'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppColors.darkSurface : Colors.white;
    final handle  = isDark ? AppColors.darkBorder : Colors.grey.shade300;
    final text    = isDark ? Colors.white : AppColors.textPrimary;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
              color: handle, borderRadius: BorderRadius.circular(2)),
        ),
        Text('Reset PIN — ${widget.user.name}',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: text)),
        const SizedBox(height: 20),
        Text('PIN baru (${_pin.length}/6)',
            style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? const Color(0xFF94A3B8) : AppColors.textSecondary)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) {
            final filled = i < _pin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 12, height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: filled
                      ? AppColors.primary
                      : isDark
                          ? const Color(0xFF475569) : Colors.grey.shade300,
                  width: 2,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        _MiniNumpad(onKey: _onKey, onDel: _onDel),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Simpan PIN Baru',
                    style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ─── Mini numpad (untuk sheet) ────────────────────────────────────────────────

class _MiniNumpad extends StatelessWidget {
  final void Function(String) onKey;
  final VoidCallback onDel;
  const _MiniNumpad({required this.onKey, required this.onDel});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1','2','3'],
      ['4','5','6'],
      ['7','8','9'],
      ['','0','⌫'],
    ];
    return Column(
      children: rows.map((row) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: row.map((k) {
          if (k.isEmpty) return const SizedBox(width: 80, height: 52);
          return GestureDetector(
            onTap: k == '⌫' ? onDel : () => onKey(k),
            child: Container(
              width: 80, height: 52,
              alignment: Alignment.center,
              child: k == '⌫'
                  ? const Icon(Icons.backspace_outlined,
                      color: AppColors.primary, size: 20)
                  : Text(k, style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
            ),
          );
        }).toList(),
      )).toList(),
    );
  }
}

class _Empty extends StatelessWidget {
  final bool isDark;
  const _Empty({required this.isDark});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.people_outline_rounded,
          size: 64,
          color: (isDark
              ? const Color(0xFF94A3B8) : AppColors.textSecondary)
                  .withOpacity(0.4)),
      const SizedBox(height: 12),
      Text('Belum ada kasir',
          style: TextStyle(
              color: isDark
                  ? const Color(0xFF94A3B8) : AppColors.textSecondary)),
    ]),
  );
}
