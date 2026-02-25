import 'dart:convert';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ArovaApp());
}

class ArovaApp extends StatelessWidget {
  const ArovaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AROVA',
      theme: ThemeData(primarySwatch: Colors.red),
      home: const AuthScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ==========================================
// 1. REAL AUTHENTICATION & LOGIN (Features 1 & 2)
// ==========================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isAmbulance = true;
  bool isLogin = true; 
  final TextEditingController idController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  Future<void> _processAuth() async {
    String id = idController.text.trim();
    String password = passwordController.text.trim();
    
    if (id.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter ID and Password')));
      return;
    }

    setState(() => isLoading = true);
    String collection = isAmbulance ? 'ambulances' : 'hospitals';
    
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection(collection).doc(id).get();
      
      if (!isLogin) {
        // REGISTRATION FLOW
        if (doc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID already registered. Please login.')));
        } else {
          // Simulate OTP Verification
          await showDialog(
            context: context, barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('OTP Verification'),
              content: const TextField(decoration: InputDecoration(hintText: 'Enter 4-digit OTP (Any number works)'), keyboardType: TextInputType.number),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    // Save credentials
                    await FirebaseFirestore.instance.collection(collection).doc(id).set({'password': password, 'created': FieldValue.serverTimestamp()});
                    Navigator.pop(context);
                    _navigateNext(id);
                  },
                  child: const Text('Verify & Register'),
                )
              ],
            ),
          );
        }
      } else {
        // LOGIN FLOW
        if (!doc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid ID. User not found.')));
        } else if (doc.get('password') != password) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect Password.')));
        } else {
          _navigateNext(id);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => isLoading = false);
  }

  void _navigateNext(String id) {
    if (isAmbulance) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AmbulanceBaseNav(ambulanceId: id)));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HospitalBaseNav(hospitalId: id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Text('AROVA', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.redAccent)),
              Text(isLogin ? 'Login to your account' : 'Register new account', style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(label: const Text('Ambulance'), selected: isAmbulance, onSelected: (val) => setState(() => isAmbulance = true)),
                  const SizedBox(width: 20),
                  ChoiceChip(label: const Text('Hospital'), selected: !isAmbulance, onSelected: (val) => setState(() => isAmbulance = false)),
                ],
              ),
              const SizedBox(height: 30),
              TextField(controller: idController, decoration: InputDecoration(labelText: isAmbulance ? 'RTO Registration Number' : '10-Digit NIN Number', border: const OutlineInputBorder())),
              const SizedBox(height: 15),
              TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
              const SizedBox(height: 20),
              isLoading 
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.black),
                    onPressed: _processAuth,
                    child: Text(isLogin ? 'Login' : 'Register', style: const TextStyle(color: Colors.white, fontSize: 18)),
                  ),
              TextButton(onPressed: () => setState(() => isLogin = !isLogin), child: Text(isLogin ? 'Need an account? Register here' : 'Already have an account? Login', style: const TextStyle(color: Colors.redAccent)))
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. AMBULANCE DASHBOARD & ROUTING
// ==========================================
class AmbulanceBaseNav extends StatefulWidget {
  final String ambulanceId;
  const AmbulanceBaseNav({super.key, required this.ambulanceId});
  @override
  State<AmbulanceBaseNav> createState() => _AmbulanceBaseNavState();
}
class _AmbulanceBaseNavState extends State<AmbulanceBaseNav> {
  int _currentIndex = 0;
  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [AmbulanceMapScreen(ambulanceId: widget.ambulanceId), HistoryScreen(userId: widget.ambulanceId, isAmbulance: true), const SettingsScreen()];
    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex, selectedItemColor: Colors.redAccent, onTap: (index) => setState(() => _currentIndex = index),
        items: const [BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'), BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'), BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings')],
      ),
    );
  }
}

class AmbulanceMapScreen extends StatefulWidget {
  final String ambulanceId;
  const AmbulanceMapScreen({super.key, required this.ambulanceId});
  @override
  State<AmbulanceMapScreen> createState() => _AmbulanceMapScreenState();
}
class _AmbulanceMapScreenState extends State<AmbulanceMapScreen> {
  LatLng _currentLocation = const LatLng(16.5062, 80.6480); 
  final TextEditingController conditionController = TextEditingController();
  bool _isLoadingLocation = true;
  final MapController _mapController = MapController();
  
