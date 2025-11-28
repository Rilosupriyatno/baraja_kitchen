// screens/create_menu_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/menu_model.dart';
import '../services/menu_service.dart';

class CreateMenuScreen extends StatefulWidget {
  const CreateMenuScreen({super.key});

  @override
  State<CreateMenuScreen> createState() => _CreateMenuScreenState();
}

class _CreateMenuScreenState extends State<CreateMenuScreen> {
  final _formKey = GlobalKey<FormState>();
  final MenuService _menuService = MenuService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  String _selectedMainCategory = 'minuman';
  String? _selectedCategory;
  List<String> _selectedOutlets = [];
  File? _imageFile;
  List<String> _rawMaterials = [];
  List<Topping> _toppings = [];
  List<Addon> _addons = [];
  bool _isLoading = false;

  // Recipe related
  bool _createRecipe = false;
  List<BaseIngredient> _baseIngredients = [];
  List<ToppingOption> _toppingOptions = [];
  List<AddonOption> _addonOptions = [];
  List<dynamic> _products = [];

  // Data from API
  List<String> _mainCategories = ['makanan', 'minuman', 'dessert', 'snack', 'event'];
  List<dynamic> _allCategories = [];
  List<dynamic> _filteredCategories = [];
  List<dynamic> _outlets = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    await Future.wait([
      _fetchCategories(),
      _fetchOutlets(),
      _fetchProducts(),
    ]);

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchCategories() async {
    try {
      final data = await _menuService.fetchCategories();
      setState(() {
        _allCategories = data;
        _filterCategories();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat kategori: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchOutlets() async {
    try {
      final data = await _menuService.fetchOutlets();
      setState(() {
        _outlets = data;
        if (_outlets.isNotEmpty) {
          _selectedOutlets = [_outlets[0]['_id']?.toString() ?? ''];
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat outlet: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchProducts() async {
    try {
      final data = await _menuService.fetchProducts();
      setState(() {
        _products = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat produk: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterCategories() {
    _filteredCategories = _allCategories.where((cat) {
      return cat['parentCategory'] == null;
    }).toList();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
  }

  // Show searchable dropdown for Main Category
  void _showMainCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final searchController = TextEditingController();
        List<String> filtered = List.from(_mainCategories);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Pilih Main Category'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: 'Cari...',
                        prefixIcon: Icon(Icons.search, color: Colors.deepOrange),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          filtered = _mainCategories
                              .where((cat) => cat.toLowerCase().contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: filtered.isEmpty
                          ? Center(child: Text('Tidak ada hasil'))
                          : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final cat = filtered[index];
                          final isSelected = _selectedMainCategory == cat;
                          return ListTile(
                            title: Text(cat[0].toUpperCase() + cat.substring(1)),
                            leading: Radio<String>(
                              value: cat,
                              groupValue: _selectedMainCategory,
                              activeColor: Colors.deepOrange,
                              onChanged: (value) {
                                setState(() {
                                  _selectedMainCategory = value!;
                                  _selectedCategory = null;
                                });
                                Navigator.pop(context);
                              },
                            ),
                            selected: isSelected,
                            selectedTileColor: Colors.orange.shade50,
                            onTap: () {
                              setState(() {
                                _selectedMainCategory = cat;
                                _selectedCategory = null;
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Tutup'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show searchable dropdown for Category
  void _showCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final searchController = TextEditingController();
        List<dynamic> filtered = List.from(_filteredCategories);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Pilih Category'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: 'Cari...',
                        prefixIcon: Icon(Icons.search, color: Colors.deepOrange),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          filtered = _filteredCategories
                              .where((cat) => (cat['name'] ?? '')
                              .toLowerCase()
                              .contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      height: 300,
                      child: filtered.isEmpty
                          ? Center(child: Text('Tidak ada hasil'))
                          : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final cat = filtered[index];
                          final catId = cat['_id']?.toString();
                          final isSelected = _selectedCategory == catId;
                          return ListTile(
                            title: Text(cat['name'] ?? 'Unknown'),
                            leading: Radio<String>(
                              value: catId ?? '',
                              groupValue: _selectedCategory ?? '',
                              activeColor: Colors.deepOrange,
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategory = value;
                                });
                                Navigator.pop(context);
                              },
                            ),
                            selected: isSelected,
                            selectedTileColor: Colors.orange.shade50,
                            onTap: () {
                              setState(() {
                                _selectedCategory = catId;
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Tutup'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show searchable multi-select for Outlets
  void _showOutletDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final searchController = TextEditingController();
        List<dynamic> filtered = List.from(_outlets);
        List<String> tempSelected = List.from(_selectedOutlets);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Pilih Outlet'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: 'Cari outlet...',
                        prefixIcon: Icon(Icons.search, color: Colors.deepOrange),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          filtered = _outlets
                              .where((outlet) =>
                          (outlet['name'] ?? '')
                              .toLowerCase()
                              .contains(value.toLowerCase()) ||
                              (outlet['city'] ?? '')
                                  .toLowerCase()
                                  .contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      height: 300,
                      child: filtered.isEmpty
                          ? Center(child: Text('Tidak ada hasil'))
                          : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final outlet = filtered[index];
                          final outletId = outlet['_id']?.toString() ?? '';
                          final isSelected = tempSelected.contains(outletId);
                          return CheckboxListTile(
                            title: Text(outlet['name'] ?? 'Unknown'),
                            subtitle: Text(
                              outlet['city'] ?? '',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: isSelected,
                            activeColor: Colors.deepOrange,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  tempSelected.add(outletId);
                                } else {
                                  tempSelected.remove(outletId);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Batal', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedOutlets = tempSelected;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pilih kategori terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedOutlets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pilih minimal satu outlet'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_createRecipe && _baseIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tambahkan minimal 1 bahan utama untuk resep'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String imageURL = '';

      if (_imageFile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Mengupload gambar...'),
              ],
            ),
            duration: Duration(seconds: 30),
            backgroundColor: Colors.blue,
          ),
        );

        imageURL = await _menuService.uploadImage(_imageFile!);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      final menuItem = MenuItem(
        name: _nameController.text,
        description: _descriptionController.text,
        price: double.parse(_priceController.text),
        imageURL: imageURL,
        mainCat: _selectedMainCategory,
        category: _selectedCategory!,
        subCategory: null,
        availableAt: _selectedOutlets,
        rawMaterials: _rawMaterials,
        toppings: _toppings,
        addons: _addons,
        workstation: 'bar',
      );

      String? menuItemId = await _menuService.createMenuItem(menuItem);

      if (_createRecipe && menuItemId != null) {
        await _menuService.createRecipe(
          menuItemId: menuItemId,
          baseIngredients: _baseIngredients,
          toppingOptions: _toppingOptions,
          addonOptions: _addonOptions,
        );
      }

      if (mounted) {
        Navigator.pop(context, {
          'success': true,
          'message': _createRecipe
              ? 'Menu dan resep ${_nameController.text} berhasil dibuat'
              : 'Menu ${_nameController.text} berhasil dibuat'
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _addTopping() {
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final priceController = TextEditingController();

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add_circle, color: Colors.orange),
              ),
              SizedBox(width: 12),
              Text('Tambah Topping', style: TextStyle(fontSize: 20)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Topping',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: InputDecoration(
                  labelText: 'Harga',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.attach_money),
                  prefixText: 'Rp ',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    priceController.text.isNotEmpty) {
                  setState(() {
                    _toppings.add(Topping(
                      name: nameController.text,
                      price: double.parse(priceController.text),
                    ));
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Tambah'),
            ),
          ],
        );
      },
    );
  }

  void _addBaseIngredient() {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedProduct;
        final quantityController = TextEditingController();
        final searchController = TextEditingController();
        List<dynamic> filtered = List.from(_products);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Tambah Bahan Utama'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: 'Cari Produk',
                        prefixIcon: Icon(Icons.search, color: Colors.deepOrange),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          filtered = _products
                              .where((p) =>
                          (p['name'] ?? '')
                              .toLowerCase()
                              .contains(value.toLowerCase()) ||
                              (p['sku'] ?? '')
                                  .toLowerCase()
                                  .contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    Container(
                      width: double.maxFinite,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: filtered.isEmpty
                          ? Center(child: Text('Tidak ada hasil'))
                          : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final product = filtered[index];
                          final productId = product['_id'].toString();
                          final isSelected = selectedProduct == productId;
                          return ListTile(
                            title: Text(product['name'] ?? 'Unknown'),
                            subtitle: Text('${product['sku']} - ${product['unit']}'),
                            leading: Radio<String>(
                              value: productId,
                              groupValue: selectedProduct,
                              activeColor: Colors.deepOrange,
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedProduct = value;
                                });
                              },
                            ),
                            selected: isSelected,
                            selectedTileColor: Colors.orange.shade50,
                            onTap: () {
                              setDialogState(() {
                                selectedProduct = productId;
                              });
                            },
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: quantityController,
                      decoration: InputDecoration(
                        labelText: 'Jumlah',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedProduct != null && quantityController.text.isNotEmpty) {
                      final product = _products.firstWhere((p) => p['_id'].toString() == selectedProduct);
                      setState(() {
                        _baseIngredients.add(BaseIngredient(
                          productId: selectedProduct!,
                          productName: product['name'],
                          productSku: product['sku'],
                          quantity: double.parse(quantityController.text),
                          unit: product['unit'],
                          isDefault: true,
                        ));
                      });
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Tambah'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.local_bar, size: 24),
            ),
            SizedBox(width: 12),
            Text('Buat Menu Bar', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.deepOrange),
            SizedBox(height: 16),
            Text(
              'Memuat data...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      )
          : Form(
        key: _formKey,
        child: isTablet ? _buildTabletLayout() : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildImagePicker(),
                  SizedBox(height: 24),
                  _buildInfoCard(),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFormFields(),
                SizedBox(height: 24),
                _buildToppingsSection(),
                SizedBox(height: 24),
                _buildRecipeSection(),
                SizedBox(height: 32),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildImagePicker(),
          SizedBox(height: 20),
          _buildInfoCard(),
          SizedBox(height: 20),
          _buildFormFields(),
          SizedBox(height: 24),
          _buildToppingsSection(),
          SizedBox(height: 24),
          _buildRecipeSection(),
          SizedBox(height: 24),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildRecipeSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: _createRecipe,
                onChanged: (value) {
                  setState(() {
                    _createRecipe = value ?? false;
                  });
                },
                activeColor: Colors.deepOrange,
              ),
              Expanded(
                child: Text(
                  'Buat Resep untuk Menu Ini',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          if (_createRecipe) ...[
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bahan Utama',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _addBaseIngredient,
                  icon: Icon(Icons.add, size: 18),
                  label: Text('Tambah'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (_baseIngredients.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Belum ada bahan utama',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ...List.generate(_baseIngredients.length, (index) {
                final ingredient = _baseIngredients[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(ingredient.productName),
                    subtitle: Text('${ingredient.quantity} ${ingredient.unit}'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _baseIngredients.removeAt(index);
                        });
                      },
                    ),
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foto Menu',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 12),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: _imageFile != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(_imageFile!, fit: BoxFit.cover),
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_photo_alternate,
                    size: 48,
                    color: Colors.deepOrange,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Tap untuk pilih gambar',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Ukuran maksimal 5MB',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepOrange.shade400, Colors.orange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.local_bar, color: Colors.white, size: 32),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Workstation: Bar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Menu ini akan ditampilkan di area bar',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informasi Menu',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 16),
        _buildTextField(
          controller: _nameController,
          label: 'Nama Menu',
          icon: Icons.restaurant_menu,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Nama menu tidak boleh kosong';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        _buildTextField(
          controller: _descriptionController,
          label: 'Deskripsi',
          icon: Icons.description_outlined,
          maxLines: 3,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Deskripsi tidak boleh kosong';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        _buildTextField(
          controller: _priceController,
          label: 'Harga',
          icon: Icons.payments_outlined,
          keyboardType: TextInputType.number,
          prefix: 'Rp ',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Harga tidak boleh kosong';
            }
            if (double.tryParse(value) == null) {
              return 'Harga harus berupa angka';
            }
            return null;
          },
        ),
        SizedBox(height: 24),
        Text(
          'Kategori & Outlet',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 16),
        _buildSearchableDropdown(
          label: 'Main Category',
          icon: Icons.category_outlined,
          value: _selectedMainCategory[0].toUpperCase() + _selectedMainCategory.substring(1),
          onTap: _showMainCategoryDialog,
        ),
        SizedBox(height: 16),
        _buildSearchableDropdown(
          label: 'Category',
          icon: Icons.grid_view_rounded,
          value: _selectedCategory != null
              ? _filteredCategories.firstWhere(
                  (cat) => cat['_id']?.toString() == _selectedCategory,
              orElse: () => {'name': 'Pilih kategori'}
          )['name'] ?? 'Pilih kategori'
              : 'Pilih kategori',
          onTap: _showCategoryDialog,
          isError: _selectedCategory == null,
        ),
        SizedBox(height: 16),
        _buildSearchableDropdown(
          label: 'Outlet (${_selectedOutlets.length} dipilih)',
          icon: Icons.store_outlined,
          value: _selectedOutlets.isEmpty
              ? 'Pilih outlet'
              : '${_selectedOutlets.length} outlet dipilih',
          onTap: _showOutletDialog,
          isError: _selectedOutlets.isEmpty,
        ),
      ],
    );
  }

  Widget _buildSearchableDropdown({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
    bool isError = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isError ? Colors.red : Colors.grey[300]!,
            width: isError ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.deepOrange),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      color: value.contains('Pilih') ? Colors.grey[400] : Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildToppingsSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add_circle, color: Colors.orange, size: 20),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Toppings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _addTopping,
                icon: Icon(Icons.add, size: 18),
                label: Text('Tambah'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          if (_toppings.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[400], size: 48),
                    SizedBox(height: 8),
                    Text(
                      'Belum ada topping',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            ...List.generate(_toppings.length, (index) {
              final topping = _toppings[index];
              return Container(
                margin: EdgeInsets.only(top: 12),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topping.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Rp ${topping.price.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _toppings.removeAt(index);
                        });
                      },
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _handleSubmit,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
        shadowColor: Colors.deepOrange.withOpacity(0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 24),
          SizedBox(width: 12),
          Text(
            'Simpan Menu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? prefix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.deepOrange),
        prefixText: prefix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.deepOrange, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}

// Model classes for Recipe
class BaseIngredient {
  final String productId;
  final String productName;
  final String productSku;
  final double quantity;
  final String unit;
  final bool isDefault;

  BaseIngredient({
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.quantity,
    required this.unit,
    required this.isDefault,
  });

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'productSku': productSku,
      'quantity': quantity,
      'unit': unit,
      'isDefault': isDefault,
    };
  }
}

class ToppingOption {
  final String toppingName;
  final List<BaseIngredient> ingredients;

  ToppingOption({
    required this.toppingName,
    required this.ingredients,
  });

  Map<String, dynamic> toJson() {
    return {
      'toppingName': toppingName,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
    };
  }
}

class AddonOption {
  final String addonName;
  final String optionLabel;
  final List<BaseIngredient> ingredients;

  AddonOption({
    required this.addonName,
    required this.optionLabel,
    required this.ingredients,
  });

  Map<String, dynamic> toJson() {
    return {
      'addonName': addonName,
      'optionLabel': optionLabel,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
    };
  }
}