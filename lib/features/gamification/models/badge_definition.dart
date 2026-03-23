import 'gamification_tier.dart';

enum BadgeCategory {
  vermoegen,
  diversifikation,
  schuldenabbau,
  dabeiSeit,
  festgeld,
  krypto,
  etfAktien,
  konsequenz,
  sachwerte,
}

extension BadgeCategoryX on BadgeCategory {
  String get label {
    switch (this) {
      case BadgeCategory.vermoegen:
        return 'Vermögen';
      case BadgeCategory.diversifikation:
        return 'Diversifikation';
      case BadgeCategory.schuldenabbau:
        return 'Schuldenabbau';
      case BadgeCategory.dabeiSeit:
        return 'Dabei seit ...';
      case BadgeCategory.festgeld:
        return 'Festgeld';
      case BadgeCategory.krypto:
        return 'Krypto';
      case BadgeCategory.etfAktien:
        return 'ETF & Aktien';
      case BadgeCategory.konsequenz:
        return 'Konsequenz';
      case BadgeCategory.sachwerte:
        return 'Sachwerte';
    }
  }

  String get emoji {
    switch (this) {
      case BadgeCategory.vermoegen:
        return '🏆';
      case BadgeCategory.diversifikation:
        return '🔀';
      case BadgeCategory.schuldenabbau:
        return '💪';
      case BadgeCategory.dabeiSeit:
        return '⏳';
      case BadgeCategory.festgeld:
        return '🐷';
      case BadgeCategory.krypto:
        return '₿';
      case BadgeCategory.etfAktien:
        return '📈';
      case BadgeCategory.konsequenz:
        return '🔄';
      case BadgeCategory.sachwerte:
        return '🥇';
    }
  }
}

class BadgeDefinition {
  const BadgeDefinition({
    required this.id,
    required this.missionId,
    required this.category,
    required this.tier,
    required this.name,
    required this.description,
    required this.xpReward,
  });

  final String id;
  final String missionId;
  final BadgeCategory category;
  final GamificationTier tier;
  final String name;
  final String description;
  final int xpReward;
}

class BadgeMission {
  const BadgeMission({
    required this.id,
    required this.category,
    required this.tiers,
  });

  final String id;
  final BadgeCategory category;
  final List<BadgeDefinition> tiers; // always 4: [bronze, silver, gold, diamond]

  String get name => tiers.first.name;

  String get missionLabel {
    return tiers.first.name;
  }
}

// ---------------------------------------------------------------------------
// All 96 badge definitions (24 missions × 4 tiers) — strings in German
// ---------------------------------------------------------------------------

