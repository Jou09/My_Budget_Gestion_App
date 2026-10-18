import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const _ink = Color(0xFF2B211C);
const _wood = Color(0xFF49352B);
const _cream = Color(0xFFF5F0E8);
const _paper = Color(0xFFFFFCF7);
const _teal = Color(0xFF087C78);
const _gold = Color(0xFFD4A15D);
const _muted = Color(0xFF86786F);
const _red = Color(0xFFB65343);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  runApp(const BudgetApp());
}

class BudgetApp extends StatefulWidget {
  const BudgetApp({super.key});

  @override
  State<BudgetApp> createState() => _BudgetAppState();
}

class _BudgetAppState extends State<BudgetApp> with WidgetsBindingObserver {
  static const _vault = FlutterSecureStorage();
  bool _ready = false;
  bool _hasPin = false;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    final pin = await _vault.read(key: 'app_pin');
    if (!mounted) return;
    setState(() {
      _hasPin = pin != null;
      _ready = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (_unlocked && mounted) setState(() => _unlocked = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _authenticated() => setState(() {
        _hasPin = true;
        _unlocked = true;
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mon Budget Étudiant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _cream,
        colorScheme: ColorScheme.fromSeed(seedColor: _teal, brightness: Brightness.light)
            .copyWith(primary: _teal, secondary: _gold, surface: _paper),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(backgroundColor: _cream, foregroundColor: _ink),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _cream,
          hintStyle: const TextStyle(color: _muted),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
      ),
      home: !_ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator(color: _teal)))
          : _unlocked
              ? BudgetHome(onLock: () => setState(() => _unlocked = false))
              : AuthScreen(isSetup: !_hasPin, onAuthenticated: _authenticated),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.isSetup, required this.onAuthenticated, super.key});

  final bool isSetup;
  final VoidCallback onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _vault = FlutterSecureStorage();
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      if (widget.isSetup) {
        if (pin.length < 4 || pin.length > 8 || int.tryParse(pin) == null) {
          setState(() => _error = 'Choisis un code PIN de 4 à 8 chiffres.');
          return;
        }
        if (pin != _confirmController.text.trim()) {
          setState(() => _error = 'Les deux codes ne correspondent pas.');
          return;
        }
        await _vault.write(key: 'app_pin', value: pin);
      } else {
        final savedPin = await _vault.read(key: 'app_pin');
        if (savedPin == null || pin != savedPin) {
          setState(() => _error = 'Code incorrect. Réessaie.');
          return;
        }
      }
      widget.onAuthenticated();
    } catch (_) {
      setState(() => _error = 'Le coffre sécurisé est indisponible sur cet appareil.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSetup = widget.isSetup;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/wallet_background.jpg', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66201510), Color(0xD9201510), Color(0xF2201510)],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(26),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFF1C887), size: 50),
                      const SizedBox(height: 13),
                      const Text('MON BUDGET', textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 15, letterSpacing: 4, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 38),
                      Text(isSetup ? 'Crée ton code secret' : 'Content de te revoir',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(isSetup ? 'Tes dépenses restent sur cet appareil.' : 'Entre ton code pour accéder à ton budget.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFE5D9CD), fontSize: 14)),
                      const SizedBox(height: 28),
                      _pinField(_pinController, isSetup ? 'Nouveau code PIN' : 'Code PIN'),
                      if (isSetup) ...[
                        const SizedBox(height: 12),
                        _pinField(_confirmController, 'Confirmer le code PIN'),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFFFFB9A9), fontWeight: FontWeight.w600)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE0B678), foregroundColor: _ink,
                          minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: _busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(isSetup ? 'Continuer' : 'Déverrouiller', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 18),
                      const Text('Protégé par un code PIN · Données conservées hors ligne',
                          textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFD7C7B8), fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pinField(TextEditingController controller, String hint) => TextField(
        controller: controller,
        obscureText: true,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 8,
        style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 8),
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          hintStyle: const TextStyle(color: Color(0xBFFFFFFF), fontSize: 14, letterSpacing: 0),
          filled: true,
          fillColor: const Color(0x55201611),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: Color(0x66FFFFFF))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: Color(0xFFE0B678), width: 1.5)),
        ),
      );
}

class BudgetHome extends StatefulWidget {
  const BudgetHome({required this.onLock, super.key});
  final VoidCallback onLock;

