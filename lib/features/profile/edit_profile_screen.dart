import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/auth_controller.dart';

/// تعديل البيانات الشخصية (الاسم والقياسات).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _ageController;
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _ageController = TextEditingController(text: user?.age?.toString() ?? '');
    _weightController = TextEditingController(
      text: user?.weightKg?.toStringAsFixed(0) ?? '',
    );
    _heightController = TextEditingController(
      text: user?.heightCm?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthController>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final user = auth.user;
    if (user == null) return;

    final ok = await auth.updateProfile(
      user.copyWith(
        name: _nameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()),
        weightKg: double.tryParse(_weightController.text.trim()),
        heightCm: double.tryParse(_heightController.text.trim()),
      ),
    );
    if (!mounted) return;

    if (ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('تم حفظ بياناتك')));
      navigator.pop();
    } else {
      showAppSnack(context, auth.error ?? 'تعذّر الحفظ', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(bottom: Space.x3),
            children: <Widget>[
              const ScreenHeader(
                title: 'تعديل البيانات',
                subtitle: 'القياسات اختيارية، لكنها تجعل البرامج أدقّ',
                showBack: true,
                padding: EdgeInsets.fromLTRB(
                  Space.sm,
                  Space.sm,
                  Space.screenInset,
                  Space.xxl,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.screenInset,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    AppTextField(
                      controller: _nameController,
                      label: 'الاسم',
                      icon: Icons.person_outline_rounded,
                      isRequired: true,
                      autofillHints: const <String>[AutofillHints.name],
                      textCapitalization: TextCapitalization.words,
                      validator: Validators.name,
                    ),
                    const SizedBox(height: Space.xl),
                    AppTextField(
                      controller: _emailController,
                      label: 'البريد الإلكتروني',
                      icon: Icons.alternate_email_rounded,
                      readOnly: true,
                      helper: 'لتغيير بريدك راسل الدعم الفني.',
                    ),
                    const SizedBox(height: Space.xl),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: AppTextField(
                            controller: _ageController,
                            label: 'العمر',
                            hint: '٢٥',
                            keyboardType: TextInputType.number,
                            validator: (v) => Validators.optionalNumber(
                              v,
                              min: 10,
                              max: 90,
                              label: 'العمر',
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: AppTextField(
                            controller: _weightController,
                            label: 'الوزن (كجم)',
                            hint: '٧٥',
                            keyboardType: TextInputType.number,
                            validator: (v) => Validators.optionalNumber(
                              v,
                              min: 30,
                              max: 250,
                              label: 'الوزن',
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: AppTextField(
                            controller: _heightController,
                            label: 'الطول (سم)',
                            hint: '١٧٥',
                            keyboardType: TextInputType.number,
                            validator: (v) => Validators.optionalNumber(
                              v,
                              min: 100,
                              max: 230,
                              label: 'الطول',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.x3),
                    AppButton.primary(
                      label: 'حفظ التعديلات',
                      isLoading: auth.isBusy,
                      onPressed: auth.isBusy ? null : _save,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
