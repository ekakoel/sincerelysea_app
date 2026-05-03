import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/models/product.dart';
import 'package:sincerelysea/services/product_service.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:sincerelysea/widgets/app_check_network_image.dart';

class ManageProductsScreen extends StatefulWidget {
  const ManageProductsScreen({super.key});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  static const int _pageSize = 20;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';
  final Set<String> _selectedProductIds = <String>{};
  bool _bulkRunning = false;
  int _visibleCount = _pageSize;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ProductService productService = context.read<ProductService>();
    return FutureBuilder<bool>(
      future: productService.isCurrentUserAdmin(),
      builder: (BuildContext context, AsyncSnapshot<bool> roleSnapshot) {
        if (roleSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (roleSnapshot.data != true) {
          return Scaffold(
            appBar: AppBar(title: const Text('Manage Store Products')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Only admin accounts can manage SincerelySea Store products.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Manage Store Products')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showCreateProductSheet,
            icon: const Icon(Icons.add),
            label: const Text('Add Product'),
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: productService.myProductsStream(),
            builder: (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Failed to load products: ${snapshot.error}'),
                );
              }

              final List<Product> products =
                  (snapshot.data?.docs ??
                          <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                      .map(Product.fromFirestore)
                      .where(
                        (Product product) =>
                            product.ownerId == ProductService.storeId ||
                            product.managedByAdmins,
                      )
                      .toList(growable: false);
              final List<Product> filtered = products.where(_matchesFilter).toList();
              final int visibleCount = filtered.length < _visibleCount
                  ? filtered.length
                  : _visibleCount;
              final List<Product> paged = filtered.take(visibleCount).toList();
              final Set<String> visibleIds = filtered
                  .map((Product product) => product.id)
                  .toSet();
              _selectedProductIds.removeWhere(
                (String id) => !visibleIds.contains(id),
              );

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: <Widget>[
                  _buildToolbar(products.length, filtered.length, paged),
                  const SizedBox(height: 12),
                  if (products.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 140),
                      child: Center(
                        child: Text(
                          'No products have been added to SincerelySea Store yet.',
                        ),
                      ),
                    )
                  else if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 140),
                      child: Center(
                        child: Text('No products match current filter.'),
                      ),
                    )
                  else
                    ...paged.map(
                      (Product product) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ManageProductCard(
                          product: product,
                          selected: _selectedProductIds.contains(product.id),
                          onSelectChanged: (bool value) {
                            _toggleSelected(product.id, value);
                          },
                          onEdit: () => _showEditSheet(product),
                          onToggleAvailability: () => _toggleAvailability(product),
                          onDelete: () => _confirmDelete(product),
                        ),
                      ),
                    ),
                  if (filtered.length > paged.length)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _visibleCount += _pageSize;
                            });
                          },
                          icon: const Icon(Icons.expand_more),
                          label: Text(
                            'Load More (${filtered.length - paged.length} remaining)',
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildToolbar(int total, int visible, List<Product> visibleProducts) {
    final bool hasSelection = _selectedProductIds.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search product name/category',
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
          onChanged: (String value) {
            setState(() {
              _searchQuery = value.trim().toLowerCase();
              _visibleCount = _pageSize;
            });
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: <String>['all', 'available', 'paused'].map((String value) {
            return ChoiceChip(
              selected: _statusFilter == value,
              label: Text(
                switch (value) {
                  'available' => 'Available',
                  'paused' => 'Paused',
                  _ => 'All',
                },
              ),
              onSelected: (_) => setState(() {
                _statusFilter = value;
                _visibleCount = _pageSize;
              }),
            );
          }).toList(growable: false),
        ),
        const SizedBox(height: 8),
        Text(
          'Showing $visible of $total products',
          style: const TextStyle(color: AppColors.black54),
        ),
        const SizedBox(height: 10),
        if (hasSelection)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.tonal(
                onPressed: _bulkRunning ? null : () => _bulkSetAvailability(false),
                child: Text('Pause (${_selectedProductIds.length})'),
              ),
              FilledButton.tonal(
                onPressed: _bulkRunning ? null : () => _bulkSetAvailability(true),
                child: const Text('Resume'),
              ),
              FilledButton.tonal(
                onPressed: _bulkRunning
                    ? null
                    : () => _bulkUpdateStockDialog(visibleProducts),
                child: const Text('Update Stock'),
              ),
              FilledButton.tonal(
                onPressed: _bulkRunning
                    ? null
                    : () => _bulkUpdatePriceDialog(visibleProducts),
                child: const Text('Update Price'),
              ),
              FilledButton.tonal(
                onPressed: _bulkRunning ? null : _bulkDeleteSelected,
                child: const Text('Delete Selected'),
              ),
              TextButton(
                onPressed: _bulkRunning ? null : _clearSelection,
                child: const Text('Clear'),
              ),
            ],
          )
        else
          TextButton.icon(
            onPressed: () {
              setState(() {
                for (final Product product in visibleProducts) {
                  _selectedProductIds.add(product.id);
                }
              });
            },
            icon: const Icon(Icons.select_all),
            label: const Text('Select Visible Products'),
          ),
      ],
    );
  }

  void _toggleSelected(String productId, bool value) {
    setState(() {
      if (value) {
        _selectedProductIds.add(productId);
      } else {
        _selectedProductIds.remove(productId);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedProductIds.clear());
  }

  Future<void> _bulkSetAvailability(bool available) async {
    if (_selectedProductIds.isEmpty) {
      return;
    }
    setState(() => _bulkRunning = true);
    final ProductService productService = context.read<ProductService>();
    final QuerySnapshot<Map<String, dynamic>> snapshot = await productService
        .myProductsStream()
        .first;
    final List<Product> selectedProducts = snapshot.docs
        .map(Product.fromFirestore)
        .where((Product product) => _selectedProductIds.contains(product.id))
        .toList(growable: false);
    int success = 0;
    try {
      for (final Product product in selectedProducts) {
        await productService.updateProduct(
          productId: product.id,
          inventoryType: product.inventoryType,
          stock: product.stock,
          preorderDays: product.preorderDays,
          preorderNote: product.preorderNote,
          availableForPurchase: available,
          name: product.name,
          price: product.price,
          category: product.category,
          description: product.description,
        );
        success++;
      }
      if (!mounted) {
        return;
      }
      _clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            available
                ? '$success products resumed.'
                : '$success products paused.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bulk update failed after $success items: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _bulkRunning = false);
      }
    }
  }

  Future<void> _bulkUpdatePriceDialog(List<Product> visibleProducts) async {
    final ProductService productService = context.read<ProductService>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final List<Product> selectedProducts = visibleProducts
        .where((Product product) => _selectedProductIds.contains(product.id))
        .toList(growable: false);
    if (selectedProducts.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No selected products for price update.')),
      );
      return;
    }
    final TextEditingController priceController = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Bulk Update Price'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Set new price for ${selectedProducts.length} selected products.'),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'New price'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    final double? nextPrice = double.tryParse(priceController.text.trim());
    if (nextPrice == null || nextPrice < 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Price must be a valid positive number.')),
      );
      return;
    }
    setState(() => _bulkRunning = true);
    int success = 0;
    try {
      for (final Product product in selectedProducts) {
        await productService.updateProduct(
          productId: product.id,
          inventoryType: product.inventoryType,
          stock: product.stock,
          preorderDays: product.preorderDays,
          preorderNote: product.preorderNote,
          availableForPurchase: product.availableForPurchase,
          name: product.name,
          price: nextPrice,
          category: product.category,
          description: product.description,
        );
        success++;
      }
      if (!mounted) {
        return;
      }
      _clearSelection();
      messenger.showSnackBar(
        SnackBar(content: Text('Updated price for $success products.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Bulk price update failed after $success items: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _bulkRunning = false);
      }
    }
  }

  Future<void> _bulkDeleteSelected() async {
    if (_selectedProductIds.isEmpty) {
      return;
    }
    final ProductService productService = context.read<ProductService>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Selected Products'),
          content: Text(
            'Delete ${_selectedProductIds.length} selected products? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _bulkRunning = true);
    int success = 0;
    try {
      for (final String id in _selectedProductIds.toList(growable: false)) {
        await productService.deleteProduct(id);
        success++;
      }
      if (!mounted) {
        return;
      }
      _clearSelection();
      messenger.showSnackBar(SnackBar(content: Text('$success products deleted.')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Bulk delete failed after $success items: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _bulkRunning = false);
      }
    }
  }

  Future<void> _bulkUpdateStockDialog(List<Product> visibleProducts) async {
    final ProductService productService = context.read<ProductService>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final List<Product> selectedReadyStock = visibleProducts
        .where(
          (Product product) =>
              _selectedProductIds.contains(product.id) &&
              product.inventoryType == 'ready_stock',
        )
        .toList(growable: false);
    if (selectedReadyStock.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No ready-stock products selected for stock update.'),
        ),
      );
      return;
    }
    final TextEditingController stockController = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Bulk Update Stock'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Set stock value for ${selectedReadyStock.length} selected ready-stock products.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'New stock value'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    final int? nextStock = int.tryParse(stockController.text.trim());
    if (nextStock == null || nextStock < 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Stock must be 0 or more.')),
      );
      return;
    }
    setState(() => _bulkRunning = true);
    int success = 0;
    try {
      for (final Product product in selectedReadyStock) {
        await productService.updateProduct(
          productId: product.id,
          inventoryType: product.inventoryType,
          stock: nextStock,
          preorderDays: product.preorderDays,
          preorderNote: product.preorderNote,
          availableForPurchase: product.availableForPurchase,
          name: product.name,
          price: product.price,
          category: product.category,
          description: product.description,
        );
        success++;
      }
      if (!mounted) {
        return;
      }
      _clearSelection();
      messenger.showSnackBar(SnackBar(content: Text('Updated stock for $success products.')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Bulk stock update failed after $success items: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _bulkRunning = false);
      }
    }
  }

  bool _matchesFilter(Product product) {
    if (_statusFilter == 'available' && !product.availableForPurchase) {
      return false;
    }
    if (_statusFilter == 'paused' && product.availableForPurchase) {
      return false;
    }
    if (_searchQuery.isEmpty) {
      return true;
    }
    final String haystack = '${product.name} ${product.category}'.toLowerCase();
    return haystack.contains(_searchQuery);
  }

  Future<void> _showCreateProductSheet() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController categoryController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController stockController = TextEditingController();
    final TextEditingController preorderDaysController = TextEditingController();
    final TextEditingController preorderNoteController = TextEditingController();
    final List<File> images = <File>[];
    String inventoryType = 'ready_stock';
    bool available = true;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Future<void> pickImages() async {
              final ImagePicker picker = ImagePicker();
              final List<XFile> picked = await picker.pickMultiImage(
                imageQuality: 85,
              );
              if (picked.isEmpty) {
                return;
              }
              setModalState(() {
                images.addAll(picked.map((XFile x) => File(x.path)));
              });
            }

            Future<void> save() async {
              final String name = nameController.text.trim();
              final String category = categoryController.text.trim();
              final double? price = double.tryParse(priceController.text.trim());
              final String description = descriptionController.text.trim();
              final int stock = int.tryParse(stockController.text.trim()) ?? 0;
              final int preorderDays =
                  int.tryParse(preorderDaysController.text.trim()) ?? 0;
              if (name.isEmpty || category.isEmpty || description.isEmpty) {
                ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                  const SnackBar(content: Text('Name, category, and description are required.')),
                );
                return;
              }
              if (price == null || price < 0) {
                ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                  const SnackBar(content: Text('Price must be a valid number.')),
                );
                return;
              }
              if (inventoryType == 'ready_stock' && stock < 0) {
                ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                  const SnackBar(content: Text('Stock must be 0 or more.')),
                );
                return;
              }
              if (inventoryType == 'preorder' && preorderDays <= 0) {
                ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                  const SnackBar(content: Text('Preorder days must be greater than 0.')),
                );
                return;
              }
              if (images.isEmpty) {
                ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                  const SnackBar(content: Text('Please select at least one image.')),
                );
                return;
              }

              setModalState(() => saving = true);
              try {
                await bottomSheetContext.read<ProductService>().createProduct(
                  CreateProductInput(
                    category: category,
                    inventoryType: inventoryType,
                    preorderDays: inventoryType == 'preorder' ? preorderDays : 0,
                    preorderNote: inventoryType == 'preorder'
                        ? preorderNoteController.text.trim()
                        : '',
                    availableForPurchase: available,
                    name: name,
                    price: price,
                    description: description,
                    stock: inventoryType == 'ready_stock' ? stock : 0,
                    images: images,
                  ),
                );
                if (!bottomSheetContext.mounted) {
                  return;
                }
                Navigator.of(bottomSheetContext).pop();
                ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                  const SnackBar(content: Text('Product created successfully.')),
                );
              } catch (e) {
                if (!bottomSheetContext.mounted) {
                  return;
                }
                ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                  SnackBar(content: Text('Failed to create product: $e')),
                );
              } finally {
                if (bottomSheetContext.mounted) {
                  setModalState(() => saving = false);
                }
              }
            }

            return _ManageFormSheet(
              title: 'Add Product',
              saving: saving,
              nameController: nameController,
              categoryController: categoryController,
              priceController: priceController,
              descriptionController: descriptionController,
              stockController: stockController,
              preorderDaysController: preorderDaysController,
              preorderNoteController: preorderNoteController,
              inventoryType: inventoryType,
              availableForPurchase: available,
              imageCount: images.length,
              onPickImages: pickImages,
              onInventoryChanged: (String value) {
                setModalState(() => inventoryType = value);
              },
              onAvailabilityChanged: (bool value) {
                setModalState(() => available = value);
              },
              onSave: save,
            );
          },
        );
      },
    );
  }

  Future<void> _showEditSheet(Product product) async {
    String inventoryType = product.inventoryType;
    bool availableForPurchase = product.availableForPurchase;
    final TextEditingController nameController = TextEditingController(
      text: product.name,
    );
    final TextEditingController categoryController = TextEditingController(
      text: product.category,
    );
    final TextEditingController priceController = TextEditingController(
      text: product.price.toStringAsFixed(2),
    );
    final TextEditingController descriptionController = TextEditingController(
      text: product.description,
    );
    final TextEditingController stockController = TextEditingController(
      text: product.stock.toString(),
    );
    final TextEditingController preorderDaysController = TextEditingController(
      text: product.preorderDays > 0 ? product.preorderDays.toString() : '',
    );
    final TextEditingController preorderNoteController = TextEditingController(
      text: product.preorderNote,
    );
    final List<String> keptImageUrls = List<String>.from(product.images);
    final List<File> newImages = <File>[];
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final ProductService productService = bottomSheetContext.read<ProductService>();
            Future<void> save() async {
              final int stock = int.tryParse(stockController.text.trim()) ?? 0;
              final int preorderDays =
                  int.tryParse(preorderDaysController.text.trim()) ?? 0;
              final double? price = double.tryParse(priceController.text.trim());
              if (nameController.text.trim().isEmpty ||
                  categoryController.text.trim().isEmpty ||
                  descriptionController.text.trim().isEmpty) {
                ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                  const SnackBar(content: Text('Name, category, and description are required.')),
                );
                return;
              }
              if (price == null || price < 0) {
                ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                  const SnackBar(content: Text('Price must be a valid number.')),
                );
                return;
              }
              if (inventoryType == 'ready_stock' && stock < 0) {
                ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                  const SnackBar(content: Text('Stock must be 0 or more.')),
                );
                return;
              }
              if (inventoryType == 'preorder' && preorderDays <= 0) {
                ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                  const SnackBar(content: Text('Preorder days must be greater than 0.')),
                );
                return;
              }

              setModalState(() => saving = true);
              try {
                await productService.updateProduct(
                  productId: product.id,
                  inventoryType: inventoryType,
                  stock: stock,
                  preorderDays: preorderDays,
                  preorderNote: preorderNoteController.text,
                  availableForPurchase: availableForPurchase,
                  name: nameController.text,
                  price: price,
                  category: categoryController.text,
                  description: descriptionController.text,
                );
                if (keptImageUrls.length + newImages.length > 0 &&
                    (keptImageUrls.length != product.images.length ||
                        newImages.isNotEmpty)) {
                  await productService.updateProductImages(
                    productId: product.id,
                    keepImageUrls: keptImageUrls,
                    newImages: newImages,
                  );
                }
                if (!bottomSheetContext.mounted) {
                  return;
                }
                Navigator.of(bottomSheetContext).pop();
                ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                  const SnackBar(content: Text('Product updated.')),
                );
              } catch (e) {
                if (!bottomSheetContext.mounted) {
                  return;
                }
                ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                  SnackBar(content: Text('Failed to update product: $e')),
                );
              } finally {
                if (bottomSheetContext.mounted) {
                  setModalState(() => saving = false);
                }
              }
            }

            return _ManageFormSheet(
              title: 'Edit Product',
              saving: saving,
              nameController: nameController,
              categoryController: categoryController,
              priceController: priceController,
              descriptionController: descriptionController,
              stockController: stockController,
              preorderDaysController: preorderDaysController,
              preorderNoteController: preorderNoteController,
              inventoryType: inventoryType,
              availableForPurchase: availableForPurchase,
              imageCount: product.images.length,
              existingImages: keptImageUrls,
              onPickImages: () async {
                final ImagePicker picker = ImagePicker();
                final List<XFile> picked = await picker.pickMultiImage(
                  imageQuality: 85,
                );
                if (picked.isEmpty) {
                  return;
                }
                setModalState(() {
                  newImages.addAll(picked.map((XFile file) => File(file.path)));
                });
              },
              extraImageCount: newImages.length,
              onRemoveExistingImage: (String imageUrl) {
                setModalState(() {
                  keptImageUrls.remove(imageUrl);
                });
              },
              onInventoryChanged: (String value) {
                setModalState(() => inventoryType = value);
              },
              onAvailabilityChanged: (bool value) {
                setModalState(() => availableForPurchase = value);
              },
              onSave: save,
            );
          },
        );
      },
    );
  }

  Future<void> _toggleAvailability(Product product) async {
    try {
      await context.read<ProductService>().updateProduct(
        productId: product.id,
        inventoryType: product.inventoryType,
        stock: product.stock,
        preorderDays: product.preorderDays,
        preorderNote: product.preorderNote,
        availableForPurchase: !product.availableForPurchase,
        name: product.name,
        price: product.price,
        category: product.category,
        description: product.description,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            product.availableForPurchase
                ? 'Product paused.'
                : 'Product resumed.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update product: $e')));
    }
  }

  Future<void> _confirmDelete(Product product) async {
    final ProductService productService = context.read<ProductService>();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: Text(
            'Delete "${product.name}" permanently? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    try {
      await productService.deleteProduct(product.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product deleted.')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete product: $e')));
    }
  }
}

