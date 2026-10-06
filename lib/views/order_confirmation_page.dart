import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'widgets/market_ui.dart';

class OrderConfirmationPage extends StatefulWidget {
  final String? orderId;

  const OrderConfirmationPage({super.key, this.orderId});

  @override
  State<OrderConfirmationPage> createState() => _OrderConfirmationPageState();
}

class _OrderConfirmationPageState extends State<OrderConfirmationPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _arrival;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _arrival = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // "Hareketi azalt" açıksa giriş animasyonu atlanır.
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _shortOrderId {
    final id = widget.orderId ?? '';
    if (id.isEmpty) return '—';
    return id.substring(0, id.length > 8 ? 8 : id.length).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: MarketPalette.canvas,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: FadeTransition(
              opacity: _controller,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.go('/home'),
                      child: Text(
                        'Ana sayfa',
                        style: MarketText.label(color: MarketPalette.greenDark),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ScaleTransition(
                    scale: _arrival,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 176,
                          height: 176,
                          decoration: BoxDecoration(
                            color: MarketPalette.greenSoft,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: MarketPalette.green.withValues(alpha: .12),
                              width: 12,
                            ),
                          ),
                        ),
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                MarketPalette.green,
                                MarketPalette.greenDark
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    MarketPalette.green.withValues(alpha: .28),
                                blurRadius: 30,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 58),
                        ),
                        const Positioned(
                          right: 7,
                          top: 19,
                          child: _SuccessDot(
                            color: MarketPalette.orange,
                            icon: Icons.auto_awesome_rounded,
                          ),
                        ),
                        const Positioned(
                          left: 3,
                          bottom: 23,
                          child: _SuccessDot(
                            color: MarketPalette.lime,
                            icon: Icons.favorite_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Siparişin bizde!',
                    textAlign: TextAlign.center,
                    style: MarketText.display(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Siparişin başarıyla alındı. Hazırlık başladığında durumunu Siparişlerim sayfasından takip edebilirsin.',
                    textAlign: TextAlign.center,
                    style: MarketText.body(color: MarketPalette.muted, weight: FontWeight.w400, height: 1.55),
                  ),
                  const SizedBox(height: 26),
                  _buildOrderCard(),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: MarketPalette.greenSoft,
                      borderRadius: BorderRadius.circular(MarketRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active_outlined,
                            color: MarketPalette.greenDark),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            'Sipariş durumundaki değişiklikleri sana bildireceğiz.',
                            style: MarketText.body(color: MarketPalette.greenDark, size: 12, weight: FontWeight.w600, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: () => context.go(
                        '/home',
                        extra: {'initialTabIndex': 2, 'openOrders': true},
                      ),
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: const Text('Siparişimi takip et'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: TextButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('Alışverişe devam et'),
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

  Widget _buildOrderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MarketRadius.lg),
        border: Border.all(color: MarketPalette.line),
        boxShadow: [
          BoxShadow(
            color: MarketPalette.greenDeep.withValues(alpha: .05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: MarketPalette.greenSoft,
                  borderRadius: BorderRadius.circular(MarketRadius.md),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: MarketPalette.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sipariş numarası',
                        style: MarketText.caption(size: 11, weight: FontWeight.w400)),
                    const SizedBox(height: 3),
                    Text('#$_shortOrderId',
                        style: MarketText.heading()),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: MarketPalette.orangeSoft,
                  borderRadius: BorderRadius.circular(MarketRadius.pill),
                ),
                child: Text('Alındı',
                    style: MarketText.label(color: MarketPalette.orangeInk, size: 11, weight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _OrderProgress(),
        ],
      ),
    );
  }
}

class _SuccessDot extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _SuccessDot({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, size: 19, color: MarketPalette.greenDeep),
    );
  }
}

class _OrderProgress extends StatelessWidget {
  const _OrderProgress();

  @override
  Widget build(BuildContext context) {
    const labels = ['Alındı', 'Hazırlanıyor', 'Yolda'];
    return Row(
      children: List.generate(labels.length * 2 - 1, (index) {
        if (index.isOdd) {
          return const Expanded(
              child: Divider(color: MarketPalette.line, thickness: 2));
        }
        final step = index ~/ 2;
        final active = step == 0;
        return Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: active ? MarketPalette.green : MarketPalette.canvas,
                shape: BoxShape.circle,
                border: Border.all(
                    color: active ? MarketPalette.green : MarketPalette.line),
              ),
              child: Icon(active ? Icons.check_rounded : Icons.circle,
                  color: active ? Colors.white : MarketPalette.line,
                  size: active ? 17 : 8),
            ),
            const SizedBox(height: 7),
            Text(labels[step],
                style: MarketText.label(color: active ? MarketPalette.greenDark : MarketPalette.muted, size: 11)),
          ],
        );
      }),
    );
  }
}
