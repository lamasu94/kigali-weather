import 'package:weather_app/weather.dart';

void main() async {
  print('Asking the weather server...');
  final weather = await fetchWeather();
  print(
    'Kigali: ${weather.temperature}°C, humidity ${weather.humidity}%, wind ${weather.wind} km/h, code ${weather.code}',
  );
}