const List<BadgeDefinition> kAllBadges = [
  // ── 🏆 Vermögen ──────────────────────────────────────────────────────────────
  // Mission: w_net — Nettovermögen
  BadgeDefinition(id: 'w_net_bronze', missionId: 'w_net', category: BadgeCategory.vermoegen, tier: GamificationTier.bronze, name: 'Erster Tausender', description: 'Nettovermögen von €1.000 erreicht', xpReward: 150),
  BadgeDefinition(id: 'w_net_silver', missionId: 'w_net', category: BadgeCategory.vermoegen, tier: GamificationTier.silver, name: 'Fünftausend', description: '€5.000 Nettovermögen erreicht', xpReward: 350),
  BadgeDefinition(id: 'w_net_gold', missionId: 'w_net', category: BadgeCategory.vermoegen, tier: GamificationTier.gold, name: 'Dreißigtausend', description: '€30.000 Nettovermögen erreicht', xpReward: 700),
  BadgeDefinition(id: 'w_net_diamond', missionId: 'w_net', category: BadgeCategory.vermoegen, tier: GamificationTier.diamond, name: 'Hundert K', description: '€100.000 Nettovermögen erreicht', xpReward: 2000),

  // Mission: w_invest — Investiert
  BadgeDefinition(id: 'w_invest_bronze', missionId: 'w_invest', category: BadgeCategory.vermoegen, tier: GamificationTier.bronze, name: 'Investiert', description: '€500 in ETF, Krypto, Festgeld oder Sachwerte angelegt', xpReward: 150),
  BadgeDefinition(id: 'w_invest_silver', missionId: 'w_invest', category: BadgeCategory.vermoegen, tier: GamificationTier.silver, name: 'Aufbauphase', description: '€3.000 in Investments angelegt', xpReward: 350),
  BadgeDefinition(id: 'w_invest_gold', missionId: 'w_invest', category: BadgeCategory.vermoegen, tier: GamificationTier.gold, name: 'Engagiert', description: '€15.000 in Investments angelegt', xpReward: 700),
  BadgeDefinition(id: 'w_invest_diamond', missionId: 'w_invest', category: BadgeCategory.vermoegen, tier: GamificationTier.diamond, name: 'Vollanleger', description: '€50.000 in Investments angelegt', xpReward: 2000),

  // Mission: w_pos — Sammler
  BadgeDefinition(id: 'w_pos_bronze', missionId: 'w_pos', category: BadgeCategory.vermoegen, tier: GamificationTier.bronze, name: 'Erste Schritte', description: 'Erste Position erfasst', xpReward: 100),
  BadgeDefinition(id: 'w_pos_silver', missionId: 'w_pos', category: BadgeCategory.vermoegen, tier: GamificationTier.silver, name: 'Sammler', description: '5 Positionen erfasst', xpReward: 200),
  BadgeDefinition(id: 'w_pos_gold', missionId: 'w_pos', category: BadgeCategory.vermoegen, tier: GamificationTier.gold, name: 'Portfolio-Aufbauer', description: '15 Positionen erfasst', xpReward: 400),
  BadgeDefinition(id: 'w_pos_diamond', missionId: 'w_pos', category: BadgeCategory.vermoegen, tier: GamificationTier.diamond, name: 'Datenpfleger', description: '30 Positionen erfasst', xpReward: 1000),

  // ── 🔀 Diversifikation ───────────────────────────────────────────────────────
  // Mission: d_breadth — Vielfalt
  BadgeDefinition(id: 'd_breadth_bronze', missionId: 'd_breadth', category: BadgeCategory.diversifikation, tier: GamificationTier.bronze, name: 'Anfänger', description: 'In 2 Kategorien aktiv', xpReward: 100),
  BadgeDefinition(id: 'd_breadth_silver', missionId: 'd_breadth', category: BadgeCategory.diversifikation, tier: GamificationTier.silver, name: 'Gut aufgestellt', description: 'In 3 Kategorien aktiv', xpReward: 250),
  BadgeDefinition(id: 'd_breadth_gold', missionId: 'd_breadth', category: BadgeCategory.diversifikation, tier: GamificationTier.gold, name: 'Echter Diversifier', description: 'In 4 Kategorien aktiv', xpReward: 500),
  BadgeDefinition(id: 'd_breadth_diamond', missionId: 'd_breadth', category: BadgeCategory.diversifikation, tier: GamificationTier.diamond, name: 'Portfolio-Meister', description: 'In 5 Kategorien aktiv', xpReward: 1000),

  // Mission: d_balance — Ausgewogen
  BadgeDefinition(id: 'd_balance_bronze', missionId: 'd_balance', category: BadgeCategory.diversifikation, tier: GamificationTier.bronze, name: 'Basis', description: '2 Kategorien mit je mind. €500', xpReward: 150),
  BadgeDefinition(id: 'd_balance_silver', missionId: 'd_balance', category: BadgeCategory.diversifikation, tier: GamificationTier.silver, name: 'Ausgewogen', description: '3 Kategorien mit je mind. €500', xpReward: 350),
  BadgeDefinition(id: 'd_balance_gold', missionId: 'd_balance', category: BadgeCategory.diversifikation, tier: GamificationTier.gold, name: 'Solide', description: '4 Kategorien mit je mind. €500', xpReward: 700),
  BadgeDefinition(id: 'd_balance_diamond', missionId: 'd_balance', category: BadgeCategory.diversifikation, tier: GamificationTier.diamond, name: 'Ausgeglichen', description: '5 Kategorien mit je mind. €500', xpReward: 1500),

  // Mission: d_spread — Gleichgewicht
  BadgeDefinition(id: 'd_spread_bronze', missionId: 'd_spread', category: BadgeCategory.diversifikation, tier: GamificationTier.bronze, name: 'Nicht alles auf eine Karte', description: 'Größte Kategorie unter 80% des Gesamtportfolios', xpReward: 150),
  BadgeDefinition(id: 'd_spread_silver', missionId: 'd_spread', category: BadgeCategory.diversifikation, tier: GamificationTier.silver, name: 'Balanciert', description: 'Größte Kategorie unter 70% des Portfolios', xpReward: 350),
  BadgeDefinition(id: 'd_spread_gold', missionId: 'd_spread', category: BadgeCategory.diversifikation, tier: GamificationTier.gold, name: 'Diversifiziert', description: 'Größte Kategorie unter 60% des Portfolios', xpReward: 700),
  BadgeDefinition(id: 'd_spread_diamond', missionId: 'd_spread', category: BadgeCategory.diversifikation, tier: GamificationTier.diamond, name: 'Risiko-Profi', description: 'Größte Kategorie unter 50% des Portfolios', xpReward: 1500),

  // ── 💪 Schuldenabbau ─────────────────────────────────────────────────────────
  // Mission: s_paid — Abbezahlt
  BadgeDefinition(id: 's_paid_bronze', missionId: 's_paid', category: BadgeCategory.schuldenabbau, tier: GamificationTier.bronze, name: 'Erste Etappe', description: '1 Schuld vollständig abbezahlt', xpReward: 200),
  BadgeDefinition(id: 's_paid_silver', missionId: 's_paid', category: BadgeCategory.schuldenabbau, tier: GamificationTier.silver, name: 'Hartnäckig', description: '2 Schulden abbezahlt', xpReward: 400),
  BadgeDefinition(id: 's_paid_gold', missionId: 's_paid', category: BadgeCategory.schuldenabbau, tier: GamificationTier.gold, name: 'Entschlossen', description: '4 Schulden abbezahlt', xpReward: 800),
  BadgeDefinition(id: 's_paid_diamond', missionId: 's_paid', category: BadgeCategory.schuldenabbau, tier: GamificationTier.diamond, name: 'Schuldenjäger', description: '7 Schulden abbezahlt', xpReward: 2000),

  // Mission: s_free — Schuldenfrei
  BadgeDefinition(id: 's_free_bronze', missionId: 's_free', category: BadgeCategory.schuldenabbau, tier: GamificationTier.bronze, name: 'Erste Zahlung', description: 'Erste Schuld beglichen', xpReward: 200),
  BadgeDefinition(id: 's_free_silver', missionId: 's_free', category: BadgeCategory.schuldenabbau, tier: GamificationTier.silver, name: 'Schuldenfrei', description: 'Keine aktiven Schulden mehr', xpReward: 500),
  BadgeDefinition(id: 's_free_gold', missionId: 's_free', category: BadgeCategory.schuldenabbau, tier: GamificationTier.gold, name: 'Sauber', description: 'Schuldenfrei & mind. 3 Schulden abbezahlt', xpReward: 1000),
  BadgeDefinition(id: 's_free_diamond', missionId: 's_free', category: BadgeCategory.schuldenabbau, tier: GamificationTier.diamond, name: 'Dauerhaft Frei', description: 'Schuldenfrei & mind. 5 Schulden abbezahlt — oder: noch nie Schulden gehabt & 1 Monat dabei', xpReward: 2000),

  // ── ⏳ Dabei seit ... ────────────────────────────────────────────────────────
  // Mission: t_age — Treue
  BadgeDefinition(id: 't_age_bronze', missionId: 't_age', category: BadgeCategory.dabeiSeit, tier: GamificationTier.bronze, name: 'Frischer Start', description: 'App seit 2 Tagen genutzt', xpReward: 100),
  BadgeDefinition(id: 't_age_silver', missionId: 't_age', category: BadgeCategory.dabeiSeit, tier: GamificationTier.silver, name: 'Dabei bleiben', description: 'App seit 1 Monat genutzt', xpReward: 300),
  BadgeDefinition(id: 't_age_gold', missionId: 't_age', category: BadgeCategory.dabeiSeit, tier: GamificationTier.gold, name: 'Ernsthaft dabei', description: 'App seit 3 Monaten genutzt', xpReward: 700),
  BadgeDefinition(id: 't_age_diamond', missionId: 't_age', category: BadgeCategory.dabeiSeit, tier: GamificationTier.diamond, name: 'Langstrecke', description: 'App seit 1 Jahr genutzt', xpReward: 1500),

  // Mission: t_xp — XP-Sammler
  BadgeDefinition(id: 't_xp_bronze', missionId: 't_xp', category: BadgeCategory.dabeiSeit, tier: GamificationTier.bronze, name: 'XP-Starter', description: '200 XP gesammelt', xpReward: 50),
  BadgeDefinition(id: 't_xp_silver', missionId: 't_xp', category: BadgeCategory.dabeiSeit, tier: GamificationTier.silver, name: 'XP-Sammler', description: '800 XP gesammelt', xpReward: 150),
  BadgeDefinition(id: 't_xp_gold', missionId: 't_xp', category: BadgeCategory.dabeiSeit, tier: GamificationTier.gold, name: 'XP-Profi', description: '3.000 XP gesammelt', xpReward: 400),
  BadgeDefinition(id: 't_xp_diamond', missionId: 't_xp', category: BadgeCategory.dabeiSeit, tier: GamificationTier.diamond, name: 'XP-Legende', description: '10.000 XP gesammelt', xpReward: 1000),

  // Mission: t_level — Aufsteiger
  BadgeDefinition(id: 't_level_bronze', missionId: 't_level', category: BadgeCategory.dabeiSeit, tier: GamificationTier.bronze, name: 'Aufsteiger', description: 'Level 3 erreicht', xpReward: 100),
  BadgeDefinition(id: 't_level_silver', missionId: 't_level', category: BadgeCategory.dabeiSeit, tier: GamificationTier.silver, name: 'Erfahren', description: 'Level 8 erreicht', xpReward: 250),
  BadgeDefinition(id: 't_level_gold', missionId: 't_level', category: BadgeCategory.dabeiSeit, tier: GamificationTier.gold, name: 'Veteran', description: 'Level 20 erreicht', xpReward: 600),
  BadgeDefinition(id: 't_level_diamond', missionId: 't_level', category: BadgeCategory.dabeiSeit, tier: GamificationTier.diamond, name: 'Elite', description: 'Level 50 erreicht', xpReward: 1500),

  // ── 🐷 Festgeld ──────────────────────────────────────────────────────────────
  // Mission: fg_count — Anleger
  BadgeDefinition(id: 'fg_count_bronze', missionId: 'fg_count', category: BadgeCategory.festgeld, tier: GamificationTier.bronze, name: 'Erste Anlage', description: 'Erstes Festgeld erstellt', xpReward: 150),
  BadgeDefinition(id: 'fg_count_silver', missionId: 'fg_count', category: BadgeCategory.festgeld, tier: GamificationTier.silver, name: 'Sammler', description: '2 aktive Festgelder', xpReward: 300),
  BadgeDefinition(id: 'fg_count_gold', missionId: 'fg_count', category: BadgeCategory.festgeld, tier: GamificationTier.gold, name: 'Festgeld-Fan', description: '3 aktive Festgelder', xpReward: 600),
  BadgeDefinition(id: 'fg_count_diamond', missionId: 'fg_count', category: BadgeCategory.festgeld, tier: GamificationTier.diamond, name: 'Festgeld-König', description: '5 aktive Festgelder', xpReward: 1500),

  // Mission: fg_vol — Volumen
  BadgeDefinition(id: 'fg_vol_bronze', missionId: 'fg_vol', category: BadgeCategory.festgeld, tier: GamificationTier.bronze, name: 'Erste Zinsen', description: '€500 in Festgeld angelegt', xpReward: 150),
  BadgeDefinition(id: 'fg_vol_silver', missionId: 'fg_vol', category: BadgeCategory.festgeld, tier: GamificationTier.silver, name: 'Aufgebaut', description: '€2.000 in Festgeld', xpReward: 350),
  BadgeDefinition(id: 'fg_vol_gold', missionId: 'fg_vol', category: BadgeCategory.festgeld, tier: GamificationTier.gold, name: 'Sicher & Stetig', description: '€10.000 in Festgeld', xpReward: 700),
  BadgeDefinition(id: 'fg_vol_diamond', missionId: 'fg_vol', category: BadgeCategory.festgeld, tier: GamificationTier.diamond, name: 'Festgeld-Profi', description: '€30.000 in Festgeld', xpReward: 1500),

  // Mission: fg_mature — Geduldig
  BadgeDefinition(id: 'fg_mature_bronze', missionId: 'fg_mature', category: BadgeCategory.festgeld, tier: GamificationTier.bronze, name: 'Erste Fälligkeit', description: '1 Festgeld ausgezahlt', xpReward: 150),
  BadgeDefinition(id: 'fg_mature_silver', missionId: 'fg_mature', category: BadgeCategory.festgeld, tier: GamificationTier.silver, name: 'Geduldig', description: '2 Festgelder ausgezahlt', xpReward: 350),
  BadgeDefinition(id: 'fg_mature_gold', missionId: 'fg_mature', category: BadgeCategory.festgeld, tier: GamificationTier.gold, name: 'Langfristdenker', description: '4 Festgelder ausgezahlt', xpReward: 700),
  BadgeDefinition(id: 'fg_mature_diamond', missionId: 'fg_mature', category: BadgeCategory.festgeld, tier: GamificationTier.diamond, name: 'Zinsjäger', description: '8 Festgelder ausgezahlt', xpReward: 1500),

  // ── ₿ Krypto ─────────────────────────────────────────────────────────────────
  // Mission: cr_count — Einstieg
  BadgeDefinition(id: 'cr_count_bronze', missionId: 'cr_count', category: BadgeCategory.krypto, tier: GamificationTier.bronze, name: 'Erster Token', description: 'Erste Krypto-Position erfasst', xpReward: 150),
  BadgeDefinition(id: 'cr_count_silver', missionId: 'cr_count', category: BadgeCategory.krypto, tier: GamificationTier.silver, name: 'Krypto-Fan', description: '2 Krypto-Positionen', xpReward: 300),
  BadgeDefinition(id: 'cr_count_gold', missionId: 'cr_count', category: BadgeCategory.krypto, tier: GamificationTier.gold, name: 'Multi-Coin', description: '4 Krypto-Positionen', xpReward: 600),
  BadgeDefinition(id: 'cr_count_diamond', missionId: 'cr_count', category: BadgeCategory.krypto, tier: GamificationTier.diamond, name: 'Krypto-Diversifier', description: '8 Krypto-Positionen', xpReward: 1200),

  // Mission: cr_vol — Volumen
  BadgeDefinition(id: 'cr_vol_bronze', missionId: 'cr_vol', category: BadgeCategory.krypto, tier: GamificationTier.bronze, name: 'Kleiner Einsatz', description: '€200 in Krypto', xpReward: 150),
  BadgeDefinition(id: 'cr_vol_silver', missionId: 'cr_vol', category: BadgeCategory.krypto, tier: GamificationTier.silver, name: 'HODLer', description: '€1.000 in Krypto', xpReward: 350),
  BadgeDefinition(id: 'cr_vol_gold', missionId: 'cr_vol', category: BadgeCategory.krypto, tier: GamificationTier.gold, name: 'Krypto-Investor', description: '€8.000 in Krypto', xpReward: 700),
  BadgeDefinition(id: 'cr_vol_diamond', missionId: 'cr_vol', category: BadgeCategory.krypto, tier: GamificationTier.diamond, name: 'Krypto-Wal', description: '€25.000 in Krypto', xpReward: 1500),

  // Mission: cr_ratio — HODLer %
  BadgeDefinition(id: 'cr_ratio_bronze', missionId: 'cr_ratio', category: BadgeCategory.krypto, tier: GamificationTier.bronze, name: 'Krypto-Anteil', description: 'Mind. 1% des Gesamtportfolios in Krypto', xpReward: 100),
  BadgeDefinition(id: 'cr_ratio_silver', missionId: 'cr_ratio', category: BadgeCategory.krypto, tier: GamificationTier.silver, name: 'Krypto-Gläubiger', description: 'Mind. 5% in Krypto', xpReward: 300),
  BadgeDefinition(id: 'cr_ratio_gold', missionId: 'cr_ratio', category: BadgeCategory.krypto, tier: GamificationTier.gold, name: 'Krypto-First', description: 'Mind. 15% in Krypto', xpReward: 600),
  BadgeDefinition(id: 'cr_ratio_diamond', missionId: 'cr_ratio', category: BadgeCategory.krypto, tier: GamificationTier.diamond, name: 'All-In', description: 'Mind. 30% in Krypto', xpReward: 1200),

  // ── 📈 ETF & Aktien ──────────────────────────────────────────────────────────
  // Mission: etf_count — Investor
  BadgeDefinition(id: 'etf_count_bronze', missionId: 'etf_count', category: BadgeCategory.etfAktien, tier: GamificationTier.bronze, name: 'Erste Position', description: 'Erste ETF- oder Aktienposition erfasst', xpReward: 150),
  BadgeDefinition(id: 'etf_count_silver', missionId: 'etf_count', category: BadgeCategory.etfAktien, tier: GamificationTier.silver, name: 'Aufbauphase', description: '2 ETF/Aktien-Positionen', xpReward: 300),
  BadgeDefinition(id: 'etf_count_gold', missionId: 'etf_count', category: BadgeCategory.etfAktien, tier: GamificationTier.gold, name: 'Aktiver Investor', description: '4 ETF/Aktien-Positionen', xpReward: 600),
  BadgeDefinition(id: 'etf_count_diamond', missionId: 'etf_count', category: BadgeCategory.etfAktien, tier: GamificationTier.diamond, name: 'Portfolio-Aufbauer', description: '8 ETF/Aktien-Positionen', xpReward: 1200),

  // Mission: etf_vol — Portfolio
  BadgeDefinition(id: 'etf_vol_bronze', missionId: 'etf_vol', category: BadgeCategory.etfAktien, tier: GamificationTier.bronze, name: 'Erste Investition', description: '€500 in ETFs & Aktien', xpReward: 150),
  BadgeDefinition(id: 'etf_vol_silver', missionId: 'etf_vol', category: BadgeCategory.etfAktien, tier: GamificationTier.silver, name: 'Wachstum', description: '€3.000 in ETFs & Aktien', xpReward: 350),
  BadgeDefinition(id: 'etf_vol_gold', missionId: 'etf_vol', category: BadgeCategory.etfAktien, tier: GamificationTier.gold, name: 'Marktteilnehmer', description: '€15.000 in ETFs & Aktien', xpReward: 700),
  BadgeDefinition(id: 'etf_vol_diamond', missionId: 'etf_vol', category: BadgeCategory.etfAktien, tier: GamificationTier.diamond, name: 'Index-Legende', description: '€50.000 in ETFs & Aktien', xpReward: 1500),

  // Mission: etf_ratio — Langfristdenker %
  BadgeDefinition(id: 'etf_ratio_bronze', missionId: 'etf_ratio', category: BadgeCategory.etfAktien, tier: GamificationTier.bronze, name: 'Langfristdenker', description: 'Mind. 5% des Portfolios in ETF/Aktien', xpReward: 100),
  BadgeDefinition(id: 'etf_ratio_silver', missionId: 'etf_ratio', category: BadgeCategory.etfAktien, tier: GamificationTier.silver, name: 'Börsianer', description: 'Mind. 15% in ETF/Aktien', xpReward: 300),
  BadgeDefinition(id: 'etf_ratio_gold', missionId: 'etf_ratio', category: BadgeCategory.etfAktien, tier: GamificationTier.gold, name: 'Marktstratege', description: 'Mind. 30% in ETF/Aktien', xpReward: 600),
  BadgeDefinition(id: 'etf_ratio_diamond', missionId: 'etf_ratio', category: BadgeCategory.etfAktien, tier: GamificationTier.diamond, name: 'Buy-and-Hold-Legende', description: 'Mind. 50% in ETF/Aktien', xpReward: 1200),

  // ── 🔄 Konsequenz ────────────────────────────────────────────────────────────
  // Mission: k_updates — Fleißig
  BadgeDefinition(id: 'k_updates_bronze', missionId: 'k_updates', category: BadgeCategory.konsequenz, tier: GamificationTier.bronze, name: 'Aktiv', description: '5x aktualisiert', xpReward: 100),
  BadgeDefinition(id: 'k_updates_silver', missionId: 'k_updates', category: BadgeCategory.konsequenz, tier: GamificationTier.silver, name: 'Regelmäßig', description: '15x aktualisiert', xpReward: 250),
  BadgeDefinition(id: 'k_updates_gold', missionId: 'k_updates', category: BadgeCategory.konsequenz, tier: GamificationTier.gold, name: 'Beständig', description: '40x aktualisiert', xpReward: 600),
  BadgeDefinition(id: 'k_updates_diamond', missionId: 'k_updates', category: BadgeCategory.konsequenz, tier: GamificationTier.diamond, name: 'Eisern', description: '80x aktualisiert', xpReward: 1500),

  // Mission: k_rich — Diszipliniert (positions >= 1k)
  BadgeDefinition(id: 'k_rich_bronze', missionId: 'k_rich', category: BadgeCategory.konsequenz, tier: GamificationTier.bronze, name: 'Erste Tausend', description: '1 Position mit mind. €1.000 Wert', xpReward: 100),
  BadgeDefinition(id: 'k_rich_silver', missionId: 'k_rich', category: BadgeCategory.konsequenz, tier: GamificationTier.silver, name: 'Fundiert', description: '3 Positionen mit je mind. €1.000', xpReward: 300),
  BadgeDefinition(id: 'k_rich_gold', missionId: 'k_rich', category: BadgeCategory.konsequenz, tier: GamificationTier.gold, name: 'Solide aufgestellt', description: '6 Positionen mit je mind. €1.000', xpReward: 600),
  BadgeDefinition(id: 'k_rich_diamond', missionId: 'k_rich', category: BadgeCategory.konsequenz, tier: GamificationTier.diamond, name: 'Vermögens-Profi', description: '12 Positionen mit je mind. €1.000', xpReward: 1500),

  // Mission: k_wealth — Substanz (positions >= 5k)
  BadgeDefinition(id: 'k_wealth_bronze', missionId: 'k_wealth', category: BadgeCategory.konsequenz, tier: GamificationTier.bronze, name: 'Substanz', description: '1 Position mit mind. €5.000 Wert', xpReward: 150),
  BadgeDefinition(id: 'k_wealth_silver', missionId: 'k_wealth', category: BadgeCategory.konsequenz, tier: GamificationTier.silver, name: 'Fundament', description: '2 Positionen mit je mind. €5.000', xpReward: 400),
  BadgeDefinition(id: 'k_wealth_gold', missionId: 'k_wealth', category: BadgeCategory.konsequenz, tier: GamificationTier.gold, name: 'Stark aufgestellt', description: '4 Positionen mit je mind. €5.000', xpReward: 800),
  BadgeDefinition(id: 'k_wealth_diamond', missionId: 'k_wealth', category: BadgeCategory.konsequenz, tier: GamificationTier.diamond, name: 'Vermögensbasis', description: '8 Positionen mit je mind. €5.000', xpReward: 1500),

  // ── 🥇 Sachwerte ─────────────────────────────────────────────────────────────
  // Mission: phys_count — Sachwert-Anleger
  BadgeDefinition(id: 'phys_count_bronze', missionId: 'phys_count', category: BadgeCategory.sachwerte, tier: GamificationTier.bronze, name: 'Erster Sachwert', description: '1 Sachwert erfasst', xpReward: 150),
  BadgeDefinition(id: 'phys_count_silver', missionId: 'phys_count', category: BadgeCategory.sachwerte, tier: GamificationTier.silver, name: 'Sachwert-Sammler', description: '2 Sachwerte erfasst', xpReward: 300),
  BadgeDefinition(id: 'phys_count_gold', missionId: 'phys_count', category: BadgeCategory.sachwerte, tier: GamificationTier.gold, name: 'Sachwert-Fan', description: '4 Sachwerte erfasst', xpReward: 600),
  BadgeDefinition(id: 'phys_count_diamond', missionId: 'phys_count', category: BadgeCategory.sachwerte, tier: GamificationTier.diamond, name: 'Sachwert-Profi', description: '8 Sachwerte erfasst', xpReward: 1200),

  // Mission: phys_vol — Wert
  BadgeDefinition(id: 'phys_vol_bronze', missionId: 'phys_vol', category: BadgeCategory.sachwerte, tier: GamificationTier.bronze, name: 'Erste Unze', description: '€200 in Sachwerten', xpReward: 150),
  BadgeDefinition(id: 'phys_vol_silver', missionId: 'phys_vol', category: BadgeCategory.sachwerte, tier: GamificationTier.silver, name: 'Kleine Reserve', description: '€1.000 in Sachwerten', xpReward: 350),
  BadgeDefinition(id: 'phys_vol_gold', missionId: 'phys_vol', category: BadgeCategory.sachwerte, tier: GamificationTier.gold, name: 'Wertanlage', description: '€5.000 in Sachwerten', xpReward: 700),
  BadgeDefinition(id: 'phys_vol_diamond', missionId: 'phys_vol', category: BadgeCategory.sachwerte, tier: GamificationTier.diamond, name: 'Goldreserve', description: '€20.000 in Sachwerten', xpReward: 1500),

  // Mission: phys_metals — Edelmetall
  BadgeDefinition(id: 'phys_metals_bronze', missionId: 'phys_metals', category: BadgeCategory.sachwerte, tier: GamificationTier.bronze, name: 'Edelmetall-Einsteiger', description: 'Gold- oder Silberposition erfasst', xpReward: 150),
  BadgeDefinition(id: 'phys_metals_silver', missionId: 'phys_metals', category: BadgeCategory.sachwerte, tier: GamificationTier.silver, name: 'Gold & Silber', description: 'Sowohl Gold als auch Silber im Portfolio', xpReward: 350),
  BadgeDefinition(id: 'phys_metals_gold', missionId: 'phys_metals', category: BadgeCategory.sachwerte, tier: GamificationTier.gold, name: 'Metallanleger', description: '€2.000 in Gold & Silber', xpReward: 700),
  BadgeDefinition(id: 'phys_metals_diamond', missionId: 'phys_metals', category: BadgeCategory.sachwerte, tier: GamificationTier.diamond, name: 'Edelmetall-Profi', description: '€10.000 in Gold & Silber', xpReward: 1500),
];