  @override
  State<BudgetHome> createState() => _BudgetHomeState();
}

class _BudgetHomeState extends State<BudgetHome> {
  int _tab = 0;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late Future<MonthData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<MonthData> _load() async => BudgetStore.instance.monthData(_month);

  void _refresh() => setState(() => _data = _load());

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _data = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('MON BUDGET', style: TextStyle(fontSize: 11, letterSpacing: 2.2, fontWeight: FontWeight.w800, color: _muted)),
          Text(_tab == 0 ? 'Vue d’ensemble' : _tab == 1 ? 'Mouvements' : 'Charges fixes',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
        ]),
        actions: [
          IconButton(tooltip: 'Verrouiller', onPressed: widget.onLock,
              icon: const Icon(Icons.lock_outline_rounded, color: _wood)),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<MonthData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: _teal));
          }
          if (snapshot.hasError) return Center(child: Text('Impossible de lire les données.\n${snapshot.error}', textAlign: TextAlign.center));
          final data = snapshot.data!;
          return IndexedStack(
            index: _tab,
            children: [
              _dashboard(data),
              _movements(data),
              _charges(data),
            ],
          );
        },
      ),
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(
              onPressed: () => _showMovementDialog(),
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        backgroundColor: _paper,
        indicatorColor: _teal.withOpacity(.12),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard_rounded), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Mouvements'),
          NavigationDestination(icon: Icon(Icons.event_repeat_outlined), selectedIcon: Icon(Icons.event_repeat_rounded), label: 'Charges'),
        ],
      ),
    );
  }

  Widget _dashboard(MonthData data) {
    return RefreshIndicator(
      color: _teal,
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 110),
        children: [
          _monthPicker(),
          const SizedBox(height: 14),
          _balanceCard(data),
          const SizedBox(height: 15),
          Row(children: [
            Expanded(child: _metricCard('Revenus reçus', data.income, Icons.south_west_rounded, _teal)),
            const SizedBox(width: 12),
            Expanded(child: _metricCard('Dépenses', data.spent, Icons.north_east_rounded, _red)),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(color: _paper, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFECE3D8))),
            child: Row(children: [
              const Icon(Icons.today_rounded, color: _gold, size: 20),
              const SizedBox(width: 10),
              const Expanded(child: Text('Dépenses aujourd’hui', style: TextStyle(color: _wood, fontWeight: FontWeight.w700, fontSize: 13))),
              Text(_money(data.todaySpent), style: const TextStyle(color: _ink, fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Ce mois-ci', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
            Text('${data.movements.length} mouvement${data.movements.length == 1 ? '' : 's'}', style: const TextStyle(color: _muted, fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          if (data.charges.isNotEmpty) _pendingChargeCard(data),
          if (data.movements.isEmpty)
            _emptyCard('Pas encore de mouvement', 'Ajoute ton argent reçu ou une dépense pour commencer.', Icons.savings_outlined)
          else ...[
            for (final movement in data.movements.take(5)) _movementTile(movement),
            if (data.movements.length > 5)
              TextButton(onPressed: () => setState(() => _tab = 1), child: const Text('Voir tout l’historique')),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _quickAction('Ajouter une dépense', Icons.add_circle_outline, () => _showMovementDialog(kind: 'expense'))),
            const SizedBox(width: 10),
            Expanded(child: _quickAction('Enregistrer un revenu', Icons.add_card_outlined, () => _showMovementDialog(kind: 'income'))),
          ]),
        ],
      ),
    );
  }

  Widget _monthPicker() => Row(children: [
        IconButton(onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(child: Text(_monthLabel(_month), textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _wood))),
        IconButton(onPressed: () => _shiftMonth(1), icon: const Icon(Icons.chevron_right_rounded)),
      ]);

  Widget _balanceCard(MonthData data) => Container(
        height: 186,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), color: _wood),
        child: Stack(fit: StackFit.expand, children: [
          Image.asset('assets/images/wallet_background.jpg', fit: BoxFit.cover, alignment: Alignment.centerRight),
          const DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight,
                colors: [Color(0xF126201A), Color(0xDD26201A), Color(0x8826201A)]))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFE0B678), size: 19), SizedBox(width: 8),
                Text('ARGENT DISPONIBLE', style: TextStyle(color: Color(0xFFE5D9CD), fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w700))]),
              const Spacer(),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                child: Text(_money(data.remaining), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800))),
              const SizedBox(height: 5),
              Text(data.pendingFixed > 0 ? '${_money(data.pendingFixed)} de charges fixes restent à payer' : 'Tes charges fixes sont à jour',
                  style: const TextStyle(color: Color(0xFFE5D9CD), fontSize: 12)),
            ]),
          ),
        ]),
      );

  Widget _metricCard(String label, int amount, IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: _paper, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFECE3D8))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 11),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(_money(amount), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _ink))),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
        ]),
      );

  Widget _pendingChargeCard(MonthData data) => Container(
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: const Color(0xFFFFF4E2), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFF0D9B5))),
        child: Row(children: [
          const Icon(Icons.event_note_rounded, color: _wood),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Charges fixes prévues', style: TextStyle(color: _wood, fontWeight: FontWeight.w700)),
            Text('${data.unpaidCharges.length} à régler · ${_money(data.pendingFixed)}', style: const TextStyle(color: _muted, fontSize: 12)),
          ])),
          IconButton(onPressed: () => setState(() => _tab = 2), icon: const Icon(Icons.arrow_forward_rounded, color: _wood)),
        ]),
      );

  Widget _movements(MonthData data) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
        children: [
          _monthPicker(),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: _paper, borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Expanded(child: _smallSummary('Revenus', data.income, _teal)),
              Container(width: 1, height: 38, color: const Color(0xFFECE3D8)),
              Expanded(child: _smallSummary('Dépenses', data.spent, _red)),
            ])),
          const SizedBox(height: 15),
          if (data.movements.isEmpty)
            _emptyCard('Aucun mouvement ce mois', 'Les dépenses et revenus ajoutés apparaîtront ici.', Icons.receipt_long_outlined)
          else for (final movement in data.movements) _movementTile(movement, canDelete: true),
        ],
      );

  Widget _smallSummary(String label, int value, Color color) => Column(children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 5),
        FittedBox(child: Text(_money(value), style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800))),
      ]);

  Widget _charges(MonthData data) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          _monthPicker(),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: _teal, borderRadius: BorderRadius.circular(22)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('À prévoir ce mois', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 5),
              Text(_money(data.pendingFixed), style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('${data.unpaidCharges.length} charge${data.unpaidCharges.length == 1 ? '' : 's'} en attente', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Mes charges récurrentes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
            TextButton.icon(onPressed: _showChargeDialog, icon: const Icon(Icons.add, size: 18), label: const Text('Ajouter')),
          ]),
          if (data.charges.isEmpty)
            _emptyCard('Aucune charge enregistrée', 'Ajoute ton loyer, internet, téléphone ou toute autre dépense mensuelle fixe.', Icons.event_repeat_outlined)
          else
            for (final charge in data.charges)
              _chargeTile(charge, data),
        ],
      );

  Widget _chargeTile(Charge charge, MonthData data) {
    final paid = data.paidChargeIds.contains(charge.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _paper, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE3D8))),
      child: Row(children: [
        CircleAvatar(backgroundColor: paid ? _teal.withOpacity(.12) : const Color(0xFFF5EBD9),
            child: Icon(_categoryIcon(charge.category), color: paid ? _teal : _wood, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(charge.title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text('Le ${charge.dueDay} · ${charge.category}', style: const TextStyle(color: _muted, fontSize: 12)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_money(charge.amount), style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 4),
          paid
              ? const Text('Payé', style: TextStyle(color: _teal, fontSize: 11, fontWeight: FontWeight.w700))
              : InkWell(onTap: () => _markChargePaid(charge), child: const Text('Marquer payé', style: TextStyle(color: _teal, fontSize: 11, fontWeight: FontWeight.w700))),
        ]),
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'delete') {
              await BudgetStore.instance.deleteCharge(charge.id);
              _refresh();
            } else if (value == 'edit') {
              _showChargeDialog(charge: charge);
            }
          },
          itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Modifier')), PopupMenuItem(value: 'delete', child: Text('Supprimer'))],
        ),
      ]),
    );
  }

  Widget _movementTile(Movement movement, {bool canDelete = false}) => Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(color: _paper, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFECE3D8))),
        child: Row(children: [
          CircleAvatar(backgroundColor: movement.kind == 'income' ? _teal.withOpacity(.12) : const Color(0xFFF4E7DC),
              child: Icon(_categoryIcon(movement.category), size: 19, color: movement.kind == 'income' ? _teal : _wood)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(movement.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text('${movement.category} · ${_dayLabel(movement.date)}', style: const TextStyle(color: _muted, fontSize: 11)),
          ])),
          Text('${movement.kind == 'income' ? '+' : '−'} ${_money(movement.amount)}',
              style: TextStyle(color: movement.kind == 'income' ? _teal : _ink, fontWeight: FontWeight.w800, fontSize: 13)),
          if (canDelete)
            IconButton(icon: const Icon(Icons.delete_outline, size: 19, color: _muted), onPressed: () async {
              await BudgetStore.instance.deleteMovement(movement.id);
              _refresh();
            }),
        ]),
      );

  Widget _emptyCard(String title, String subtitle, IconData icon) => Container(
        margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        decoration: BoxDecoration(color: _paper, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE3D8))),
        child: Column(children: [Icon(icon, size: 35, color: _gold), const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 5), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 12, height: 1.4))]),
      );

  Widget _quickAction(String label, IconData icon, VoidCallback onPressed) => OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(foregroundColor: _teal, side: const BorderSide(color: Color(0xFFCADBD7)),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        icon: Icon(icon, size: 18), label: Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
      );

  Future<void> _showMovementDialog({String? kind}) async {
    final title = TextEditingController();
    final amount = TextEditingController();
    var selectedKind = kind ?? 'expense';
    var category = selectedKind == 'income' ? 'Argent reçu' : 'Repas';
    final categories = ['Repas', 'Transport', 'Courses', 'Logement', 'Études', 'Santé', 'Loisirs', 'Autre'];
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        backgroundColor: _paper,
        title: Text(selectedKind == 'income' ? 'Enregistrer un revenu' : 'Ajouter une dépense', style: const TextStyle(color: _ink, fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'expense', label: Text('Dépense'), icon: Icon(Icons.north_east)), ButtonSegment(value: 'income', label: Text('Revenu'), icon: Icon(Icons.south_west))],
            selected: {selectedKind},
            onSelectionChanged: (value) => setDialogState(() {
              selectedKind = value.first;
              category = selectedKind == 'income' ? 'Argent reçu' : 'Repas';
            }),
          ),
          const SizedBox(height: 14),
          TextField(controller: title, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: selectedKind == 'income' ? 'Source (ex. allocation)' : 'Description (ex. déjeuner)')),
          const SizedBox(height: 10),
          TextField(controller: amount, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Montant', suffixText: 'Ar')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'Catégorie'),
            items: (selectedKind == 'income' ? ['Argent reçu', 'Bourse', 'Aide familiale', 'Autre revenu'] : categories)
                .map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
            onChanged: (value) => setDialogState(() => category = value ?? category)),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer'))],
      )),
    );
    if (saved == true) {
      final parsedAmount = int.tryParse(amount.text);
      if (title.text.trim().isEmpty || parsedAmount == null || parsedAmount <= 0) {
        _notice('Saisis une description et un montant valide.');
      } else {
        await BudgetStore.instance.addMovement(MovementDraft(
          title: title.text.trim(), category: category, amount: parsedAmount, kind: selectedKind,
          date: DateTime(_month.year, _month.month, _month.year == DateTime.now().year && _month.month == DateTime.now().month ? DateTime.now().day : 1),
        ));
        _refresh();
      }
    }
    title.dispose();
    amount.dispose();
  }

  Future<void> _showChargeDialog({Charge? charge}) async {
    final title = TextEditingController(text: charge?.title ?? '');
    final amount = TextEditingController(text: charge?.amount.toString() ?? '');
    final dueDay = TextEditingController(text: (charge?.dueDay ?? 1).toString());
    var category = charge?.category ?? 'Logement';
    const categories = ['Logement', 'Internet', 'Téléphone', 'Études', 'Transport', 'Autre'];
    final saved = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      backgroundColor: _paper,
      title: Text(charge == null ? 'Nouvelle charge fixe' : 'Modifier la charge', style: const TextStyle(color: _ink, fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nom (ex. loyer)')),
        const SizedBox(height: 10),
        TextField(controller: amount, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Montant mensuel', suffixText: 'Ar')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'Catégorie'),
          items: categories.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) => setDialogState(() => category = value ?? category)),
        const SizedBox(height: 10),
        TextField(controller: dueDay, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Jour d’échéance (1 à 31)')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer'))],
    )));
    if (saved == true) {
      final value = int.tryParse(amount.text);
      final day = int.tryParse(dueDay.text);
      if (title.text.trim().isEmpty || value == null || value <= 0 || day == null || day < 1 || day > 31) {
        _notice('Vérifie le nom, le montant et le jour d’échéance.');
      } else {
        await BudgetStore.instance.saveCharge(ChargeDraft(id: charge?.id, title: title.text.trim(), amount: value, dueDay: day, category: category));
        _refresh();
      }
    }
    title.dispose();
    amount.dispose();
    dueDay.dispose();
  }

  Future<void> _markChargePaid(Charge charge) async {
    await BudgetStore.instance.payCharge(charge, _month);
    _refresh();
    if (mounted) _notice('${charge.title} marqué comme payé.');
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }
}

