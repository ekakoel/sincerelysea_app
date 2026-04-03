import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/models/product.dart';
import 'package:sincerelysea/services/product_service.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:sincerelysea/widgets/app_check_network_image.dart';

class ManageProductsScreen extends StatelessWidget {
  const ManageProductsScreen({super.key});

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

              if (products.isEmpty) {
                return const Center(
                  child: Text(
                    'No products have been added to SincerelySea Store yet.',
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: products.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (BuildContext context, int index) {
                  final Product product = products[index];
                  return _ManageProductCard(product: product);
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _ManageProductCard extends StatelessWidget {
  const _ManageProductCard({required this.product});

  final Product product;

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
                          label: product.availableForPurchase
                              ? 'Available'
                              : 'Paused',
                          color: product.availableForPurchase
                              ? Colors.blue
                              : Colors.grey,
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
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showEditSheet(context, product),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Product'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditSheet(BuildContext context, Product product) async {
    String inventoryType = product.inventoryType;
    bool availableForPurchase = product.availableForPurchase;
    final TextEditingController stockController = TextEditingController(
      text: product.stock.toString(),
    );
    final TextEditingController preorderDaysController = TextEditingController(
      text: product.preorderDays > 0 ? product.preorderDays.toString() : '',
    );
    final TextEditingController preorderNoteController = TextEditingController(
      text: product.preorderNote,
    );
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Future<void> save() async {
              final int stock = int.tryParse(stockController.text.trim()) ?? 0;
              final int preorderDays =
                  int.tryParse(preorderDaysController.text.trim()) ?? 0;
              if (inventoryType == 'ready_stock' && stock < 0) {
                ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                  const SnackBar(content: Text('Stock must be 0 or more.')),
                );
                return;
              }
              if (inventoryType == 'preorder' && preorderDays <= 0) {
                ScaffoldMessenger.of(bottomSheetContext).showSnackBar(
                  const SnackBar(
                    content: Text('Preorder days must be greater than 0.'),
                  ),
                );
                return;
              }

              setModalState(() => saving = true);
              try {
                await bottomSheetContext.read<ProductService>().updateProduct(
                  productId: product.id,
                  inventoryType: inventoryType,
                  stock: stock,
                  preorderDays: preorderDays,
                  preorderNote: preorderNoteController.text,
                  availableForPurchase: availableForPurchase,
                );
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

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Edit Product',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: inventoryType,
                      decoration: const InputDecoration(
                        labelText: 'Inventory type',
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(
                          value: 'ready_stock',
                          child: Text('Ready Stock'),
                        ),
                        DropdownMenuItem(
                          value: 'preorder',
                          child: Text('Preorder'),
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }
                        setModalState(() => inventoryType = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: availableForPurchase,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Available for purchase'),
                      subtitle: Text(
                        availableForPurchase
                            ? 'Customers can buy this product'
                            : 'Product is temporarily paused',
                      ),
                      onChanged: (bool value) {
                        setModalState(() => availableForPurchase = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (inventoryType == 'ready_stock')
                      TextField(
                        controller: stockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stock',
                        ),
                      )
                    else ...<Widget>[
                      TextField(
                        controller: preorderDaysController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Preorder days',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: preorderNoteController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Preorder note',
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: saving ? null : save,
                        child: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
