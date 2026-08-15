import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const SmartGroceryApp());
}

class SmartGroceryApp extends StatelessWidget {
  const SmartGroceryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Grocery',
      theme: ThemeData(
        // De donkergroene kleur uit het design
        primaryColor: const Color(0xFF0F4D2A),
        scaffoldBackgroundColor: const Color(0xFFF7F9F8),
        useMaterial3: true,
        fontFamily: 'Roboto', 
      ),
      home: const HoofdNavigatie(),
    );
  }
}

// --- HOOFDNAVIGATIE (Bottom Navigation Bar) ---
class HoofdNavigatie extends StatefulWidget {
  const HoofdNavigatie({super.key});

  @override
  State<HoofdNavigatie> createState() => _HoofdNavigatieState();
}

class _HoofdNavigatieState extends State<HoofdNavigatie> {
  int _huidigeIndex = 0;

  // De verschillende schermen van de app
  final List<Widget> _schermen = [
    const VandaagScherm(),
    const PlaceholderScherm(titel: 'Jouw week'),
    const PlaceholderScherm(titel: 'Boodschappen'),
    const RouteScherm(), // Dit is nu het grijze scherm
  ];

  void _onItemTapped(int index) {
    setState(() {
      _huidigeIndex = index;
    });
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Vandaag'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Weekplan'),
          BottomNavigationBarItem(icon: Icon(Icons.format_list_bulleted), label: 'Lijst'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Route'),
        ],
      ),
    );
  }
}

// --- TAB 1: VANDAAG SCHERM (Design nagemaakt) ---
class VandaagScherm extends StatefulWidget {
  const VandaagScherm({super.key});

  @override
  State<VandaagScherm> createState() => _VandaagSchermState();
}

class _VandaagSchermState extends State<VandaagScherm> {
  final TextEditingController _menuController = TextEditingController();
  bool _isLaden = false;
  Map<String, dynamic>? _apiResultaat;

  Future<void> fetchBerekening(String ingevoerdMenu) async {
    setState(() {
      _isLaden = true;
      _apiResultaat = null; // Reset vorige resultaten
    });

    // LET OP: Check of dit jouw EXACTE nieuwe Render URL is!
    final url = Uri.parse('https://smartcart-vtxn.onrender.com/api/calculate');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'menu': ingevoerdMenu}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _apiResultaat = jsonDecode(response.body);
          _isLaden = false;
        });
      } else {
        setState(() { _isLaden = false; });
        // Toon de foutmelding op het scherm
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server fout: ${response.statusCode}. Check Render!'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      setState(() { _isLaden = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Netwerkfout: Kan server niet bereiken.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  // Berekent het totaal aantal producten in alle categorieën
  int _berekenTotaalProducten() {
    if (_apiResultaat == null || _apiResultaat!['ingredienten'] == null) return 0;
    int totaal = 0;
    final ingredientenMap = _apiResultaat!['ingredienten'] as Map<String, dynamic>;
    for (var lijst in ingredientenMap.values) {
      if (lijst is List) totaal += lijst.length;
    }
    return totaal;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Goedemorgen\nWard',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2),
                ),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF0F4D2A),
                      child: const Text('W', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.notifications_outlined, size: 28),
                  ],
                )
              ],
            ),
            const SizedBox(height: 32),
            
            const Text(
              'Wat wil je deze week eten?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: TextField(
                controller: _menuController,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (waarde) {
                  if (waarde.isNotEmpty) {
                    FocusScope.of(context).unfocus();
                    fetchBerekening(waarde);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Vertel wat je lekker vindt, hoeveel je wilt uitgeven of wat je nog in huis hebt...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  suffixIcon: _isLaden 
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F4D2A)),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send, color: Color(0xFF0F4D2A)),
                          onPressed: () {
                            if (_menuController.text.isNotEmpty) {
                              FocusScope.of(context).unfocus();
                              fetchBerekening(_menuController.text);
                            }
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (_apiResultaat != null) ...[
              // We tonen nu ook de naam van het gerecht dat Gemini heeft gekozen!
              Text(
                'Gekozen: ${_apiResultaat!['gekozen_gerecht'] ?? 'Menu'}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F4D2A)),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F4D2A),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _bouwStatRow(Icons.local_offer_outlined, '€${_apiResultaat!['total_price'] ?? '0.00'} totaal'),
                    const Divider(color: Colors.white24, height: 32),
                    _bouwStatRow(Icons.eco_outlined, 'Route: ${_apiResultaat!['route_info'] ?? 'Berekend'}'),
                    const Divider(color: Colors.white24, height: 32),
                    _bouwStatRow(
                      Icons.storefront_outlined, 
                      '${_berekenTotaalProducten()} producten gevonden',
                      onTap: () => _toonProductenLijst(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F4D2A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => _toonProductenLijst(context),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 16.0),
                        child: Text('Bekijk boodschappenlijst', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      Icon(Icons.chevron_right, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _bouwStatRow(IconData icon, String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text, 
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                softWrap: true,
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  void _toonProductenLijst(BuildContext context) {
    if (_apiResultaat == null || _apiResultaat!['ingredienten'] == null) return;
    
    final ingredientenMap = _apiResultaat!['ingredienten'] as Map<String, dynamic>;
    final gerechtNaam = _apiResultaat!['gekozen_gerecht'] ?? 'Boodschappenlijst';

    // We bouwen dynamisch een lijst met categorie-koppen en de producten eronder
    List<Widget> lijstWeergave = [];
    
    ingredientenMap.forEach((categorie, producten) {
      final prodLijst = producten as List<dynamic>;
      if (prodLijst.isNotEmpty) {
        // Voeg de categorie titel toe
        lijstWeergave.add(
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: Text(
              categorie, 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F4D2A))
            ),
          )
        );
        // Voeg de producten onder deze categorie toe
        for (var product in prodLijst) {
          lijstWeergave.add(
            Card(
              elevation: 0,
              color: Colors.grey.shade50,
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline, color: Color(0xFF0F4D2A)),
                title: Text(product.toString(), style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
            )
          );
        }
      }
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true, // Zorgt dat de popup groter kan worden als de lijst lang is
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6, // Start op 60% van het scherm
          maxChildSize: 0.9, // Kan uitgeschoven worden tot 90%
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(gerechtNaam, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      controller: controller,
                      children: lijstWeergave,
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }
}

// --- TAB 2 & 3: PLACEHOLDER SCHERMEN ---
class PlaceholderScherm extends StatelessWidget {
  final String titel;
  const PlaceholderScherm({super.key, required this.titel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        titel,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F4D2A)),
      ),
    );
  }
}

// --- TAB 4: ROUTE SCHERM ---
class RouteScherm extends StatelessWidget {
  const RouteScherm({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Route & Kaart',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F4D2A)),
      ),
    );
  }
}