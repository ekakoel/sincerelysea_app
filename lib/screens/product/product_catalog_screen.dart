import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/models/product.dart';
import 'package:sincerelysea/screens/cart/cart_screen.dart';
import 'package:sincerelysea/screens/product/product_detail_screen.dart';
import 'package:sincerelysea/screens/product/saved_products_screen.dart';
import 'package:sincerelysea/services/cart_service.dart';
import 'package:sincerelysea/services/product_service.dart';
import 'package:sincerelysea/services/wishlist_service.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:sincerelysea/widgets/product_card.dart';

class ProductCatalogScreen extends StatefulWidget {
  const ProductCatalogScreen({super.key});

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  static const int _pageSize = 12;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<Product> _products = <Product>[];

  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  ProductSortOption _sortOption = ProductSortOption.newest;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedInventoryFilter = 'all';
  double? _minPrice;
  double? _maxPrice;
  bool _wishlistOnly = false;
  List<String> _categories = const <String>['All'];

  @override
  void initState() {
    super.initState();
    _fetchInitialProducts();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final String nextQuery = _searchController.text.trim().toLowerCase();
    if (nextQuery == _searchQuery) {
      return;
    }
    setState(() => _searchQuery = nextQuery);
  }

  void _onScroll() {
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent * 0.85) {
      return;
    }
    if (_isLoadingMore || !_hasMore) {
      return;
    }
    _fetchMoreProducts();
  }

  Future<void> _fetchInitialProducts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _products.clear();
        _categories = const <String>['All'];
        _lastDocument = null;
        _hasMore = true;
      });
    }

    try {
      final List<String> categories = await context.read<ProductService>()
          .getProductCategories();
      if (mounted) {
        setState(() {
          _categories = <String>['All', ...categories];
          if (!_categories.contains(_selectedCategory)) {
            _selectedCategory = 'All';
          }
        });
      }
      await _fetchProducts();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchMoreProducts() async {
    if (mounted) {
      setState(() => _isLoadingMore = true);
    }
    try {
      await _fetchProducts();
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _fetchProducts() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await context
        .read<ProductService>()
        .getProductsPage(
          limit: _pageSize,
          startAfter: _lastDocument,
          options: ProductQueryOptions(
            sort: _sortOption,
            category: _selectedCategory == 'All' ? null : _selectedCategory,
            inventoryType: _selectedInventoryFilter,
            minPrice: _minPrice,
            maxPrice: _maxPrice,
          ),
        );

    if (snapshot.docs.length < _pageSize) {
      _hasMore = false;
    }
    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
    }

    final List<Product> nextProducts = snapshot.docs
        .map(Product.fromFirestore)
        .where((Product product) => product.id.isNotEmpty)
        .toList(growable: false);

    if (!mounted) {
      return;
    }
    setState(() => _products.addAll(nextProducts));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Saved Products',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SavedProductsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.favorite_border),
          ),
          StreamBuilder<int>(
            stream: context.read<CartService>().cartItemCountStream(),
            builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
              final int totalItems = snapshot.data ?? 0;
              return IconButton(
                tooltip: 'Cart',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CartScreen(),
                    ),
                  );
                },
                icon: Badge(
                  isLabelVisible: totalItems > 0,
                  label: Text(totalItems > 99 ? '99+' : '$totalItems'),
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchInitialProducts,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return StreamBuilder<Set<String>>(
      stream: context.read<WishlistService>().productWishlistIdsStream(),
      builder: (BuildContext context, AsyncSnapshot<Set<String>> snapshot) {
        final Set<String> wishlistIds = snapshot.data ?? <String>{};
        final List<Product> visibleProducts = _products.where((Product product) {
          if (_wishlistOnly && !wishlistIds.contains(product.id)) {
            return false;
          }
          if (_selectedInventoryFilter == 'ready_stock' && !product.isReadyStock) {
            return false;
          }
          if (_selectedInventoryFilter == 'preorder' && !product.isPreorder) {
            return false;
          }
          if (_selectedCategory != 'All' &&
              product.category.trim() != _selectedCategory) {
            return false;
          }
          if (_searchQuery.isEmpty) {
            return true;
          }
          final String haystack =
              '${product.name} ${product.description}'.toLowerCase();
          return haystack.contains(_searchQuery);
        }).toList(growable: false);

        if (_isLoading) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              _buildToolbar(),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.67,
                ),
                itemBuilder: (BuildContext context, int index) {
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.gray300),
                    ),
                  );
                },
              ),
            ],
          );
        }

        if (_products.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              _buildToolbar(),
              const SizedBox(height: 80),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gray300),
                ),
                child: const Column(
                  children: <Widget>[
                    Icon(Icons.storefront_outlined, size: 36),
                    SizedBox(height: 10),
                    Text(
                      'No products available yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            _buildToolbar(),
            const SizedBox(height: 12),
            if (visibleProducts.isEmpty)
              Container(
                margin: const EdgeInsets.only(top: 40),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gray300),
                ),
                child: Center(
                  child: Text(
                    _wishlistOnly
                        ? 'No wishlisted products match this filter.'
                        : 'No products match your filter.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visibleProducts.length + (_isLoadingMore ? 2 : 0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.67,
                ),
                itemBuilder: (BuildContext context, int index) {
                  if (index >= visibleProducts.length) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  final Product product = visibleProducts[index];
                  final bool isWishlisted = wishlistIds.contains(product.id);
                  return ProductCard(
                    product: product,
                    isWishlisted: isWishlisted,
                    onWishlistTap: () => _toggleWishlist(product, isWishlisted),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ProductDetailScreen(productId: product.id),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar() {
    final int activeFilters = _activeFilterCount();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Discover Products',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '${_products.length} items available',
          style: const TextStyle(color: AppColors.black54),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search products',
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            ActionChip(
              avatar: const Icon(Icons.swap_vert, size: 18),
              label: Text(_sortLabel(_sortOption)),
              onPressed: _openSortSheet,
            ),
            ActionChip(
              avatar: const Icon(Icons.tune, size: 18),
              label: Text(
                activeFilters == 0 ? 'Filters' : 'Filters ($activeFilters)',
              ),
              onPressed: _openFilterSheet,
            ),
            FilterChip(
              selected: _wishlistOnly,
              label: const Text('Wishlist'),
              onSelected: (bool value) => setState(() => _wishlistOnly = value),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Wrap(
            spacing: 8,
            children: _categories.map((String category) {
              return ChoiceChip(
                label: Text(category),
                selected: _selectedCategory == category,
                onSelected: (_) {
                  setState(() => _selectedCategory = category);
                  _fetchInitialProducts();
                },
              );
            }).toList(growable: false),
          ),
        ),
      ],
    );
  }

  int _activeFilterCount() {
    int count = 0;
    if (_selectedInventoryFilter != 'all') {
      count++;
    }
    if (_minPrice != null) {
      count++;
    }
    if (_maxPrice != null) {
      count++;
    }
    return count;
  }

  String _sortLabel(ProductSortOption sort) {
    return switch (sort) {
      ProductSortOption.newest => 'Newest',
      ProductSortOption.bestSelling => 'Best Selling',
      ProductSortOption.priceLowToHigh => 'Price: Low to High',
      ProductSortOption.priceHighToLow => 'Price: High to Low',
    };
  }

  Future<void> _openSortSheet() async {
    ProductSortOption temp = _sortOption;
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext bottomSheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Sort Products',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  ...ProductSortOption.values.map((ProductSortOption option) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_sortLabel(option)),
                      trailing: temp == option
                          ? const Icon(Icons.check_circle, size: 20)
                          : const Icon(Icons.circle_outlined, size: 20),
                      onTap: () => setModalState(() => temp = option),
                    );
                  }),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.of(bottomSheetContext).pop();
                        await _changeSort(temp);
                      },
                      child: const Text('Apply Sort'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openFilterSheet() async {
    String inventory = _selectedInventoryFilter;
    final TextEditingController minController = TextEditingController(
      text: _minPrice?.toStringAsFixed(0) ?? '',
    );
    final TextEditingController maxController = TextEditingController(
      text: _maxPrice?.toStringAsFixed(0) ?? '',
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(bottomSheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Filter Products',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: <String>['all', 'ready_stock', 'preorder'].map((
                      String value,
                    ) {
                      return ChoiceChip(
                        selected: inventory == value,
                        label: Text(
                          switch (value) {
                            'ready_stock' => 'Ready Stock',
                            'preorder' => 'Preorder',
                            _ => 'All Types',
                          },
                        ),
                        onSelected: (_) => setModalState(() => inventory = value),
                      );
                    }).toList(growable: false),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: minController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Min Price'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: maxController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Max Price'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedInventoryFilter = 'all';
                              _minPrice = null;
                              _maxPrice = null;
                            });
                            Navigator.of(bottomSheetContext).pop();
                            _fetchInitialProducts();
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _selectedInventoryFilter = inventory;
                              _minPrice =
                                  double.tryParse(minController.text.trim());
                              _maxPrice =
                                  double.tryParse(maxController.text.trim());
                            });
                            Navigator.of(bottomSheetContext).pop();
                            _fetchInitialProducts();
                          },
                          child: const Text('Apply Filters'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _changeSort(ProductSortOption nextSort) async {
    if (_sortOption == nextSort) {
      return;
    }
    setState(() => _sortOption = nextSort);
    await _fetchInitialProducts();
  }

  Future<void> _toggleWishlist(Product product, bool isWishlisted) async {
    try {
      await context.read<WishlistService>().toggleProductWishlist(product);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isWishlisted
                ? 'Removed from wishlist'
                : 'Added to wishlist',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update wishlist: $e')),
      );
    }
  }
}