class BudgetStore {
  BudgetStore._();
  static final instance = BudgetStore._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final root = await getDatabasesPath();
    _database = await openDatabase(p.join(root, 'budget_etudiant.db'), version: 1,
        onCreate: (db, version) async {
      await db.execute('''CREATE TABLE movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        amount INTEGER NOT NULL,
        kind TEXT NOT NULL,
        created_at TEXT NOT NULL,
        fixed_id INTEGER
      )''');
      await db.execute('''CREATE TABLE charges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        amount INTEGER NOT NULL,
        due_day INTEGER NOT NULL,
        active INTEGER NOT NULL DEFAULT 1
      )''');
      await db.execute('''CREATE TABLE charge_payments (
        charge_id INTEGER NOT NULL,
        month_key TEXT NOT NULL,
        movement_id INTEGER NOT NULL,
        PRIMARY KEY (charge_id, month_key)
      )''');
    });
    return _database!;
  }

  Future<MonthData> monthData(DateTime month) async {
    final db = await database;
    final monthKey = _monthKey(month);
    final start = DateTime(month.year, month.month, 1).toIso8601String();
    final end = DateTime(month.year, month.month + 1, 1).toIso8601String();
    final rawMovements = await db.query('movements', where: 'created_at >= ? AND created_at < ?', whereArgs: [start, end], orderBy: 'created_at DESC, id DESC');
    final rawCharges = await db.query('charges', where: 'active = 1', orderBy: 'due_day ASC, id ASC');
    final rawPayments = await db.query('charge_payments', where: 'month_key = ?', whereArgs: [monthKey]);
    final movements = rawMovements.map(Movement.fromMap).toList();
    final charges = rawCharges.map(Charge.fromMap).toList();
    final paid = rawPayments.map((row) => row['charge_id'] as int).toSet();
    final income = movements.where((m) => m.kind == 'income').fold<int>(0, (sum, m) => sum + m.amount);
    final spent = movements.where((m) => m.kind == 'expense').fold<int>(0, (sum, m) => sum + m.amount);
    final today = DateTime.now();
    final todaySpent = today.year == month.year && today.month == month.month
        ? movements.where((m) => m.kind == 'expense' && m.date.year == today.year && m.date.month == today.month && m.date.day == today.day)
            .fold<int>(0, (sum, m) => sum + m.amount)
        : 0;
    final unpaid = charges.where((charge) => !paid.contains(charge.id)).toList();
    final pending = unpaid.fold<int>(0, (sum, charge) => sum + charge.amount);
    return MonthData(income: income, spent: spent, todaySpent: todaySpent, pendingFixed: pending, remaining: income - spent - pending,
        movements: movements, charges: charges, unpaidCharges: unpaid, paidChargeIds: paid);
  }

  Future<void> addMovement(MovementDraft draft, {int? fixedId}) async {
    final db = await database;
    await db.insert('movements', {
      'title': draft.title, 'category': draft.category, 'amount': draft.amount, 'kind': draft.kind,
      'created_at': draft.date.toIso8601String(), 'fixed_id': fixedId,
    });
  }

  Future<void> deleteMovement(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('charge_payments', where: 'movement_id = ?', whereArgs: [id]);
      await txn.delete('movements', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> saveCharge(ChargeDraft draft) async {
    final db = await database;
    final values = {'title': draft.title, 'category': draft.category, 'amount': draft.amount, 'due_day': draft.dueDay, 'active': 1};
    if (draft.id == null) {
      await db.insert('charges', values);
    } else {
      await db.update('charges', values, where: 'id = ?', whereArgs: [draft.id]);
    }
  }

  Future<void> deleteCharge(int id) async {
    final db = await database;
    await db.delete('charges', where: 'id = ?', whereArgs: [id]);
    await db.delete('charge_payments', where: 'charge_id = ?', whereArgs: [id]);
  }

  Future<void> payCharge(Charge charge, DateTime month) async {
    final db = await database;
    final monthKey = _monthKey(month);
    await db.transaction((txn) async {
      final alreadyPaid = await txn.query('charge_payments', where: 'charge_id = ? AND month_key = ?', whereArgs: [charge.id, monthKey], limit: 1);
      if (alreadyPaid.isNotEmpty) return;
      final lastDay = DateTime(month.year, month.month + 1, 0).day;
      final dueDate = DateTime(month.year, month.month, charge.dueDay > lastDay ? lastDay : charge.dueDay);
      final movementId = await txn.insert('movements', {
        'title': charge.title, 'category': charge.category, 'amount': charge.amount, 'kind': 'expense',
        'created_at': dueDate.toIso8601String(), 'fixed_id': charge.id,
      });
      await txn.insert('charge_payments', {'charge_id': charge.id, 'month_key': monthKey, 'movement_id': movementId});
    });
  }
}

class MonthData {
  const MonthData({required this.income, required this.spent, required this.todaySpent, required this.pendingFixed, required this.remaining,
    required this.movements, required this.charges, required this.unpaidCharges, required this.paidChargeIds});
  final int income;
  final int spent;
  final int todaySpent;
  final int pendingFixed;
  final int remaining;
  final List<Movement> movements;
  final List<Charge> charges;
  final List<Charge> unpaidCharges;
  final Set<int> paidChargeIds;
}

class Movement {
  const Movement({required this.id, required this.title, required this.category, required this.amount, required this.kind, required this.date});
  final int id;
  final String title;
  final String category;
  final int amount;
  final String kind;
  final DateTime date;
  factory Movement.fromMap(Map<String, Object?> row) => Movement(
    id: row['id'] as int, title: row['title'] as String, category: row['category'] as String,
    amount: row['amount'] as int, kind: row['kind'] as String, date: DateTime.parse(row['created_at'] as String));
}

class MovementDraft {
  const MovementDraft({required this.title, required this.category, required this.amount, required this.kind, required this.date});
  final String title;
  final String category;
  final int amount;
  final String kind;
  final DateTime date;
}

class Charge {
  const Charge({required this.id, required this.title, required this.category, required this.amount, required this.dueDay});
  final int id;
  final String title;
  final String category;
  final int amount;
  final int dueDay;
  factory Charge.fromMap(Map<String, Object?> row) => Charge(
    id: row['id'] as int, title: row['title'] as String, category: row['category'] as String,
    amount: row['amount'] as int, dueDay: row['due_day'] as int);
}

class ChargeDraft {
  const ChargeDraft({this.id, required this.title, required this.category, required this.amount, required this.dueDay});
  final int? id;
  final String title;
  final String category;
  final int amount;
  final int dueDay;
}

String _monthKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

String _money(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return '${amount < 0 ? '−' : ''}${buffer.toString()} Ar';
}

String _monthLabel(DateTime date) {
  const names = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
  return '${names[date.month - 1][0].toUpperCase()}${names[date.month - 1].substring(1)} ${date.year}';
}

String _dayLabel(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

IconData _categoryIcon(String category) {
  switch (category) {
    case 'Repas': return Icons.restaurant_rounded;
    case 'Transport': return Icons.directions_bus_filled_rounded;
    case 'Logement': return Icons.home_rounded;
    case 'Internet': return Icons.wifi_rounded;
    case 'Téléphone': return Icons.phone_android_rounded;
    case 'Études': return Icons.menu_book_rounded;
    case 'Courses': return Icons.shopping_basket_rounded;
    case 'Santé': return Icons.health_and_safety_rounded;
    case 'Loisirs': return Icons.sports_esports_rounded;
    case 'Argent reçu':
    case 'Bourse':
    case 'Aide familiale': return Icons.account_balance_wallet_rounded;
    default: return Icons.payments_rounded;
  }
}
