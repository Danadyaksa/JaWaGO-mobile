import 'dart:math';

class GeoHelper {
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371e3;
    double phi1 = lat1 * pi / 180;
    double phi2 = lat2 * pi / 180;
    double deltaPhi = (lat2 - lat1) * pi / 180;
    double deltaLambda = (lon2 - lon1) * pi / 180;

    double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return r * c;
  }

  static String calculateETA(double distanceInMeters) {
    const int speedKmh = 40;
    double distanceKm = distanceInMeters / 1000;
    double timeHours = distanceKm / speedKmh;
    int timeMinutes = (timeHours * 60).ceil();

    if (timeMinutes < 1) return "1 mnt";
    if (timeMinutes > 60) {
      int hours = timeMinutes ~/ 60;
      int mins = timeMinutes % 60;
      return "$hours jam $mins mnt";
    }
    return "$timeMinutes mnt";
  }

  static String getMockAddress(double lat, double lng) {
    const List<String> streets = [
      "Jl. Kaliurang",
      "Jl. Gejayan",
      "Jl. Malioboro",
      "Jl. Magelang",
      "Ringroad Utara",
      "Jl. Solo"
    ];
    int streetIndex = (lat * 1000).abs().toInt() % streets.length;
    String randomStreet = streets[streetIndex];
    int number = ((lng * 1000).abs().toInt() % 200) + 1;
    return "$randomStreet No. $number, Yogyakarta";
  }
}
