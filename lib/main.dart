import 'dart:convert';
import 'package:flutter/material.dart';
import 'weather.dart';
import 'package:shared_preferences/shared_preferences.dart';
IconData iconFor(int code) {
  if (code == 0) return Icons.wb_sunny;
  if (code <= 3) return Icons.cloud;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 95) return Icons.thunderstorm;
  if (code >= 51) return Icons.water_drop;
  return Icons.help_outline;
}

class WeatherCard extends StatelessWidget {
  const WeatherCard({
    super.key,
    required this.weather,
  });

  final Weather weather;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Weather icon
            Icon(
              iconFor(weather.code),
              size: 80,
              color: Colors.blue,
            ),

            const SizedBox(height: 16),

            // Temperature
            Text(
              '${weather.temperature.round()}°C',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Weather description
            Text(
              describe(weather.code),
              style: const TextStyle(
                fontSize: 20,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 24),

            // Humidity and wind
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    const Icon(
                      Icons.water_drop,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 8),
                    Text('${weather.humidity}%'),
                    const Text('Humidity'),
                  ],
                ),

                Column(
                  children: [
                    const Icon(
                      Icons.air,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 8),
                    Text('${weather.wind} km/h'),
                    const Text('Wind'),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Last updated time
            Text(
              'Updated at ${weather.time.substring(11)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(const WeatherApp());
}


class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue),
      home: const WeatherScreen(),
    );
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  Weather? weather;
  bool loading = true;
  String? error;
  City selectedCity = cities[0];
  bool offline = false;
  @override
  void initState() {
    super.initState();
    restoreCityAndLoad();
  }
  Future<void> restoreCityAndLoad() async {
    final prefs = await SharedPreferences.getInstance();

    final savedCity = prefs.getString('city');

    if (!mounted) return;

    setState(() {
      selectedCity = cities.firstWhere(
            (city) => city.name == savedCity,
        orElse: () => cities[0],
      );
    });

    await load();
  }
  Future<void> selectCity(City city) async {
    if (city.name == selectedCity.name) return;

    setState(() {
      selectedCity = city;
      loading = true;
      error = null;
    });

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('city', city.name);

    await load();
  }


  Future<void> load() async {
    try {
      // Fetch fresh weather for the selected city.
      final result = await fetchWeather(selectedCity);

      // Save the successful result for this city.
      final prefs = await SharedPreferences.getInstance();
      final text = jsonEncode(result.toJson());

      await prefs.setString(
        'weather_${selectedCity.name}',
        text,
      );

      if (!mounted) return;

      setState(() {
        weather = result;
        loading = false;
        error = null;
        offline = false;
      });
    } catch (e) {
      // Try to find previously saved weather for this city.
      try {
        final prefs = await SharedPreferences.getInstance();

        final text = prefs.getString(
          'weather_${selectedCity.name}',
        );

        if (text != null) {
          final savedWeather = Weather.fromJson(
            jsonDecode(text) as Map<String, dynamic>,
          );

          if (!mounted) return;

          setState(() {
            weather = savedWeather;
            loading = false;
            error = null;
            offline = true;
          });

          return;
        }
      } catch (_) {
        // If cached data cannot be read, show the error.
      }

      if (!mounted) return;

      setState(() {
        loading = false;
        error =
        'Could not load the weather. Check your internet connection.';
        offline = false;
      });
    }
  }


  void retry() {
    setState(() {
      loading = true;
      error = null;
    });
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${selectedCity.name} Weather'),
      ),

        body: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),

            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: cities.map((city) {
                    return ChoiceChip(
                      label: Text(city.name),
                      selected: selectedCity.name == city.name,
                      onSelected: (_) => selectCity(city),
                    );
                  }).toList(),
                ),
              ),


              SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Center(
                  child: loading
                      ? const CircularProgressIndicator()
                      : error != null
                      ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: retry,
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                      : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (offline)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Offline: showing the weather saved at '
                                '${weather!.time.substring(11)}',
                            style: TextStyle(
                              color: Colors.brown.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      WeatherCard(weather: weather!),
                    ],
                  ),
                ),
              ),

            ],

          ),
        ),
    );
  }
}


