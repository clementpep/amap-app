import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/auth_repository.dart';
import '../providers/auth_provider.dart';
import '../../../core/widgets/common_widgets.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _amapNameCtrl = TextEditingController();
  bool _loading = false;
  bool _profileLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final profile = await ref.read(authRepositoryProvider).getProfile(user.id);
    if (mounted && profile != null) {
      _fullNameCtrl.text = profile['full_name'] ?? '';
      _amapNameCtrl.text = profile['amap_name'] ?? '';
      setState(() => _profileLoaded = true);
    }
  }

  Future<void> _save() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile(
        userId: user.id,
        fullName: _fullNameCtrl.text.trim(),
        amapName: _amapNameCtrl.text.trim(),
      );
      if (mounted) showSuccessSnackbar(context, 'Profil mis à jour');
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Erreur lors de la mise à jour');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Se déconnecter'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Déconnecter', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _amapNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: const Text('Sauvegarder', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: !_profileLoaded
          ? const LoadingWidget(message: 'Chargement du profil...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    Center(
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: const Color(0xFFE8F5E9),
                        child: Text(
                          _fullNameCtrl.text.isNotEmpty
                              ? _fullNameCtrl.text[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (user != null)
                      Text(
                        user.email ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Color(0xFF546E7A),
                        ),
                      ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _fullNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nom complet',
                        prefixIcon: Icon(Icons.person_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amapNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom de l\'AMAP',
                        prefixIcon: Icon(Icons.nature_people_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Nom AMAP requis' : null,
                    ),
                    const SizedBox(height: 48),
                    OutlinedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text(
                        'Se déconnecter',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
