/// The bank only hands out loans on weekdays (Monday to Friday, device time,
/// like the exchange hours in MarketSchedule). Repaying is always possible.
class BankHours {
  const BankHours._();

  static bool isOpen([DateTime? now]) =>
      (now ?? DateTime.now()).weekday <= DateTime.friday;

  static const closedMessage =
      'Die Bank hat am Wochenende geschlossen. Kredite gibt es nur von '
      'Montag bis Freitag. Nächster Kredit-Termin: Montag.';
}
