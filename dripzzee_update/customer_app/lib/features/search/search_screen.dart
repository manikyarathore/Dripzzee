import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/drip_chip.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/text_field.dart';
import '../../data/catalog_search.dart';
import '../../data/models/catalog_filter.dart';
import '../../data/models/fashion_category.dart';
import '../../data/services/recent_search_store.dart';
import '../../navigation.dart';
import '../../state/auth_controller.dart';
import '../../state/catalog_controller.dart';
import '../catalog/widgets/product_card.dart';
import '../catalog/widgets/store_card.dart';

enum _ResultTab { products, stores }

/// Search across nearby products, brands, stores, categories, colours and
/// styles. Used as a bottom-nav tab and pushed (standalone) from Home.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.standalone = false});

  final bool standalone;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';
  List<String> _recent = const [];
  _ResultTab _tab = _ResultTab.products;
  ProductSort _sort = ProductSort.popular;

  RecentSearchStore get _store => context.read<RecentSearchStore>();
  String? get _uid => context.read<AuthController>().uid;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final uid = _uid;
    if (uid == null) return;
    final list = await _store.load(uid);
    if (mounted) setState(() => _recent = list);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  Future<void> _commit(String value) async {
    final q = value.trim();
    _controller.value = TextEditingValue(
      text: q,
      selection: TextSelection.collapsed(offset: q.length),
    );
    setState(() => _query = q);
    final uid = _uid;
    if (uid != null && q.isNotEmpty) {
      final list = await _store.add(uid, q);
      if (mounted) setState(() => _recent = list);
    }
  }

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogController>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(widget.standalone ? 4 : 16, 12, 16, 8),
              child: Row(
                children: [
                  if (widget.standalone)
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      autofocus: widget.standalone,
                      onChanged: _onChanged,
                      onSubmitted: _commit,
                      textInputAction: TextInputAction.search,
                      style: AppTextStyles.body(size: 15),
                      decoration: appInputDecoration(
                        hint: 'Search styles, brands, stores',
                        prefixIcon: Icons.search_rounded,
                        suffix: _controller.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: Icon(Icons.close_rounded,
                                    color: AppColors.mute),
                                onPressed: _clear,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _body(catalog)),
          ],
        ),
      ),
    );
  }

  Widget _body(CatalogController catalog) {
    if (_query.isEmpty) return _idle(catalog);
    return switch (catalog.state) {
      LoadState.idle || LoadState.loading => const CenteredLoader(),
      LoadState.error => ErrorState(
          message: catalog.error ?? 'Search is unavailable right now.',
          onRetry: catalog.refresh,
        ),
      LoadState.ready => _results(catalog.search(_query)),
    };
  }

  Widget _idle(CatalogController catalog) {
    final brands = <String>{
      for (final p in catalog.recommended(limit: 40))
        if (p.brand.isNotEmpty) p.brand,
    }.take(8).toList();

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (_recent.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text('RECENT SEARCHES', style: AppTextStyles.mono(size: 11)),
              ),
              TextButton(
                onPressed: () async {
                  final uid = _uid;
                  if (uid == null) return;
                  await _store.clear(uid);
                  if (mounted) setState(() => _recent = const []);
                },
                child: Text('Clear all',
                    style: AppTextStyles.body(
                        size: 12, color: AppColors.shopper, weight: FontWeight.w700)),
              ),
            ],
          ),
          for (final r in _recent)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.history_rounded, color: AppColors.mute),
              title: Text(r, style: AppTextStyles.body(size: 15)),
              trailing: IconButton(
                tooltip: 'Remove',
                icon: Icon(Icons.close_rounded, size: 18, color: AppColors.faint),
                onPressed: () async {
                  final uid = _uid;
                  if (uid == null) return;
                  final list = await _store.remove(uid, r);
                  if (mounted) setState(() => _recent = list);
                },
              ),
              onTap: () => _commit(r),
            ),
          const SizedBox(height: 16),
        ],
        Text('BROWSE CATEGORIES', style: AppTextStyles.mono(size: 11)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in kCategories)
              DripChip(
                label: c.label,
                icon: c.icon,
                selected: false,
                onTap: () => AppNav.openProducts(context, c.filter),
              ),
          ],
        ),
        if (brands.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('BRANDS NEAR YOU', style: AppTextStyles.mono(size: 11)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in brands)
                DripChip(label: b, selected: false, onTap: () => _commit(b)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _results(SearchResults results) {
    final products = sortProducts(results.products, _sort);
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (results.suggestions.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                children: [
                  for (final s in results.suggestions) ...[
                    DripChip(
                      label: s,
                      icon: Icons.north_west_rounded,
                      selected: false,
                      onTap: () => _commit(s),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
        if (results.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No results for "$_query"',
              message:
                  'Try a broader word like "kurta" or "sneakers", or browse a category.',
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  DripChip(
                    label: 'Products · ${results.products.length}',
                    selected: _tab == _ResultTab.products,
                    onTap: () => setState(() => _tab = _ResultTab.products),
                  ),
                  DripChip(
                    label: 'Stores · ${results.stores.length}',
                    selected: _tab == _ResultTab.stores,
                    onTap: () => setState(() => _tab = _ResultTab.stores),
                  ),
                  if (_tab == _ResultTab.products && products.length > 1)
                    DripChip(
                      label: _sort == ProductSort.popular
                          ? 'Sort: relevance'
                          : _sort.label,
                      icon: Icons.swap_vert_rounded,
                      selected: _sort != ProductSort.popular,
                      onTap: () => setState(() {
                        final next = ProductSort.values[
                            (ProductSort.values.indexOf(_sort) + 1) %
                                ProductSort.values.length];
                        _sort = next;
                      }),
                    ),
                ],
              ),
            ),
          ),
          if (_tab == _ResultTab.products)
            products.isEmpty
                ? SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.checkroom_outlined,
                      title: 'No products match',
                      message:
                          'But ${pluralize(results.stores.length, 'store')} did — check the Stores tab.',
                    ),
                  )
                : ProductGridSliver(
                    products: products,
                    heroPrefix: 'search',
                  )
          else
            results.stores.isEmpty
                ? const SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'No stores match',
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: results.stores.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, i) => StoreCard(
                        store: results.stores[i],
                        heroTag: 'search-store-${results.stores[i].id}',
                      ),
                    ),
                  ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ],
    );
  }
}
