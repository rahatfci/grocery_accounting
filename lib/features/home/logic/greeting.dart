/// Home's greeting for the hour at [now]: morning until noon, afternoon
/// until six, evening after that and through the small hours.
String greetingFor(DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 12) {
    return 'Good morning';
  }
  if (hour >= 12 && hour < 18) {
    return 'Good afternoon';
  }
  return 'Good evening';
}
