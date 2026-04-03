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
  bool _wishlistOnly = false;

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
        _lastDocument = null;
        _hasMore = true;
      });
    }

    try {
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
          sort: _sortOption,
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
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.72,
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
              const SizedBox(height: 120),
              const Center(
                child: Text('No products available yet.'),
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
            const SizedBox(height: 16),
            if (visibleProducts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 72),
                child: Center(
                  child: Text(
                    _wishlistOnly
                        ? 'No wishlisted products match this filter.'
                        : 'No products match your search.',
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
                  childAspectRatio: 0.72,
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
    final Set<String> categorySet = <String>{'All'};
    for (final Product product in _products) {
      final String category = product.category.trim();
      if (category.isNotEmpty) {
        categorySet.add(category);
      }
    }
    final List<String> categories = categorySet.toList(growable: false);

    return Column(
      children: <Widget>[
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search products',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            const Text(
              'Sort by',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Wrap(
                  spacing: 8,
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text('Newest'),
                      selected: _sortOption == ProductSortOption.newest,
                      onSelected: (_) => _changeSort(ProductSortOption.newest),
                    ),
                    ChoiceChip(
                      label: const Text('Lowest Price'),
                      selected:
                          _sortOption == ProductSortOption.priceLowToHigh,
                      onSelected: (_) => _changeSort(
                        ProductSortOption.priceLowToHigh,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Highest Price'),
                      selected:
                          _sortOption == ProductSortOption.priceHighToLow,
                      onSelected: (_) => _changeSort(
                        ProductSortOption.priceHighToLow,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Wrap(
            spacing: 8,
            children: categories.map((String category) {
              return ChoiceChip(
                label: Text(category),
                selected: _selectedCategory == category,
                onSelected: (_) {
                  setState(() => _selectedCategory = category);
                },
              );
            }).toList(growable: false),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ChoiceChip(
                label: const Text('All Types'),
                selected: _selectedInventoryFilter == 'all',
                onSelected: (_) {
                  setState(() => _selectedInventoryFilter = 'all');
                },
              ),
              ChoiceChip(
                label: const Text('Ready Stock'),
                selected: _selectedInventoryFilter == 'ready_stock',
                onSelected: (_) {
                  setState(() => _selectedInventoryFilter = 'ready_stock');
                },
              ),
              ChoiceChip(
                label: const Text('Preorder'),
                selected: _selectedInventoryFilter == 'preorder',
                onSelected: (_) {
                  setState(() => _selectedInventoryFilter = 'preorder');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilterChip(
            selected: _wishlistOnly,
            label: const Text('Wishlist Only'),
            avatar: Icon(
              _wishlistOnly ? Icons.favorite : Icons.favorite_border,
              color: _wishlistOnly ? Colors.red : AppColors.gray700,
              size: 18,
            ),
            onSelected: (bool value) {
              setState(() => _wishlistOnly = value);
            },
          ),
        ),
      ],
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
