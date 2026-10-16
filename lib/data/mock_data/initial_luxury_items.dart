import '../models/luxury_item.dart';

class InitialLuxuryItems {
  static List<LuxuryItem> getItems() {
    return [
      // --- EINSTIEG & LIFESTYLE (Erschwinglich) ---
      LuxuryItem(
        id: 'life_espresso',
        name: 'Italienische Barista Espressomaschine',
        category: LuxuryCategory.lifestyle,
        price: 180.0,
        icon: '☕',
        description: 'Frischer Siebträger-Espresso für durchgezockte Börsen-Nächte.',
        prestigePoints: 3,
      ),
      LuxuryItem(
        id: 'life_shirt',
        name: 'Maßgeschneidertes Designer-Hemd',
        category: LuxuryCategory.lifestyle,
        price: 350.0,
        icon: '👔',
        description: 'Italienische Baumwolle mit deinen Initialen am Ärmel.',
        prestigePoints: 6,
      ),
      LuxuryItem(
        id: 'life_pen',
        name: 'Montblanc Meisterstück Füllfederhalter',
        category: LuxuryCategory.lifestyle,
        price: 750.0,
        icon: '✒️',
        description: 'Damit werden Millionenverträge und Börsen-Übernahmen unterzeichnet.',
        prestigePoints: 14,
      ),
      LuxuryItem(
        id: 'life_gold_iphone',
        name: 'Custom 24k Gold iPhone Edition',
        category: LuxuryCategory.lifestyle,
        price: 2400.0,
        icon: '📱',
        description: 'Massiver Goldrahmen mit graviertem Bullen-Emblem.',
        prestigePoints: 40,
      ),
      LuxuryItem(
        id: 'life_wine',
        name: 'Château Lafite Rothschild 1996',
        category: LuxuryCategory.lifestyle,
        price: 4500.0,
        icon: '🍷',
        description: 'Ein legendärer Bordeaux-Jahrgang für deine ersten Aktiengewinne.',
        prestigePoints: 75,
      ),
      LuxuryItem(
        id: 'life_golf_club',
        name: 'VIP Golf-Club Jahresmitgliedschaft',
        category: LuxuryCategory.lifestyle,
        price: 8900.0,
        icon: '🏌️',
        description: 'Networking mit den Top-CEOs und Investmentbankern auf dem Green.',
        prestigePoints: 140,
      ),

      // --- UHREN ---
      LuxuryItem(
        id: 'watch_rolex_sub',
        name: 'Rolex Submariner Date',
        category: LuxuryCategory.watch,
        price: 14500.0,
        icon: '⌚',
        description: 'Der zeitlose Klassiker unter den Taucheruhren. Der Einstieg in die High Society.',
        prestigePoints: 100,
      ),
      LuxuryItem(
        id: 'watch_ap_royaloak',
        name: 'Audemars Piguet Royal Oak',
        category: LuxuryCategory.watch,
        price: 52000.0,
        icon: '💎',
        description: 'Ikonisches Gérald Genta Achteck-Design aus gebürstetem Edelstahl.',
        prestigePoints: 400,
      ),
      LuxuryItem(
        id: 'watch_patek_nautilus',
        name: 'Patek Philippe Nautilus 5711',
        category: LuxuryCategory.watch,
        price: 125000.0,
        icon: '👑',
        description: 'Der Heilige Gral der Haute Horlogerie. Warteliste? Für dich nicht mehr.',
        prestigePoints: 1200,
      ),
      LuxuryItem(
        id: 'watch_rm_carbon',
        name: 'Richard Mille RM 11-03 Flyback',
        category: LuxuryCategory.watch,
        price: 380000.0,
        icon: '⚡',
        description: 'Ultraleichtes Karbon-Gehäuse. Wird von F1-Fahrern und Milliardären getragen.',
        prestigePoints: 3500,
      ),

      // --- SPORTWAGEN & SUPERCARS ---
      LuxuryItem(
        id: 'car_porsche_gt3',
        name: 'Porsche 911 GT3 RS',
        category: LuxuryCategory.vehicle,
        price: 275000.0,
        icon: '🏎️',
        description: '525 PS reiner Saugmotor mit gigantischem Heckflügel für die Rennstrecke.',
        prestigePoints: 2500,
      ),
      LuxuryItem(
        id: 'car_ferrari_sf90',
        name: 'Ferrari SF90 Stradale',
        category: LuxuryCategory.vehicle,
        price: 580000.0,
        icon: '🏁',
        description: '1.000 PS Hybrid-V8 aus Maranello. Katapultiert dich in 2,5 Sekunden auf 100 km/h.',
        prestigePoints: 6000,
      ),
      LuxuryItem(
        id: 'car_bugatti_chiron',
        name: 'Bugatti Chiron Super Sport',
        category: LuxuryCategory.vehicle,
        price: 3900000.0,
        icon: '🚀',
        description: '1.600 PS W16-Quad-Turbo. 440 km/h Spitze. Ultimatives Statussymbol.',
        prestigePoints: 35000,
      ),

      // --- IMMOBILIEN & PENTHOUSES ---
      LuxuryItem(
        id: 'house_vienna_penthouse',
        name: 'Dachterrassen-Penthouse Wien 1. Bezirk',
        category: LuxuryCategory.realEstate,
        price: 2800000.0,
        icon: '🏛️',
        description: '350 m² Luxus mit direktem Blick auf den Stephansdom und privatem Infinity-Pool.',
        prestigePoints: 25000,
      ),
      LuxuryItem(
        id: 'house_woerthersee_villa',
        name: 'Seevilla am Wörthersee',
        category: LuxuryCategory.realEstate,
        price: 5900000.0,
        icon: '🏰',
        description: 'Eigener Badestrand, Bootshaus und Hubschrauberlandeplatz in Kärnten.',
        prestigePoints: 50000,
      ),
      LuxuryItem(
        id: 'house_manhattan_billionaires',
        name: 'Penthouse Billionaires’ Row NYC',
        category: LuxuryCategory.realEstate,
        price: 22000000.0,
        icon: '🏙️',
        description: 'Über den Wolken von Manhattan im 85. Stockwerk mit 360-Grad-Blick auf den Central Park.',
        prestigePoints: 200000,
      ),

      // --- EXKLUSIV: JETS, YACHTEN & INSELN ---
      LuxuryItem(
        id: 'jet_gulfstream',
        name: 'Gulfstream G650ER Privatjet',
        category: LuxuryCategory.exclusive,
        price: 68000000.0,
        icon: '✈️',
        description: 'Nonstop von Wien nach Tokio mit eigener Mastersuite und Gourmet-Küche.',
        prestigePoints: 650000,
      ),
      LuxuryItem(
        id: 'yacht_superyacht',
        name: '95m Superyacht "The Bull of Wall Street"',
        category: LuxuryCategory.exclusive,
        price: 135000000.0,
        icon: '🛥️',
        description: 'Zwei Helipads, U-Boot-Garage, Spa-Bereich und 40 Mann Besatzung vor Monaco.',
        prestigePoints: 1500000,
      ),
    ];
  }
}
