// "Bind a card to this scene" bottom sheet. User enters an optional label,
// taps a blank NTAG, service writes `huetap://c/<uuid>` + a Text record
// with the label, then a CardBinding row is inserted into Drift.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/database.dart';
import '../../core/nfc/nfc_service.dart';
import '../../core/providers.dart';
import '../../core/theme/twilight_hearth_theme.dart';
import '../../l10n/gen/app_localizations.dart';

enum _BindState { idle, writing, done }

class BindCardSheet extends ConsumerStatefulWidget {
  const BindCardSheet({required this.bridge, required this.scene, super.key});

  final Bridge bridge;
  final Scene scene;

  @override
  ConsumerState<BindCardSheet> createState() => _BindCardSheetState();
}

class _BindCardSheetState extends ConsumerState<BindCardSheet> {
  final _labelCtrl = TextEditingController();
  final _nfc = NfcService();
  NfcWriteHandle? _handle;
  _BindState _state = _BindState.idle;
  String? _error;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _handle?.stop();
    super.dispose();
  }

  Future<void> _startBind() async {
    if (_state == _BindState.writing) return;
    final label = _labelCtrl.text.trim().isEmpty
        ? widget.scene.name
        : _labelCtrl.text.trim();
    final uuid = const Uuid().v4();

    setState(() {
      _state = _BindState.writing;
      _error = null;
    });

    _handle = await _nfc.startWrite(
      uuid: uuid,
      label: label,
      onResult: (outcome) async {
        if (!mounted) return;
        switch (outcome) {
          case NfcWriteSuccess(uuid: final u):
            final db = ref.read(databaseProvider);
            await db
                .into(db.cardBindings)
                .insertOnConflictUpdate(
                  CardBindingsCompanion.insert(
                    uuid: u,
                    label: label,
                    bridgeRowId: widget.bridge.id,
                    sceneId: widget.scene.id,
                    createdAt: DateTime.now(),
                  ),
                );
            if (!mounted) return;
            setState(() => _state = _BindState.done);
          case NfcWriteFailure(message: final m):
            setState(() {
              _error = m;
              _state = _BindState.idle;
            });
          case NfcWriteCancelled():
            setState(() => _state = _BindState.idle);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.bindCardSheetTitle,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.bindCardSceneLabel(widget.scene.name),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: TwilightHearthColors.text2,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _labelCtrl,
              enabled: _state == _BindState.idle,
              decoration: InputDecoration(
                labelText: l10n.bindCardLabelField,
                hintText: l10n.bindCardLabelHint,
                prefixIcon: const Icon(Symbols.label),
              ),
            ),
            const SizedBox(height: 20),
            switch (_state) {
              _BindState.idle => _StartBlock(
                onStart: _startBind,
                error: _error,
              ),
              _BindState.writing => const _WritingBlock(),
              _BindState.done => _DoneBlock(
                onClose: () => Navigator.pop(context),
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _StartBlock extends StatelessWidget {
  const _StartBlock({required this.onStart, required this.error});
  final VoidCallback onStart;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (error != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: TwilightHearthColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Symbols.error, color: TwilightHearthColors.danger),
                const SizedBox(width: 8),
                Expanded(child: Text(error!)),
              ],
            ),
          ),
        FilledButton.icon(
          onPressed: onStart,
          icon: const Icon(Symbols.nfc),
          label: Text(AppLocalizations.of(context)!.bindCardStartButton),
        ),
      ],
    );
  }
}

class _WritingBlock extends StatelessWidget {
  const _WritingBlock();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            gradient: TwilightHearthGradients.primary,
            shape: BoxShape.circle,
            boxShadow: TwilightHearthShadows.elev,
          ),
          child: const Icon(
            Symbols.nfc,
            color: TwilightHearthColors.cream,
            size: 48,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.bindCardWaitingTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.bindCardWaitingDescription,
          textAlign: TextAlign.center,
          style: const TextStyle(color: TwilightHearthColors.text2),
        ),
        const SizedBox(height: 16),
        const CircularProgressIndicator(),
      ],
    );
  }
}

class _DoneBlock extends StatelessWidget {
  const _DoneBlock({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: TwilightHearthColors.meadow,
            shape: BoxShape.circle,
          ),
          child: const Icon(Symbols.check, color: Colors.white, size: 44),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.bindCardSuccessTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onClose, child: Text(l10n.commonDone)),
      ],
    );
  }
}
