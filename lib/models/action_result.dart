class ActionResult {
  const ActionResult(this.ok, [this.reason = '']);

  factory ActionResult.fromMap(Map<dynamic, dynamic>? m) {
    if (m == null) return const ActionResult(false, 'no_response');
    return ActionResult(m['ok'] == true, (m['reason'] as String?) ?? '');
  }

  static const ActionResult success = ActionResult(true);

  final bool ok;
  final String reason;
}