/// Fast lookup by badge ID.
final Map<String, BadgeDefinition> kBadgeById = {
  for (final b in kAllBadges) b.id: b,
};

/// All badges grouped by category.
Map<BadgeCategory, List<BadgeDefinition>> get kBadgesByCategory {
  final map = <BadgeCategory, List<BadgeDefinition>>{};
  for (final b in kAllBadges) {
    map.putIfAbsent(b.category, () => []).add(b);
  }
  return map;
}

/// All badges grouped by missionId. Each group has exactly 4 tiers.
Map<String, List<BadgeDefinition>> get kBadgesByMission {
  final map = <String, List<BadgeDefinition>>{};
  for (final b in kAllBadges) {
    map.putIfAbsent(b.missionId, () => []).add(b);
  }
  return map;
}

/// Missions grouped by category. Each category has exactly 3 missions.
Map<BadgeCategory, List<BadgeMission>> get kMissionsByCategory {
  final byMission = kBadgesByMission;
  final result = <BadgeCategory, List<BadgeMission>>{};
  for (final entry in byMission.entries) {
    final tiers = entry.value..sort((a, b) => a.tier.index.compareTo(b.tier.index));
    final category = tiers.first.category;
    final mission = BadgeMission(id: entry.key, category: category, tiers: tiers);
    result.putIfAbsent(category, () => []).add(mission);
  }
  return result;
}
