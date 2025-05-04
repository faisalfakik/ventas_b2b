// lib/screens/vendor_dashboard/vendor_dashboard_screen.dart

// --- Framework & Packages ---
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- ViewModel ---
import 'viewmodels/vendor_dashboard_viewmodel.dart';

// --- Modelos ---
import 'package:ventas_b2b/models/customer_model.dart' as cust;
import 'package:ventas_b2b/models/vendor_model.dart' as vend;
import '../../../models/visit_model.dart';
import '../../../models/sales_goal_model.dart';

// --- Helpers/Utils ---
import '../../../utils/helpers.dart';

// --- Widgets Separados ---
import 'widgets/vendor_info_card.dart';
import 'widgets/sales_goal_card.dart';
import 'widgets/stats_panel.dart';
import 'widgets/section_header.dart';
import 'widgets/filter_chips.dart';
import 'widgets/visit_list.dart';
import 'widgets/customer_list.dart';
import 'widgets/error_widgets.dart';

// --- Otras Pantallas (Navegación) ---
import '../customer_detail_screen.dart';
import '../visit_detail_screen.dart';
import '../schedule_visit_screen.dart';
import '../vendor_tools_screen.dart';

// --- Widget Principal (Proveedor del ViewModel) ---
class VendorDashboardScreen extends StatelessWidget {
  final String vendorId;
  const VendorDashboardScreen({super.key, required this.vendorId});

  @override
  Widget build(BuildContext context) {
    // Crea e inyecta el ViewModel usando ChangeNotifierProvider
    return ChangeNotifierProvider(
      create: (_) {
        debugPrint("🔍 PROVIDER: Creando VendorDashboardViewModel...");
        return VendorDashboardViewModel(vendorId: vendorId);
      },
      // El child es la vista real que consumirá el ViewModel
      child: const _VendorDashboardView(),
    );
  }
}

// --- Widget de la Vista (Consume el ViewModel) ---
class _VendorDashboardView extends StatefulWidget {
  // Convertido a StatefulWidget para manejar el ScrollController
  const _VendorDashboardView();
  @override
  State<_VendorDashboardView> createState() => _VendorDashboardViewState();
}

