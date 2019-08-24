String durationString(Duration d) {
  return d
      .toString()
      .split('.')
      .first
      .split(':')
      .where((String e) => e != '0')
      .toList()
      .join(':');
}
