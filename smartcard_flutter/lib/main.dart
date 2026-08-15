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
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Vandaag'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Maaltijd'),
          BottomNavigationBarItem(icon: Icon(Icons.format_list_bulleted), label: 'Lijst'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Route'),
        ],
      ),
    );
  }
}

// --- TAB 1: VANDAAG SCHERM (Time-first benadering) ---
class VandaagScherm extends StatefulWidget {
  const VandaagScherm({super.key});

  @override
  State<VandaagScherm> createState() => _VandaagSchermState();
}

class _VandaagSchermState extends State<VandaagScherm> {
  final TextEditingController _tijdController = TextEditingController();
  bool _isLaden = false;
  List<dynamic>? _suggesties;

  Future<void> fetchBerekening(String input) async {
    setState(() {
      _isLaden = true;
      _suggesties = null; 
    });

    // LET OP: Update deze URL naar jouw echte Render URL
    final url = Uri.parse('https://smartcart-vtxn.onrender.com/api/calculate');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'menu': input}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _suggesties = data['suggesties'];
          _isLaden = false;
        });
      } else {
        setState(() { _isLaden = false; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server fout: ${response.statusCode}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      setState(() { _isLaden = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Netwerkfout: Kan server niet bereiken.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _tijdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Goedenavond\nWard',
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
            const SizedBox(height: 24),

            // GESIMULEERDE AGENDA WIDGET
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Vandaag', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, size: 14, color: Color(0xFF0F4D2A)),
                            SizedBox(width: 4),
                            Text('Agenda gekoppeld', style: TextStyle(fontSize: 12, color: Color(0xFF0F4D2A))),
                          ],
                        ),
                      )
                    ],
                  ),
                  const Divider(height: 24),
                  _bouwAgendaItem(Icons.work_outline, '17:00', 'Werk klaar', 'UZ Leuven'),
                  const SizedBox(height: 12),
                  _bouwAgendaItem(Icons.sports_tennis, '19:00', 'Tennis', 'Start om 19:00'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // TIJD INPUT WIDGET
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0F4D2A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'JOUW BESCHIKBARE TIJD',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('1u 20', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Text(
                    'Inclusief winkel, rit naar huis en koken.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _tijdController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (waarde) {
                        if (waarde.isNotEmpty) fetchBerekening(waarde);
                      },
                      decoration: InputDecoration(
                        hintText: 'Bijv: 1u 20m, gezond en licht',
                        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        suffixIcon: _isLaden 
                            ? const Padding(
                                padding: EdgeInsets.all(10.0),
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F4D2A)),
                              )
                            : IconButton(
                                icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFF0F4D2A), size: 18),
                                onPressed: () {
                                  if (_tijdController.text.isNotEmpty) {
                                    FocusScope.of(context).unfocus();
                                    fetchBerekening(_tijdController.text);
                                  }
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // SUGGESTIES LIJST
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

  Widget _bouwAgendaItem(IconData icon, String tijd, String titel, String subtitel) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 12),
        Text(tijd, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titel, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(subtitel, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        )
      ],
    );
  }

  Widget _bouwMaaltijdKaart(Map<String, dynamic> gerecht) {
    return GestureDetector(
      onTap: () => _toonRoutePlanEnWinkel(context, gerecht),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.restaurant, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gerecht['gerecht_naam'] ?? 'Onbekend gerecht',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gerecht['waarom_geschikt'] ?? '',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${gerecht['bereidingstijd_minuten']} min',
                          style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // Toont de gesimuleerde route/tijdslijn en ingrediëntenlijst
  void _toonRoutePlanEnWinkel(BuildContext context, Map<String, dynamic> gerecht) {
    final ingredientenMap = gerecht['ingredienten'] as Map<String, dynamic>?;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
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
                  
                  // Gesimuleerde Timeline
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F4D2A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Eten klaar om 18:15', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(gerecht['gerecht_naam'], style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        const Divider(color: Colors.white24, height: 32),
                        _bouwTijdStap('17:02', 'Vertrek van je werk'),
                        _bouwTijdStap('17:13', 'Winkelen (Carrefour Market)'),
                        _bouwTijdStap('17:48', 'Thuis aankomen'),
                        _bouwTijdStap('18:15', 'Maaltijd klaar', isLaatste: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Ingrediëntenlijst
                  const Text('Boodschappen', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (ingredientenMap != null) 
                    ...ingredientenMap.entries.map((entry) {
                      final items = entry.value as List<dynamic>;
                      if (items.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                            child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F4D2A))),
                          ),
                          ...items.map((item) => Card(
                            elevation: 0,
                            color: Colors.grey.shade50,
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              leading: const Icon(Icons.check_circle_outline, color: Color(0xFF0F4D2A)),
                              title: Text(item.toString(), style: const TextStyle(fontWeight: FontWeight.w500)),
                            ),
                          )),
                        ],
                      );
                    }),
                  
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F4D2A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Start Route', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            );
          }
        );
      },
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
          Text(actie, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class PlaceholderScherm extends StatelessWidget {
  final String titel;
  const PlaceholderScherm({super.key, required this.titel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(titel, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F4D2A))),
    );
  }
}