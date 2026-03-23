enum ChallengeType { permanent, weekly, monthly }

class ChallengeDefinition {
  const ChallengeDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.xpReward,
    required this.type,
  });

  final String id;
  final String title;
  final String description;
  final int xpReward;
  final ChallengeType type;

  /// Whether progress on this challenge is repeatable (weekly / monthly reset).
  bool get isRepeating => type != ChallengeType.permanent;
}

// ---------------------------------------------------------------------------
// All challenge definitions — strings in German
// ---------------------------------------------------------------------------

const List<ChallengeDefinition> kAllChallenges = [
  // ── Dauerhaft (einmalig) ─────────────────────────────────────────────────
  ChallengeDefinition(
    id: 'first_position',
    title: 'Erste Schritte',
    description: 'Erste Position in irgendeiner Kategorie erfassen',
    xpReward: 100,
    type: ChallengeType.permanent,
  ),
  ChallengeDefinition(
    id: 'three_categories',
    title: 'Es wird ernst',
    description: 'Positionen in 3 verschiedenen Kategorien erfassen',
    xpReward: 200,
    type: ChallengeType.permanent,
  ),
  ChallengeDefinition(
    id: 'all_categories',
    title: 'Voll diversifiziert',
    description: 'In allen 6 Kategorien aktiv sein',
    xpReward: 500,
    type: ChallengeType.permanent,
  ),
  ChallengeDefinition(
    id: 'debt_free',
    title: 'Schuldenfrei',
    description: 'Keine aktiven Schulden',
    xpReward: 800,
    type: ChallengeType.permanent,
  ),
  ChallengeDefinition(
    id: 'five_figures',
    title: 'Fünfstellig',
    description: '€10.000 Nettovermögen erreicht',
    xpReward: 300,
    type: ChallengeType.permanent,
  ),
  ChallengeDefinition(
    id: 'six_figures',
    title: 'Sechsstellig',
    description: '€100.000 Nettovermögen erreicht',
    xpReward: 1000,
    type: ChallengeType.permanent,
  ),
  ChallengeDefinition(
    id: 'millionaire',
    title: 'Millionär',
    description: '€1.000.000 Nettovermögen erreicht',
    xpReward: 3000,
    type: ChallengeType.permanent,
  ),
  ChallengeDefinition(
    id: 'festgeld_matured',
    title: 'Erste Fälligkeit',
    description: 'Ein Festgeld ist fällig geworden',
    xpReward: 200,
    type: ChallengeType.permanent,
  ),
  ChallengeDefinition(
    id: 'three_month_growth',
    title: 'Aufwärtstrend',
    description: 'Nettovermögen 3 Monate in Folge gestiegen',
    xpReward: 400,
    type: ChallengeType.permanent,
  ),

  // ── Wöchentlich ──────────────────────────────────────────────────────────
  ChallengeDefinition(
    id: 'weekly_refresh',
    title: 'Wöchentlicher Check',
    description: 'App mindestens einmal diese Woche aktualisiert',
    xpReward: 50,
    type: ChallengeType.weekly,
  ),

  // ── Monatlich ────────────────────────────────────────────────────────────
  ChallengeDefinition(
    id: 'monthly_update',
    title: 'Monatliches Update',
    description: 'Mindestens eine Position diesen Monat aktualisiert',
    xpReward: 75,
    type: ChallengeType.monthly,
  ),
  ChallengeDefinition(
    id: 'positive_month',
    title: 'Positiver Monat',
    description: 'Nettovermögen höher als letzten Monat',
    xpReward: 75,
    type: ChallengeType.monthly,
  ),
];

/// Fast lookup by challenge ID.
final Map<String, ChallengeDefinition> kChallengeById = {
  for (final c in kAllChallenges) c.id: c,
};

List<ChallengeDefinition> get kPermanentChallenges =>
    kAllChallenges.where((c) => c.type == ChallengeType.permanent).toList();

List<ChallengeDefinition> get kWeeklyChallenges =>
    kAllChallenges.where((c) => c.type == ChallengeType.weekly).toList();

List<ChallengeDefinition> get kMonthlyChallenges =>
    kAllChallenges.where((c) => c.type == ChallengeType.monthly).toList();
