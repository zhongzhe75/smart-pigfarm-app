String twoDigits(int value) => value.toString().padLeft(2, '0');

String formatClock(DateTime dateTime) {
  return '${twoDigits(dateTime.hour)}:${twoDigits(dateTime.minute)}:${twoDigits(dateTime.second)}';
}

String formatDate(DateTime dateTime) {
  return '${dateTime.year}-${twoDigits(dateTime.month)}-${twoDigits(dateTime.day)}';
}

String formatDateTime(DateTime dateTime) {
  return '${formatDate(dateTime)} ${formatClock(dateTime)}';
}

String formatShortDate(DateTime dateTime) {
  return '${twoDigits(dateTime.month)}/${twoDigits(dateTime.day)}';
}
