import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const ArovaApp());
  } catch (error) {
    runApp(ArovaApp(initializationError: error));
  }
}

class ArovaApp extends StatelessWidget {
  const ArovaApp({super.key, this.initializationError});

  final Object? initializationError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AROVA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
        useMaterial3: true,
      ),
      home: initializationError == null
          ? const AuthScreen()
          : InitializationErrorScreen(error: initializationError!),
    );
  }
}

class InitializationErrorScreen extends StatelessWidget {
  const InitializationErrorScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 56, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'AROVA could not connect to its services.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check the Firebase configuration and your network connection, then restart the app.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _demoOtp = '1234';

  bool _isAmbulance = true;
  bool _isLogin = true;
  bool _isLoading = false;
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _verifyOtp() async {
    final otpController = TextEditingController();
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('OTP verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Demo OTP: 1234'),
            const SizedBox(height: 12),
            TextField(
              controller: otpController,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'Enter the 4-digit OTP',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (otpController.text == _demoOtp) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    otpController.dispose();
    return verified ?? false;
  }

  Future<void> _processAuth() async {
    if (_isLoading) {
      return;
    }

    final id = _idController.text.trim();
    final password = _passwordController.text.trim();
    if (id.isEmpty || password.isEmpty) {
      _showMessage('Enter both your ID and password.');
      return;
    }

    setState(() => _isLoading = true);
    final collection = _isAmbulance ? 'ambulances' : 'hospitals';
    final account = FirebaseFirestore.instance.collection(collection).doc(id);

    try {
      final document = await account.get();
      if (!mounted) {
        return;
      }

      if (_isLogin) {
        final data = document.data();
        if (!document.exists || data?['password'] != password) {
          _showMessage('Invalid ID or password.');
          return;
        }
        _navigateNext(id);
        return;
      }

      if (document.exists) {
        _showMessage('This ID is already registered. Please log in.');
        return;
      }

      final verified = await _verifyOtp();
      if (!mounted) {
        return;
      }
      if (!verified) {
        _showMessage('OTP verification was cancelled or did not match.');
        return;
      }

      await account.set({
        'password': password,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) {
        return;
      }
      _navigateNext(id);
    } on FirebaseException {
      _showMessage('Could not reach the service. Please try again.');
    } catch (_) {
      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateNext(String id) {
    if (!mounted) {
      return;
    }
    final page = _isAmbulance
        ? AmbulanceBaseNav(ambulanceId: id)
        : HospitalBaseNav(hospitalId: id);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  const Icon(Icons.local_hospital, size: 64, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  const Text(
                    'AROVA',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: Colors.redAccent,
                    ),
                  ),
                  Text(_isLogin ? 'Sign in to dispatch care faster' : 'Create a response account'),
                  const SizedBox(height: 32),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Ambulance'), icon: Icon(Icons.emergency)),
                      ButtonSegment(value: false, label: Text('Hospital'), icon: Icon(Icons.local_hospital)),
                    ],
                    selected: {_isAmbulance},
                    onSelectionChanged: (selection) {
                      setState(() => _isAmbulance = selection.first);
                    },
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _idController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: _isAmbulance ? 'RTO registration number' : 'Hospital ID',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    onSubmitted: (_) => _processAuth(),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _isLoading ? null : _processAuth,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isLogin ? 'Log in' : 'Register'),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin ? 'Need an account? Register' : 'Already registered? Log in',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AmbulanceBaseNav extends StatefulWidget {
  const AmbulanceBaseNav({super.key, required this.ambulanceId});

  final String ambulanceId;

  @override
  State<AmbulanceBaseNav> createState() => _AmbulanceBaseNavState();
}

class _AmbulanceBaseNavState extends State<AmbulanceBaseNav> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      AmbulanceMapScreen(ambulanceId: widget.ambulanceId),
      HistoryScreen(userId: widget.ambulanceId, isAmbulance: true),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class AmbulanceMapScreen extends StatefulWidget {
  const AmbulanceMapScreen({super.key, required this.ambulanceId});

  final String ambulanceId;

  @override
  State<AmbulanceMapScreen> createState() => _AmbulanceMapScreenState();
}

class _AmbulanceMapScreenState extends State<AmbulanceMapScreen> {
  final _conditionController = TextEditingController();
  final _mapController = MapController();
  late final stt.SpeechToText _speech;

  LatLng? _currentLocation;
  List<LatLng> _routePoints = const [];
  String _routeDistance = '';
  String? _locationError;
  String? _activeRequestId;
  bool _isLoadingLocation = true;
  bool _isListening = false;
  bool _isSubmitting = false;
  bool _isFetchingRoute = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _requestSubscription;
  Timer? _requestTimeout;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    unawaited(_requestLocation());
  }

  @override
  void dispose() {
    _conditionController.dispose();
    _requestTimeout?.cancel();
    _requestSubscription?.cancel();
    unawaited(_speech.stop());
    super.dispose();
  }

  void _showMessage(String message, {Color? backgroundColor}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  Future<void> _requestLocation() async {
    if (mounted) {
      setState(() {
        _isLoadingLocation = true;
        _locationError = null;
      });
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setLocationError('Turn on location services to send a dispatch request.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _setLocationError('Location permission is needed to find nearby hospitals.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _setLocationError('Location permission is permanently denied. Enable it in device settings.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
    } catch (_) {
      _setLocationError('Unable to read your current location. Please try again.');
    }
  }

  void _setLocationError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingLocation = false;
      _locationError = message;
    });
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (mounted && (status == 'done' || status == 'notListening')) {
          setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() => _isListening = false);
          _showMessage('Voice input was unavailable. Please type the condition.');
        }
      },
    );
    if (!mounted) {
      return;
    }
    if (!available) {
      _showMessage('Speech recognition is not available on this device.');
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          _conditionController.text = result.recognizedWords;
        }
      },
    );
  }

  Future<void> _requestHospital() async {
    final location = _currentLocation;
    final condition = _conditionController.text.trim();
    if (location == null) {
      _showMessage('Wait for your location before sending a request.');
      return;
    }
    if (condition.isEmpty) {
      _showMessage('Describe the patient condition first.');
      return;
    }
    if (_isSubmitting || _activeRequestId != null) {
      _showMessage('A dispatch request is already active.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final request = await FirebaseFirestore.instance.collection('requests').add({
        'ambulanceId': widget.ambulanceId,
        'condition': condition,
        'ambLat': location.latitude,
        'ambLng': location.longitude,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) {
        return;
      }
      setState(() {
        _activeRequestId = request.id;
        _routePoints = const [];
        _routeDistance = '';
      });
      _watchRequest(request.id);
      _startRequestTimeout(request.id);
      _showMessage('Request sent. Waiting for a nearby hospital.');
    } on FirebaseException {
      _showMessage('Unable to send the request. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _startRequestTimeout(String requestId) {
    _requestTimeout?.cancel();
    _requestTimeout = Timer(const Duration(minutes: 3), () async {
      try {
        final request = await FirebaseFirestore.instance.collection('requests').doc(requestId).get();
        if (mounted && request.data()?['status'] == 'pending') {
          _showMessage(
            'No hospital has accepted yet. Please contact dispatch or try again.',
            backgroundColor: Colors.orange,
          );
        }
      } on FirebaseException {
        // The live listener will surface a later status change if one arrives.
      }
    });
  }

  void _watchRequest(String requestId) {
    _requestSubscription?.cancel();
    _requestSubscription = FirebaseFirestore.instance.collection('requests').doc(requestId).snapshots().listen(
      (snapshot) {
        if (!mounted || !snapshot.exists) {
          return;
        }
        final data = snapshot.data();
        final status = data?['status'];
        if (status == 'accepted') {
          _requestTimeout?.cancel();
          unawaited(_fetchRoute(requestId, data!));
        } else if (status == 'completed') {
          _requestTimeout?.cancel();
          setState(() {
            _activeRequestId = null;
            _routePoints = const [];
            _routeDistance = '';
          });
          _requestSubscription?.cancel();
          _requestSubscription = null;
          _showMessage('Trip completed. The dispatch has been added to history.');
        }
      },
      onError: (_) => _showMessage('Unable to receive dispatch updates.'),
    );
  }

  Future<void> _fetchRoute(String requestId, Map<String, dynamic> request) async {
    final location = _currentLocation;
    final latitude = request['hospLat'];
    final longitude = request['hospLng'];
    if (location == null || latitude is! num || longitude is! num || _isFetchingRoute) {
      return;
    }

    setState(() => _isFetchingRoute = true);
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://router.project-osrm.org/route/v1/driving/'
              '${location.longitude},${location.latitude};${longitude.toDouble()},${latitude.toDouble()}'
              '?overview=full&geometries=geojson',
            ),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw const HttpException('Routing service returned an error.');
      }

      final routeData = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = routeData['routes'];
      if (routes is! List || routes.isEmpty || routes.first is! Map<String, dynamic>) {
        throw const FormatException('No route found.');
      }
      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'];
      final coordinates = geometry is Map<String, dynamic> ? geometry['coordinates'] : null;
      final distance = route['distance'];
      if (coordinates is! List || distance is! num) {
        throw const FormatException('Malformed route.');
      }

      final points = <LatLng>[];
      for (final coordinate in coordinates) {
        if (coordinate is List && coordinate.length >= 2 && coordinate[0] is num && coordinate[1] is num) {
          points.add(LatLng((coordinate[1] as num).toDouble(), (coordinate[0] as num).toDouble()));
        }
      }
      if (points.length < 2) {
        throw const FormatException('Route has too few points.');
      }
      if (!mounted || _activeRequestId != requestId) {
        return;
      }
      setState(() {
        _routePoints = points;
        _routeDistance = '${(distance / 1000).toStringAsFixed(1)} km to hospital';
      });
    } on TimeoutException {
      _showMessage('Routing timed out. The hospital has still accepted your request.');
    } on FormatException {
      _showMessage('The accepted hospital did not provide a valid route.');
    } on HttpException {
      _showMessage('The routing service is temporarily unavailable.');
    } catch (_) {
      _showMessage('Unable to load the route to the hospital.');
    } finally {
      if (mounted) {
        setState(() => _isFetchingRoute = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocation) {
      return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
    }

    final location = _currentLocation;
    if (location == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off, size: 54, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(_locationError ?? 'Location is unavailable.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _requestLocation,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: location, initialZoom: 14),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
            PolylineLayer(
              polylines: [
                Polyline(points: _routePoints, color: Colors.blue, strokeWidth: 4),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: location,
                  child: const Icon(Icons.emergency, color: Colors.redAccent, size: 40),
                ),
              ],
            ),
          ],
        ),
        if (_routeDistance.isNotEmpty)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.green,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Route confirmed: $_routeDistance',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _conditionController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Patient condition',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _toggleVoiceInput,
                      icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                      label: Text(_isListening ? 'Listening… tap to stop' : 'Describe by voice'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _isSubmitting || _activeRequestId != null ? null : _requestHospital,
                    child: Text(
                      _isSubmitting
                          ? 'Sending request…'
                          : _activeRequestId != null
                          ? 'Waiting for hospital…'
                          : 'Find a hospital nearby',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class HospitalBaseNav extends StatefulWidget {
  const HospitalBaseNav({super.key, required this.hospitalId});

  final String hospitalId;

  @override
  State<HospitalBaseNav> createState() => _HospitalBaseNavState();
}

class _HospitalBaseNavState extends State<HospitalBaseNav> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HospitalDashboard(hospitalId: widget.hospitalId),
      HistoryScreen(userId: widget.hospitalId, isAmbulance: false),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Requests'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class HospitalDashboard extends StatefulWidget {
  const HospitalDashboard({super.key, required this.hospitalId});

  final String hospitalId;

  @override
  State<HospitalDashboard> createState() => _HospitalDashboardState();
}

class _HospitalDashboardState extends State<HospitalDashboard> {
  static const _serviceRadiusMetres = 50000.0;

  LatLng? _hospitalLocation;
  bool _isLocating = true;
  bool _isUpdatingRequest = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHospitalLocation());
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _loadHospitalLocation() async {
    if (mounted) {
      setState(() => _isLocating = true);
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() => _hospitalLocation = LatLng(position.latitude, position.longitude));
      }
    } catch (_) {
      // The screen presents a retry action when the location remains unavailable.
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  bool _isNearby(Map<String, dynamic> request) {
    final location = _hospitalLocation;
    final latitude = request['ambLat'];
    final longitude = request['ambLng'];
    if (location == null || latitude is! num || longitude is! num) {
      return false;
    }
    return Geolocator.distanceBetween(
          location.latitude,
          location.longitude,
          latitude.toDouble(),
          longitude.toDouble(),
        ) <=
        _serviceRadiusMetres;
  }

  Future<void> _acceptRequest(String requestId) async {
    final location = _hospitalLocation;
    if (location == null || _isUpdatingRequest) {
      _showMessage('Enable location access before accepting a dispatch.');
      return;
    }

    setState(() => _isUpdatingRequest = true);
    try {
      final request = FirebaseFirestore.instance.collection('requests').doc(requestId);
      final accepted = await FirebaseFirestore.instance.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(request);
        if (!snapshot.exists || snapshot.data()?['status'] != 'pending') {
          return false;
        }
        transaction.update(request, {
          'status': 'accepted',
          'acceptedBy': widget.hospitalId,
          'hospLat': location.latitude,
          'hospLng': location.longitude,
          'acceptedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (!mounted) {
        return;
      }
      _showMessage(accepted ? 'Request accepted. The ambulance is being routed to you.' : 'This request was already taken.');
    } on FirebaseException {
      _showMessage('Unable to accept the request. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isUpdatingRequest = false);
      }
    }
  }

  Future<void> _markCompleted(String requestId) async {
    if (_isUpdatingRequest) {
      return;
    }
    setState(() => _isUpdatingRequest = true);
    try {
      final request = FirebaseFirestore.instance.collection('requests').doc(requestId);
      final completed = await FirebaseFirestore.instance.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(request);
        final data = snapshot.data();
        if (!snapshot.exists || data?['status'] != 'accepted' || data?['acceptedBy'] != widget.hospitalId) {
          return false;
        }
        transaction.update(request, {
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (mounted) {
        _showMessage(completed ? 'Trip marked as complete.' : 'This trip can no longer be completed.');
      }
    } on FirebaseException {
      _showMessage('Unable to complete the trip. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isUpdatingRequest = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby dispatches'),
        actions: [
          IconButton(
            tooltip: 'Refresh hospital location',
            onPressed: _isLocating ? null : _loadHospitalLocation,
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: _isLocating
          ? const Center(child: CircularProgressIndicator())
          : _hospitalLocation == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_off, size: 52, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    const Text(
                      'Location access is required to receive nearby dispatches.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _loadHospitalLocation,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('requests')
                  .where('status', whereIn: ['pending', 'accepted'])
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Unable to load dispatch requests.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final requests = snapshot.data!.docs.where((request) {
                  final data = request.data();
                  if (data['status'] == 'accepted') {
                    return data['acceptedBy'] == widget.hospitalId;
                  }
                  return _isNearby(data);
                }).toList();
                if (requests.isEmpty) {
                  return const Center(child: Text('No nearby active requests.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    final data = request.data();
                    final accepted = data['status'] == 'accepted';
                    return Card(
                      color: accepted ? Colors.green.shade50 : null,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ambulance: ${data['ambulanceId'] ?? 'Unknown'}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text('Condition: ${data['condition'] ?? 'Not specified'}'),
                            const SizedBox(height: 14),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: accepted ? Colors.blue : Colors.green,
                              ),
                              onPressed: _isUpdatingRequest
                                  ? null
                                  : () => accepted ? _markCompleted(request.id) : _acceptRequest(request.id),
                              child: Text(accepted ? 'Patient arrived — complete trip' : 'Accept request'),
                            ),
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

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.userId, required this.isAmbulance});

  final String userId;
  final bool isAmbulance;

  @override
  Widget build(BuildContext context) {
    final fieldToQuery = isAmbulance ? 'ambulanceId' : 'acceptedBy';
    return Scaffold(
      appBar: AppBar(title: const Text('Trip history')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('requests')
            .where(fieldToQuery, isEqualTo: userId)
            .where('status', isEqualTo: 'completed')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load trip history.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snapshot.data!.docs;
          if (requests.isEmpty) {
            return const Center(child: Text('No completed trips yet.'));
          }
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final data = requests[index].data();
              final counterpart = isAmbulance ? data['acceptedBy'] : data['ambulanceId'];
              return ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(data['condition']?.toString() ?? 'Patient condition not recorded'),
                subtitle: Text(isAmbulance ? 'Delivered to: $counterpart' : 'From: $counterpart'),
              );
            },
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
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('AROVA emergency response network'),
            subtitle: Text('Keep location permission enabled for live dispatch.'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log out', style: TextStyle(color: Colors.red)),
            onTap: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
              (route) => false,
            ),
          ),
        ],
      ),
    );
  }
}