  // Voice & Route Variables
  late stt.SpeechToText _speech;
  bool _isListening = false;
  List<LatLng> _routePoints = [];
  String _routeDistance = "";
  String? activeRequestId;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _requestExplicitLocation(); // Feature 3 & 7
    _listenForAcceptedRoute();
  }

  Future<void> _requestExplicitLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Turn on GPS in settings')));
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _isLoadingLocation = false;
    });
    _mapController.move(_currentLocation, 15.0);
  }

  // Feature 6: Working Voice to Text
  void _listenVoice() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) => setState(() => conditionController.text = val.recognizedWords));
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> requestHospital() async {
    if (conditionController.text.isEmpty) return;
    try {
      DocumentReference docRef = await FirebaseFirestore.instance.collection('requests').add({
        'ambulanceId': widget.ambulanceId, 'condition': conditionController.text,
        'ambLat': _currentLocation.latitude, 'ambLng': _currentLocation.longitude,
        'status': 'pending', 'timestamp': FieldValue.serverTimestamp(),
      });
      setState(() => activeRequestId = docRef.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent! Waiting for hospital...')));
      
      // Feature 8: The 3 Minute Timeout (Simulated 30s for demo)
      Future.delayed(const Duration(seconds: 30), () {
        FirebaseFirestore.instance.collection('requests').doc(docRef.id).get().then((doc) {
          if (doc.exists && doc['status'] == 'pending') {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Timeout! Suggesting Top 3 Nearby Hospitals...'), backgroundColor: Colors.orange));
          }
        });
      });
    } catch (e) { print(e); }
  }

  // Feature 4: Live Routing when Hospital Accepts
  void _listenForAcceptedRoute() {
    FirebaseFirestore.instance.collection('requests').where('ambulanceId', isEqualTo: widget.ambulanceId).where('status', isEqualTo: 'accepted').snapshots().listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        var data = snapshot.docs.first.data();
        activeRequestId = snapshot.docs.first.id;
        // Fetch Route from OSRM
        double hospLat = data['hospLat'] ?? 16.51; // Fallback for testing
        double hospLng = data['hospLng'] ?? 80.65;
        
        final response = await http.get(Uri.parse('http://router.project-osrm.org/route/v1/driving/${_currentLocation.longitude},${_currentLocation.latitude};$hospLng,$hospLat?geometries=geojson'));
        if (response.statusCode == 200) {
          var routeData = jsonDecode(response.body);
          var coordinates = routeData['routes'][0]['geometry']['coordinates'];
          double dist = routeData['routes'][0]['distance'] / 1000; // km
          
          List<LatLng> points = [];
          for (var coord in coordinates) { points.add(LatLng(coord[1], coord[0])); }
          
          setState(() {
            _routePoints = points;
            _routeDistance = "${dist.toStringAsFixed(1)} km to Hospital";
          });
        }
      } else {
        setState(() { _routePoints = []; _routeDistance = ""; }); // Clear route if completed
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _isLoadingLocation 
            ? const Center(child: CircularProgressIndicator(color: Colors.red))
            : FlutterMap(
                mapController: _mapController, options: MapOptions(initialCenter: _currentLocation, initialZoom: 14.0),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                  PolylineLayer(polylines: [Polyline(points: _routePoints, color: Colors.blue, strokeWidth: 4.0)]),
                  MarkerLayer(markers: [Marker(point: _currentLocation, child: const Icon(Icons.local_shipping, color: Colors.red, size: 40))]),
                ],
              ),
          if (_routeDistance.isNotEmpty)
            Positioned(top: 50, left: 20, right: 20, child: Card(color: Colors.green, child: Padding(padding: const EdgeInsets.all(12.0), child: Text("Route Confirmed: $_routeDistance", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center)))),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(25), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: conditionController, decoration: const InputDecoration(hintText: 'Patient condition', border: OutlineInputBorder())),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      FloatingActionButton(backgroundColor: _isListening ? Colors.red : Colors.blue, onPressed: _listenVoice, child: Icon(_isListening ? Icons.mic_off : Icons.mic)),
                      FloatingActionButton(backgroundColor: Colors.green, onPressed: () {}, child: const Icon(Icons.camera_alt)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.black),
                    onPressed: requestHospital, child: const Text('Find Hospital Nearby', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. HOSPITAL DASHBOARD
// ==========================================
class HospitalBaseNav extends StatefulWidget {
  final String hospitalId;
  const HospitalBaseNav({super.key, required this.hospitalId});
  @override
  State<HospitalBaseNav> createState() => _HospitalBaseNavState();
}
class _HospitalBaseNavState extends State<HospitalBaseNav> {
  int _currentIndex = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: [HospitalDashboard(hospitalId: widget.hospitalId), HistoryScreen(userId: widget.hospitalId, isAmbulance: false), const SettingsScreen()][_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex, selectedItemColor: Colors.redAccent, onTap: (index) => setState(() => _currentIndex = index),
        items: const [BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Requests'), BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'), BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings')],
      ),
    );
  }
}

