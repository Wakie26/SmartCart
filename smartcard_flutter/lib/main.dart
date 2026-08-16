import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const SmartGroceryApp());
}

// --- CENTRALE INSTELLINGEN ---
final String orsToken = dotenv.env['ORS_API_KEY'] ?? '';
const double thuisLat = 50.8284; // Kerselaarlaan 2A, Bierbeek
const double thuisLon = 4.7599;

void main() {
  runApp(const SmartGroceryApp());
}

class SmartGroceryApp extends StatelessWidget {
  const SmartGroceryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartCart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF0F4D2A),
        scaffoldBackgroundColor: const Color(0xFFF7F9F8),
        useMaterial3: true,
        fontFamily: 'Roboto', 
      ),
      home: const HoofdNavigatie(),
    );
  }
}

// --- HOOFDNAVIGATIE ---
class HoofdNavigatie extends StatefulWidget {
  const HoofdNavigatie({super.key});

  @override
  State<HoofdNavigatie> createState() => _HoofdNavigatieState();
}

class _HoofdNavigatieState extends State<HoofdNavigatie> {
  int _huidigeIndex = 0;

  final List<Widget> _schermen = [
    const VandaagScherm(),
    const PlaceholderScherm(titel: 'Maaltijd'),
    const PlaceholderScherm(titel: 'Lijst'),
    const PlaceholderScherm(titel: 'Route'),
  ];

  void _onItemTapped(int index) {
    setState(() { _huidigeIndex = index; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _schermen[_huidigeIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _huidigeIndex,
        selectedItemColor: const Color(0xFF0F4D2A),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Vandaag'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Maaltijd'),
          BottomNavigationBarItem(icon: Icon(Icons.format_list_bulleted), label: 'Lijst'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Route'),
        ],
      ),
    );
  }
}

// --- TAB 1: VANDAAG SCHERM ---
class VandaagScherm extends StatefulWidget {
  const VandaagScherm({super.key});

  @override
  State<VandaagScherm> createState() => _VandaagSchermState();
}

class _VandaagSchermState extends State<VandaagScherm> {
  final TextEditingController _tijdController = TextEditingController();
  
  // Maaltijd Variabelen
  bool _isGeminiLaden = false;
  List<dynamic>? _suggesties;

  // Route Variabelen (Worden op de achtergrond berekend)
  bool _isRouteLaden = true;
  String _routeFoutmelding = '';
  String _gekozenWinkelNaam = 'zoeken...';
  int _ritNaarWinkelMin = 0;
  int _ritNaarHuisMin = 0;

  @override
  void initState() {
    super.initState();
    _laadRealistischeReistijden();
  }

  Future<void> _laadRealistischeReistijden() async {
    try {
      // 1. Locatie ophalen
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('GPS staat uit.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Geen GPS toestemming.');
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final double startLat = position.latitude;
      final double startLon = position.longitude;

      // 2. OpenStreetMap (Winkel zoeken in 10km radius)
      final overpassUrl = Uri.parse('https://overpass-api.de/api/interpreter');
      final overpassQuery = '''
        [out:json];
        node["shop"="supermarket"](around:10000,$startLat,$startLon);
        out 1;
      ''';
      final overpassResponse = await http.post(overpassUrl, headers: {'User-Agent': 'SmartCartPrototype/1.0'}, body: overpassQuery);
      if (overpassResponse.statusCode != 200) throw Exception('Fout bij OpenStreetMap');
      
      final overpassData = json.decode(overpassResponse.body);
      if (overpassData['elements'].isEmpty) throw Exception('Geen winkel in de buurt');

      final winkelElement = overpassData['elements'][0];
      final double winkelLat = winkelElement['lat'];
      final double winkelLon = winkelElement['lon'];
      final winkelNaam = winkelElement['tags']?['name'] ?? 'Supermarkt';

      // 3. OpenRouteService (Leg 1: Huidig -> Winkel)
      final String orsUrl1 = 'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$orsToken&start=$startLon,$startLat&end=$winkelLon,$winkelLat';
      final orsRes1 = await http.get(Uri.parse(orsUrl1));
      final int ritWinkel = (json.decode(orsRes1.body)['features'][0]['properties']['summary']['duration'] / 60).round();

      // 4. OpenRouteService (Leg 2: Winkel -> Thuis in Bierbeek)
      final String orsUrl2 = 'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$orsToken&start=$winkelLon,$winkelLat&end=$thuisLon,$thuisLat';
      final orsRes2 = await http.get(Uri.parse(orsUrl2));
      final int ritHuis = (json.decode(orsRes2.body)['features'][0]['properties']['summary']['duration'] / 60).round();

      if (mounted) {
        setState(() {
          _gekozenWinkelNaam = winkelNaam;
          _ritNaarWinkelMin = ritWinkel;
          _ritNaarHuisMin = ritHuis;
          _isRouteLaden = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _routeFoutmelding = e.toString().replaceAll('Exception: ', '');
          _isRouteLaden = false;
        });
      }
    }
  }

