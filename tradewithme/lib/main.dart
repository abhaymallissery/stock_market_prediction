import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:candlesticks/candlesticks.dart';
import 'learn.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoftTrade AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF2F5F8),
        primaryColor: const Color(0xFF2D3142),
        cardColor: Colors.white,
        textTheme: GoogleFonts.poppinsTextTheme(),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // CONFIG: CHANGE THIS TO YOUR LOCAL IP IF TESTING ON REAL DEVICE
  // For Emulator use: "http://10.0.2.2:5000"
  final String baseUrl = "http://172.26.160.236:5000"; 
  final TextEditingController _searchController = TextEditingController(text: "AAPL");

  // STATE VARIABLES
  Map<String, dynamic>? liveData;
  Map<String, dynamic>? aiData;
  List<Candle> candles = [];
  bool isLoadingChart = false;
  bool isPredicting = false;
  String selectedInterval = "1d";
  int _selectedIndex = 0; // For mobile bottom nav

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  void _loadAllData() {
    fetchLive();
    fetchHistory();
  }

  // --- API CALLS ---
  Future<void> fetchLive() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/live?symbol=${_searchController.text}"));
      if (res.statusCode == 200) {
        setState(() => liveData = json.decode(res.body));
      }
    } catch (e) {
      debugPrint("Live Error: $e");
    }
  }

  Future<void> fetchHistory() async {
    if (!mounted) return;
    setState(() => isLoadingChart = true);
    try {
      final res = await http.get(Uri.parse("$baseUrl/history?symbol=${_searchController.text}&interval=$selectedInterval"));
      if (res.statusCode == 200) {
        List<dynamic> data = json.decode(res.body);
        setState(() {
          candles = data.map((e) => Candle(
            date: DateTime.fromMillisecondsSinceEpoch(e['date']),
            high: (e['high'] as num).toDouble(),
            low: (e['low'] as num).toDouble(),
            open: (e['open'] as num).toDouble(),
            close: (e['close'] as num).toDouble(),
            volume: (e['volume'] as num).toDouble(),
          )).toList().reversed.toList();
        });
      }
    } catch (e) {
      debugPrint("History Error: $e");
    }
    if (mounted) setState(() => isLoadingChart = false);
  }

  Future<void> fetchPrediction() async {
    setState(() => isPredicting = true);
    try {
      final res = await http.get(Uri.parse("$baseUrl/predict?symbol=${_searchController.text}"));
      if (res.statusCode == 200) {
        setState(() => aiData = json.decode(res.body));
      }
    } catch (e) {
      debugPrint("Prediction Error: $e");
    }
    setState(() => isPredicting = false);
  }

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder to decide between Mobile and Desktop
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return _buildMobileLayout();
        } else {
          return _buildDesktopLayout();
        }
      },
    );
  }

  // --- MOBILE LAYOUT ---
  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: "Search (e.g. TSLA)",
            border: InputBorder.none,
            suffixIcon: Icon(Icons.search, color: Color(0xFFFFA726)),
          ),
          onSubmitted: (value) => _loadAllData(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildLivePriceCard(),
              const SizedBox(height: 16),
              // Fixed height for chart in scroll view
              SizedBox(height: 400, child: _buildChartCard(isMobile: true)),
              const SizedBox(height: 16),
              _buildAIPredictionCard(),
              const SizedBox(height: 16),
              _buildActionButtons(),
              const SizedBox(height: 16),
              // Give the list a fixed height or use shrinkwrap logic
              SizedBox(height: 300, child: _buildEventsList()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFFFA726),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 1) {
             Navigator.push(context, MaterialPageRoute(builder: (_) => const LearningTradingComingSoon()));
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Dash"),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: "Learn"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }

  // --- DESKTOP LAYOUT (Your Original Design) ---
  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              Expanded(flex: 3, child: _buildChartCard()),
                              const SizedBox(height: 20),
                              Expanded(flex: 2, child: _buildEventsList()),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              _buildLivePriceCard(),
                              const SizedBox(height: 20),
                              _buildAIPredictionCard(),
                              const SizedBox(height: 20),
                              _buildActionButtons(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildSidebar() {
    return Container(
      width: 80,
      margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Icon(Icons.show_chart, color: Color(0xFF2D3142), size: 30),
          Column(
            children: [
              _sidebarIcon(Icons.dashboard_rounded, true),
              _sidebarIcon(
                Icons.school_rounded,
                false,
                color: Colors.blueAccent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LearningTradingComingSoon(),
                    ),
                  );
                },
              ),
              _sidebarIcon(Icons.pie_chart_rounded, false),
              _sidebarIcon(Icons.settings_rounded, false),
            ],
          ),
          const CircleAvatar(
            backgroundImage: NetworkImage("https://i.pravatar.cc/100?img=33"),
            radius: 20,
          ),
        ],
      ),
    );
  }

  Widget _sidebarIcon(IconData icon, bool isActive, {VoidCallback? onTap, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Icon(
          icon,
          color: isActive ? const Color(0xFFFFA726) : color ?? Colors.grey[400],
          size: 26,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Dashboard", style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF2D3142))),
            Text("Real-time AI Market Analysis", style: GoogleFonts.poppins(color: Colors.grey[500])),
          ],
        ),
        Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10)],
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search Symbol (e.g. TSLA)",
              border: InputBorder.none,
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: Color(0xFFFFA726)),
                onPressed: _loadAllData,
              ),
            ),
            onSubmitted: (value) => _loadAllData(),
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard({bool isMobile = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Market Overview", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
              DropdownButton<String>(
                value: selectedInterval,
                underline: Container(),
                items: ["15m", "1h", "1d", "1wk"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) {
                  setState(() => selectedInterval = v!);
                  fetchHistory();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: isLoadingChart
                ? const Center(child: CircularProgressIndicator())
                : candles.isEmpty 
                  ? const Center(child: Text("No data found"))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        color: const Color(0xFF1E222D),
                        child: Candlesticks(candles: candles),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePriceCard() {
    if (liveData == null) return const SizedBox.shrink();
    bool isUp = (liveData!['change'] ?? 0) >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Current Price", style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12)),
          const SizedBox(height: 4),
          Text("\$${liveData!['price']}", style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isUp ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${isUp ? '+' : ''}${liveData!['change']} (${liveData!['pct_change']}%)",
                  style: TextStyle(color: isUp ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              Text("RSI: ${liveData!['rsi']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAIPredictionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D3142),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF2D3142).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("AI Signal", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                child: const Icon(Icons.auto_awesome, color: Color(0xFFFFA726), size: 16),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (isPredicting)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (aiData == null)
            Center(child: TextButton(onPressed: fetchPrediction, child: const Text("Tap to Predict", style: TextStyle(color: Colors.white))))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(aiData!['signal'],
                        style: GoogleFonts.poppins(
                            color: aiData!['signal'] == "BUY" ? Colors.greenAccent : Colors.redAccent,
                            fontSize: 28,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                  ],
                ),
                const SizedBox(height: 5),
                // --- NEW CODE STARTS HERE ---
                Row(
                  children: [
                    // Target Price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Target", style: TextStyle(color: Colors.white38, fontSize: 10)),
                        Text("\$${aiData!['target']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Container(width: 1, height: 30, color: Colors.white10), // Divider
                    const SizedBox(width: 20),
                    // Stop Loss Price (Added)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Stop Loss", style: TextStyle(color: Colors.white38, fontSize: 10)),
                        Text("\$${aiData!['stop_loss']}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                // --- NEW CODE ENDS HERE ---
                
                const SizedBox(height: 15),
                LinearProgressIndicator(
                  value: (aiData!['confidence'] ?? 0) / 100,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFA726)),
                ),
                const SizedBox(height: 5),
                Text("Confidence: ${aiData!['confidence']}%", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                const SizedBox(height: 10),
                if (aiData!['metrics'] != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _metricRow("Model Accuracy", "${aiData!['metrics']['accuracy']}%"),
                        _metricRow("RMSE Error", "₹${aiData!['metrics']['rmse']}"),
                        _metricRow("F1 Score", "${aiData!['metrics']['f1_score']}"),
                      ],
                    ),
                  )
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: fetchPrediction,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2D3142),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: const Text("+ Run Prediction", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEventsList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Watchlist & Events", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
              Icon(Icons.more_horiz, color: Colors.grey[400]),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                _eventItem("NVDA", "Nvidia Corp", "Earnings Call", "Today, 4:00 PM", Colors.purpleAccent),
                _eventItem("BTC", "Bitcoin", "Crypto Volatility", "Live", Colors.orangeAccent),
                _eventItem("TSLA", "Tesla Inc", "Cybertruck News", "Yesterday", Colors.blueAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventItem(String symbol, String name, String event, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(symbol[0], style: TextStyle(color: color, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              Text("$name • $time", style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey[200]!)),
            child: Icon(Icons.check, size: 14, color: Colors.green[300]),
          )
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}