class _ManageProductCard extends StatelessWidget {
  const _ManageProductCard({
    required this.product,
    required this.selected,
    required this.onSelectChanged,
    required this.onEdit,
    required this.onToggleAvailability,
    required this.onDelete,
  });

  final Product product;
  final bool selected;
  final ValueChanged<bool> onSelectChanged;
  final VoidCallback onEdit;
  final VoidCallback onToggleAvailability;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final String imageUrl = product.images.isNotEmpty ? product.images.first : '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray300),
      ),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Checkbox(
                value: selected,
                onChanged: (bool? value) => onSelectChanged(value ?? false),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 78,
                  height: 78,
                  child: imageUrl.isEmpty
                      ? Container(
                          color: AppColors.gray200,
                          child: const Icon(Icons.inventory_2_outlined),
                        )
                      : AppCheckCachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: Container(color: AppColors.gray200),
                          error: Container(
                            color: AppColors.gray200,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(product.category),
                    const SizedBox(height: 6),
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _Tag(
                          label: product.inventoryLabel,
                          color: product.isPreorder ? Colors.orange : Colors.green,
                        ),
                        _Tag(
                          label: product.availableForPurchase ? 'Available' : 'Paused',
                          color: product.availableForPurchase ? Colors.blue : Colors.grey,
                        ),
                        _Tag(
                          label: product.isPreorder
                              ? 'Est. ${product.preorderDays} day(s)'
                              : 'Stock ${product.stock}',
                          color: AppColors.gray700,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onToggleAvailability,
                  icon: Icon(
                    product.availableForPurchase
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                  ),
                  label: Text(product.availableForPurchase ? 'Pause' : 'Resume'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManageFormSheet extends StatelessWidget {
  const _ManageFormSheet({
    required this.title,
    required this.saving,
    required this.nameController,
    required this.categoryController,
    required this.priceController,
    required this.descriptionController,
    required this.stockController,
    required this.preorderDaysController,
    required this.preorderNoteController,
    required this.inventoryType,
    required this.availableForPurchase,
    required this.imageCount,
    this.extraImageCount = 0,
    this.existingImages = const <String>[],
    this.onRemoveExistingImage,
    required this.onInventoryChanged,
    required this.onAvailabilityChanged,
    required this.onSave,
    required this.onPickImages,
  });

  final String title;
  final bool saving;
  final TextEditingController nameController;
  final TextEditingController categoryController;
  final TextEditingController priceController;
  final TextEditingController descriptionController;
  final TextEditingController stockController;
  final TextEditingController preorderDaysController;
  final TextEditingController preorderNoteController;
  final String inventoryType;
  final bool availableForPurchase;
  final int imageCount;
  final int extraImageCount;
  final List<String> existingImages;
  final ValueChanged<String>? onRemoveExistingImage;
  final ValueChanged<String> onInventoryChanged;
  final ValueChanged<bool> onAvailabilityChanged;
  final VoidCallback onSave;
  final VoidCallback? onPickImages;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Product Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: inventoryType,
              decoration: const InputDecoration(labelText: 'Inventory Type'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'ready_stock', child: Text('Ready Stock')),
                DropdownMenuItem(value: 'preorder', child: Text('Preorder')),
              ],
              onChanged: (String? value) {
                if (value != null) {
                  onInventoryChanged(value);
                }
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: availableForPurchase,
              contentPadding: EdgeInsets.zero,
              title: const Text('Available for purchase'),
              onChanged: onAvailabilityChanged,
            ),
            const SizedBox(height: 12),
            if (inventoryType == 'ready_stock')
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock'),
              )
            else ...<Widget>[
              TextField(
                controller: preorderDaysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Preorder days'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: preorderNoteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Preorder Note'),
              ),
            ],
            if (onPickImages != null) ...<Widget>[
              const SizedBox(height: 12),
              if (existingImages.isNotEmpty) ...<Widget>[
                const Text(
                  'Current Images',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 78,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: existingImages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final String imageUrl = existingImages[index];
                      return Stack(
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 78,
                              height: 78,
                              child: AppCheckCachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: Container(color: AppColors.gray200),
                                error: Container(
                                  color: AppColors.gray200,
                                  child: const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                          ),
                          if (onRemoveExistingImage != null)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: InkWell(
                                onTap: () => onRemoveExistingImage!(imageUrl),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: onPickImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  existingImages.isEmpty
                      ? 'Select Images ($imageCount selected)'
                      : 'Add Images (+$extraImageCount)',
                ),
              ),
            ] else ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'Existing images: $imageCount',
                style: const TextStyle(color: AppColors.black54),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(title.startsWith('Add') ? 'Create Product' : 'Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