  Future<void> fetchBerekening(String input) async {
    setState(() { _isGeminiLaden = true; _suggesties = null; });
    final url = Uri.parse('https://smartcart-vtxn.onrender.com/api/calculate'); // Jouw render URL
    
    // We tellen de logistieke tijd op: rit 1 + 15 min winkelen + rit 2
    final int logistiekTijd = _ritNaarWinkelMin + 15 + _ritNaarHuisMin;

    try {
      final response = await http.post(
        url, 
        headers: {'Content-Type': 'application/json'}, 
        body: jsonEncode({
          'menu': input,
          'reistijd_minuten': logistiekTijd // Dit sturen we nu mee naar de AI!
        })
      );
      
      if (response.statusCode == 200) {
        setState(() { _suggesties = jsonDecode(response.body)['suggesties']; _isGeminiLaden = false; });
      } else {
        setState(() { _isGeminiLaden = false; });
      }
    } catch (e) {
      setState(() { _isGeminiLaden = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // We berekenen hier de weergave voor het groene blok
    int totaalMinimumMinuten = _ritNaarWinkelMin + 15 + _ritNaarHuisMin + 20; // Rit 1 + Winkel + Rit 2 + Standaard 20m koken
    int uren = totaalMinimumMinuten ~/ 60;
    int minuten = totaalMinimumMinuten % 60;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Goedenavond\nWard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2)),
            const SizedBox(height: 24),

            // DYNAMISCH TIJD BLOK
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF0F4D2A), borderRadius: BorderRadius.circular(20)),
              child: _isRouteLaden
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : _routeFoutmelding.isNotEmpty
                      ? Text(_routeFoutmelding, style: const TextStyle(color: Colors.redAccent))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('MINIMAAL BENODIGDE TIJD VANDAAG', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text('${uren > 0 ? '${uren}u ' : ''}${minuten.toString().padLeft(2, '0')}m', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Text('Via $_gekozenWinkelNaam naar Kerselaarlaan 2A. Incl. 20m koken.', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                              child: TextField(
                                controller: _tijdController,
                                onSubmitted: (waarde) { if (waarde.isNotEmpty) fetchBerekening(waarde); },
                                decoration: InputDecoration(
                                  hintText: 'Wat wil je eten? (of pas tijd aan)',
                                  hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  suffixIcon: _isGeminiLaden 
                                      ? const Padding(padding: EdgeInsets.all(10.0), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F4D2A)))
                                      : IconButton(icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFF0F4D2A), size: 18), onPressed: () => fetchBerekening(_tijdController.text)),
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
            const SizedBox(height: 24),

            if (_suggesties != null) ...[
              const Text('Wat past vandaag?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ..._suggesties!.map((gerecht) => _bouwMaaltijdKaart(gerecht)).toList(),
            ]
          ],
        ),
      ),
    );
  }

  Widget _bouwMaaltijdKaart(Map<String, dynamic> gerecht) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white,
          isScrollControlled: true, 
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (BuildContext context) {
            // We geven de al berekende tijden direct door aan de pop-up!
            return InstantRouteSheet(
              gerecht: gerecht,
              winkelNaam: _gekozenWinkelNaam,
              ritNaarWinkelMin: _ritNaarWinkelMin,
              ritNaarHuisMin: _ritNaarHuisMin,
            );
          }
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(
          children: [
            Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.restaurant, color: Colors.grey)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(gerecht['gerecht_naam'] ?? 'Gerecht', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(gerecht['waarom_geschikt'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Text('${gerecht['bereidingstijd_minuten']} min koken', style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// --- INSTANT ROUTE SCHERM (Geen laadtijd meer!) ---
class InstantRouteSheet extends StatelessWidget {
  final Map<String, dynamic> gerecht;
  final String winkelNaam;
  final int ritNaarWinkelMin;
  final int ritNaarHuisMin;

  const InstantRouteSheet({super.key, required this.gerecht, required this.winkelNaam, required this.ritNaarWinkelMin, required this.ritNaarHuisMin});

  String _formatTijd(DateTime tijd) {
    return "${tijd.hour.toString().padLeft(2, '0')}:${tijd.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final ingredientenMap = gerecht['ingredienten'] as Map<String, dynamic>?;
    final int kookTijd = gerecht['bereidingstijd_minuten'] ?? 20;

    // Instant tijdsberekening
    final nu = DateTime.now(); 
    final aankomstWinkel = nu.add(Duration(minutes: ritNaarWinkelMin));
    final vertrekWinkel = aankomstWinkel.add(const Duration(minutes: 15)); 
    final aankomstThuis = vertrekWinkel.add(Duration(minutes: ritNaarHuisMin)); 
    final maaltijdKlaar = aankomstThuis.add(Duration(minutes: kookTijd));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75, 
      maxChildSize: 0.95, 
      builder: (_, controller) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: ListView(
            controller: controller,
            children: [
              const Text('Jouw snelste plan', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF0F4D2A), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Eten klaar om ${_formatTijd(maaltijdKlaar)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(gerecht['gerecht_naam'], style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    const Divider(color: Colors.white24, height: 32),
                    _bouwTijdStap(_formatTijd(nu), 'Vertrek (Huidige locatie)'),
                    _bouwTijdStap(_formatTijd(aankomstWinkel), 'Aankomst $winkelNaam'),
                    _bouwTijdStap(_formatTijd(aankomstThuis), 'Thuis (Bierbeek) & Start koken'),
                    _bouwTijdStap(_formatTijd(maaltijdKlaar), 'Maaltijd klaar', isLaatste: true),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              const Text('Boodschappen', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (ingredientenMap != null) 
                ...ingredientenMap.entries.map((entry) {
                  final items = entry.value as List<dynamic>;
                  if (items.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(padding: const EdgeInsets.only(top: 16.0, bottom: 8.0), child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F4D2A)))),
                      ...items.map((item) => Card(elevation: 0, color: Colors.grey.shade50, margin: const EdgeInsets.only(bottom: 6), child: ListTile(leading: const Icon(Icons.check_circle_outline, color: Color(0xFF0F4D2A)), title: Text(item.toString(), style: const TextStyle(fontWeight: FontWeight.w500))))),
                    ],
                  );
                }),
              const SizedBox(height: 24),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F4D2A), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () => Navigator.pop(context), child: const Text('Start Route', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))
            ],
          ),
        );
      }
    );
  }

  Widget _bouwTijdStap(String tijd, String actie, {bool isLaatste = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Text(tijd, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          Icon(isLaatste ? Icons.check_circle : Icons.circle_outlined, color: Colors.white, size: 16),
          const SizedBox(width: 12),
          Expanded(child: Text(actie, style: const TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }
}

class PlaceholderScherm extends StatelessWidget {
  final String titel;
  const PlaceholderScherm({super.key, required this.titel});
  @override
  Widget build(BuildContext context) { return Center(child: Text(titel, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F4D2A)))); }
}