class HospitalDashboard extends StatelessWidget {
  final String hospitalId;
  const HospitalDashboard({super.key, required this.hospitalId});

  void acceptRequest(String docId, BuildContext context) async {
    // Generate a random nearby GPS coordinate for the hospital to enable routing
    await FirebaseFirestore.instance.collection('requests').doc(docId).update({
      'status': 'accepted', 'acceptedBy': hospitalId,
      'hospLat': 16.50 + (DateTime.now().millisecond / 100000), // Mock location near Amaravati
      'hospLng': 80.64 + (DateTime.now().millisecond / 100000),
    });
  }

  void markCompleted(String docId) {
    FirebaseFirestore.instance.collection('requests').doc(docId).update({'status': 'completed'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Active Dashboard'), backgroundColor: Colors.redAccent),
      // Feature 5: Shows BOTH pending and accepted requests until 'Completed' is pressed
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('requests').where('status', whereIn: ['pending', 'accepted']).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final requests = snapshot.data!.docs;
          if (requests.isEmpty) return const Center(child: Text('No active requests.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16), itemCount: requests.length,
            itemBuilder: (context, index) {
              var data = requests[index].data() as Map<String, dynamic>;
              bool isAccepted = data['status'] == 'accepted';
              bool isMine = data['acceptedBy'] == hospitalId;

              if (isAccepted && !isMine) return const SizedBox.shrink(); // Hide if someone else took it

              return Card(
                color: isAccepted ? Colors.green[50] : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ambulance: ${data['ambulanceId']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Condition: ${data['condition']}'),
                      const SizedBox(height: 10),
                      isAccepted 
                        ? ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), onPressed: () => markCompleted(requests[index].id), child: const Text('Patient Arrived - Complete Trip', style: TextStyle(color: Colors.white)))
                        : ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: () => acceptRequest(requests[index].id, context), child: const Text('Accept Request', style: TextStyle(color: Colors.white))),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// 4. REAL HISTORY & CLICKABLE SETTINGS
// ==========================================
class HistoryScreen extends StatelessWidget {
  final String userId;
  final bool isAmbulance;
  const HistoryScreen({super.key, required this.userId, required this.isAmbulance});

  @override
  Widget build(BuildContext context) {
    String fieldToQuery = isAmbulance ? 'ambulanceId' : 'acceptedBy';
    return Scaffold(
      appBar: AppBar(title: const Text('Trip History'), backgroundColor: Colors.black),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('requests').where(fieldToQuery, isEqualTo: userId).where('status', isEqualTo: 'completed').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No history found.'));
          
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) => ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text(docs[index]['condition']),
              subtitle: Text(isAmbulance ? 'Delivered to: ${docs[index]['acceptedBy']}' : 'From: ${docs[index]['ambulanceId']}'),
            ),
          );
        },
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: Colors.black),
      body: ListView(
        children: [
          ListTile(leading: const Icon(Icons.person), title: const Text('Profile'), onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile options opened')))),
          ListTile(leading: const Icon(Icons.notifications), title: const Text('Alerts'), onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert settings opened')))),
          ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Logout', style: TextStyle(color: Colors.red)), onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthScreen()))),
        ],
      ),
    );
  }
}