class _VendorDashboardViewState extends State<_VendorDashboardView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Añade listener para detectar scroll y cargar más (paginación infinita)
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose(); // Importante liberar el controlador
    super.dispose();
  }

  // Lógica para cargar más cuando el usuario llega cerca del final
  void _onScroll() {
    // Umbral antes de llegar al final (ajusta según necesidad)
    const scrollThreshold = 300.0;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - scrollThreshold) {
      // Llama a los métodos del ViewModel para cargar más
      // Usa 'context.read' dentro de callbacks/listeners para evitar re-escuchar
      context.read<VendorDashboardViewModel>().loadMoreVisits();
      context.read<VendorDashboardViewModel>().loadMoreCustomers();
    }
  }

  // --- Métodos de Navegación (Usan context.read para acceder al ViewModel) ---
  void _navigateToScheduleVisit(BuildContext context) {
    final viewModel = context.read<VendorDashboardViewModel>();
    Navigator.push<bool>( context,
      MaterialPageRoute(builder: (_) => ScheduleVisitScreen(vendorId: viewModel.vendorId)),
    ).then((visitScheduled) {
      if (visitScheduled == true) viewModel.loadInitialData(refresh: true);
    });
  }
  void _navigateToCustomerDetail(BuildContext context, String customerId) {
    final viewModel = context.read<VendorDashboardViewModel>();
    Navigator.push( context,
      MaterialPageRoute(builder: (_) => CustomerDetailScreen(
        customerId: customerId,
        vendorId: viewModel.vendorId,
      )),
    );
  }
  void _navigateToVisitDetail(BuildContext context, Visit visit) { // Pasar objeto completo
    final viewModel = context.read<VendorDashboardViewModel>();
    // Pasar el cliente cacheado si existe
    final customer = viewModel.getCachedCustomer(visit.customerId);
    Navigator.push<bool>( context,
      MaterialPageRoute( builder: (_) => VisitDetailScreen(
        visitId: visit.id,
        // Opcional: Pasar objetos para evitar búsqueda en pantalla de detalle
        // initialVisit: visit,
        // initialCustomer: customer,
      )),
    ).then((visitUpdated) {
      if (visitUpdated == true) viewModel.loadInitialData(refresh: true);
    });
  }
  void _navigateToMap(BuildContext context) {
    print("TODO: Navegar a pantalla de mapa de visitas");
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mapa no implementado aún')));
    // final viewModel = context.read<VendorDashboardViewModel>();
    // final visitsWithLocation = viewModel.displayVisits.where((v) => v.latitude != null).toList();
    // Navigator.push(context, MaterialPageRoute(builder: (_) => MapVisitsScreen(visits: visitsWithLocation)));
  }

  // --- Build Method Principal de la Vista ---
  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<VendorDashboardViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _AppBarTitle(vendor: viewModel.vendor),
        actions: [
          _ConnectivityIcon(isOffline: viewModel.isOffline),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: () => _navigateToMap(context),
            tooltip: 'Ver mapa de visitas',
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => VendorToolsScreen(vendorId: viewModel.vendorId)),
            ),
            tooltip: 'Herramientas',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _navigateToScheduleVisit(context),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Agendar Visita'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => viewModel.loadInitialData(refresh: true),
        color: theme.primaryColor,
        child: _buildBodyScrollView(context, viewModel),
      ),
    );
  }

  // --- Construcción del Cuerpo ---
  Widget _buildBodyScrollView(BuildContext context, VendorDashboardViewModel viewModel) {

    // Estado de Carga Inicial
    if (viewModel.isLoading && !viewModel.initialLoadComplete) {
      // Centrar indicador de carga
      return const Center(child: CircularProgressIndicator());
    }
    // Estado de Error Crítico Inicial
    if (viewModel.errorMessage != null && viewModel.vendor == null) {
      return Center( // Centrar widget de error
        child: ErrorStateWidget( // Usar widget separado
            message: viewModel.errorMessage!,
            onRetry: () => viewModel.loadInitialData()
        ),
      );
    }
    // Estado Imposible
    if (viewModel.vendor == null) {
      return const Center(child: Text('Error inesperado: Vendedor no disponible.'));
    }

    // --- Cuerpo Principal con CustomScrollView ---
    return CustomScrollView(
      controller: _scrollController, // Importante para paginación
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), // Mejor feedback de scroll
      slivers: [
        // --- Banner de Error (si aplica) ---
        if (viewModel.errorMessage != null && viewModel.initialLoadComplete)
          SliverToBoxAdapter(child: GeneralErrorBanner( // Usa widget separado
              message: viewModel.errorMessage!,
              onDismiss: () => viewModel.clearErrorMessage()
          )),

        // --- Panel de Estadísticas ---
        SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0), // Padding alrededor
            child: StatsPanel(viewModel: viewModel) // Usa widget separado
        )),
        const SliverToBoxAdapter(child: SizedBox(height: 8)), // Espacio reducido

        // --- Info Vendedor ---
        SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: VendorInfoCard(vendor: viewModel.vendor!) // Usa widget separado
        )),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        // --- Meta de Ventas ---
        if (viewModel.currentGoal != null) ...[
          SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SalesGoalCard(currentGoal: viewModel.currentGoal!) // Usa widget separado
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],

        // --- Sección Próximas Visitas ---
        SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SectionHeader('Próximas Visitas', onViewAllPressed: () => print("TODO: Nav Todas Visitas")))), // Usa widget separado
        SliverToBoxAdapter(child: VisitFilterChips(viewModel: viewModel)), // Usa widget separado
        VisitList(
          onVisitTap: (visit) => _navigateToVisitDetail(context, visit),
          onLoadMore: () => viewModel.loadMoreVisits(),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        // --- Sección Clientes Asignados ---
        SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SectionHeader('Clientes Asignados', onViewAllPressed: () => print("TODO: Nav Todos Clientes")))), // Usa widget separado
        SliverToBoxAdapter(child: CustomerFilterChips(viewModel: viewModel)), // Usa widget separado
        CustomerList(
          onCustomerTap: (String customerId) => _navigateToCustomerDetail(context, customerId),
          onAcknowledgeTap: (customer) => viewModel.acknowledgeNewCustomer(customer),
          onLoadMore: () {},
        ),

        // Padding inferior para que el FAB no tape el botón "Cargar más"
        const SliverToBoxAdapter(child: SizedBox(height: 88)),
      ],
    );
  }
} // Fin _VendorDashboardViewState

// ================================================================
// WIDGETS DE UI PRIVADOS DE ESTA PANTALLA (Si los hubiera)
// O puedes mover AppBarTitle y ConnectivityIcon a widgets/ también
// ================================================================

class _AppBarTitle extends StatelessWidget {
  final vend.Vendor? vendor;
  const _AppBarTitle({required this.vendor});

  @override
  Widget build(BuildContext context) {
    if (vendor == null) return const Text('Cargando...');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(vendor?.name ?? 'Sin nombre', style: const TextStyle(fontSize: 18)),
        Text(vendor?.email ?? 'Sin email', style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _ConnectivityIcon extends StatelessWidget {
  final bool isOffline;
  const _ConnectivityIcon({required this.isOffline});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Tooltip(message: isOffline ? 'Trabajando sin conexión' : 'Conectado',
        child: Icon(isOffline ? Icons.signal_wifi_off_rounded : Icons.signal_wifi_4_bar_rounded,
          color: isOffline ? Colors.orange.shade300 : theme.colorScheme.onPrimary.withOpacity(0.9), size: 20,),),);
  }
}