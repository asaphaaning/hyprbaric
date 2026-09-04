import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';

const List<SessionAction> _actions = <SessionAction>[
  SessionAction.lock,
  SessionAction.logout,
  SessionAction.restart,
  SessionAction.shutdown,
];

@UseCase(name: 'Actions', type: SessionLauncherCard, path: '[Widgets]/Session')
Widget buildSessionActions(BuildContext context) {
  return const _SessionActionsStory();
}

@UseCase(
  name: 'Confirmation',
  type: SessionLauncherCard,
  path: '[Widgets]/Session',
)
Widget buildSessionConfirmation(BuildContext context) {
  return const _SessionConfirmationStory();
}

@UseCase(
  name: 'Interactive',
  type: SessionLauncherCard,
  path: '[Widgets]/Session',
)
Widget buildInteractiveSession(BuildContext context) {
  return const _InteractiveSessionStory();
}

class _SessionActionsStory extends StatelessWidget {
  const _SessionActionsStory();

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: SessionLauncherCard(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        actions: _actions,
        selectedAction: SessionAction.lock,
        confirmingAction: null,
        confirmChoice: SessionConfirmChoice.confirm,
        errorMessage: null,
        onActionTap: _noopAction,
        onCancel: _noop,
        onConfirm: _noop,
      ),
    );
  }
}

class _SessionConfirmationStory extends StatelessWidget {
  const _SessionConfirmationStory();

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: SessionLauncherCard(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        actions: _actions,
        selectedAction: SessionAction.shutdown,
        confirmingAction: SessionAction.shutdown,
        confirmChoice: SessionConfirmChoice.confirm,
        errorMessage: null,
        onActionTap: _noopAction,
        onCancel: _noop,
        onConfirm: _noop,
      ),
    );
  }
}

class _InteractiveSessionStory extends StatefulWidget {
  const _InteractiveSessionStory();

  @override
  State<_InteractiveSessionStory> createState() =>
      _InteractiveSessionStoryState();
}

class _InteractiveSessionStoryState extends State<_InteractiveSessionStory> {
  SessionAction? confirmingAction;
  SessionConfirmChoice confirmChoice = SessionConfirmChoice.confirm;
  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: SessionLauncherCard(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        actions: _actions,
        selectedAction: confirmingAction ?? SessionAction.lock,
        confirmingAction: confirmingAction,
        confirmChoice: confirmChoice,
        errorMessage: errorMessage,
        onActionTap: (SessionAction action) {
          setState(() {
            confirmingAction = action;
            confirmChoice = SessionConfirmChoice.confirm;
            errorMessage = null;
          });
        },
        onCancel: () {
          setState(() {
            confirmingAction = null;
            confirmChoice = SessionConfirmChoice.confirm;
            errorMessage = null;
          });
        },
        onConfirm: () {
          setState(() {
            confirmingAction = null;
            errorMessage = 'Preview only — no session action was run.';
          });
        },
      ),
    );
  }
}

void _noopAction(SessionAction _) {}

void _noop() {}
