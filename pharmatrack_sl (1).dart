import 'dart:io';

// ================================================================
//  PharmaTrack SL - Pharmacy Inventory and Sales Management System
//  PROG 202 - Software Engineering | Assignment 1 (Dart Prototype)
// ================================================================

// ------------------------- MODELS -------------------------------

/// A staff member who can log in to the system.
class User {
  final String username;
  final String password;
  final String role; // "Admin" or "Pharmacist"

  User(this.username, this.password, this.role);

  bool get isAdmin => role == 'Admin';
}

/// A medicine kept in the pharmacy stock.
class Medicine {
  final String id;
  final String name;
  final String category;
  final double price; // price per unit in New Leones (NLe)
  int quantity; // current quantity in stock
  final int reorderLevel; // alert when stock is at or below this level
  final DateTime expiryDate;

  Medicine({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.quantity,
    required this.reorderLevel,
    required this.expiryDate,
  });

  bool get isLowStock => quantity <= reorderLevel;

  bool isExpired(DateTime today) => expiryDate.isBefore(today);

  int daysToExpiry(DateTime today) => expiryDate.difference(today).inDays;

  /// Returns a short status label used in the stock table.
  String status(DateTime today) {
    if (isExpired(today)) return 'EXPIRED';
    if (isLowStock) return 'LOW STOCK';
    if (daysToExpiry(today) <= 30) return 'EXPIRING SOON';
    return 'OK';
  }
}

/// One line on a receipt (one medicine and the quantity sold).
class SaleItem {
  final String medicineId;
  final String name;
  final double unitPrice;
  final int quantity;

  SaleItem(this.medicineId, this.name, this.unitPrice, this.quantity);

  double get subtotal => unitPrice * quantity;
}

/// A completed sale (a receipt) made up of one or more SaleItems.
class Sale {
  final String id;
  final String cashier;
  final DateTime date;
  final List<SaleItem> items;

  Sale(this.id, this.cashier, this.date, this.items);

  double get total => items.fold(0.0, (sum, item) => sum + item.subtotal);
}

// ------------------------ BUSINESS LOGIC ------------------------

/// Holds the data and the rules of the pharmacy system.
class PharmacyService {
  final List<User> users = [];
  final List<Medicine> medicines = [];
  final List<Sale> sales = [];
  int _saleCounter = 1000;

  /// Loads sample users and medicines so the prototype can be demonstrated.
  void loadSampleData() {
    users.add(User('admin', 'admin123', 'Admin'));
    users.add(User('pharm', 'pharm123', 'Pharmacist'));

    medicines.addAll([
      Medicine(id: 'M001', name: 'Paracetamol 500mg', category: 'Pain Relief',
          price: 5.00, quantity: 120, reorderLevel: 30,
          expiryDate: DateTime(2027, 8, 31)),
      Medicine(id: 'M002', name: 'Amoxicillin 250mg', category: 'Antibiotic',
          price: 12.00, quantity: 18, reorderLevel: 25,
          expiryDate: DateTime(2027, 3, 15)),
      Medicine(id: 'M003', name: 'Artemether-Lumefantrine', category: 'Antimalarial',
          price: 30.00, quantity: 45, reorderLevel: 20,
          expiryDate: DateTime(2027, 1, 20)),
      Medicine(id: 'M004', name: 'Oral Rehydration Salts', category: 'Rehydration',
          price: 3.00, quantity: 80, reorderLevel: 40,
          expiryDate: DateTime(2026, 10, 25)),
      Medicine(id: 'M005', name: 'Ibuprofen 400mg', category: 'Pain Relief',
          price: 7.00, quantity: 60, reorderLevel: 20,
          expiryDate: DateTime(2026, 9, 30)),
      Medicine(id: 'M006', name: 'Vitamin C 500mg', category: 'Supplement',
          price: 4.00, quantity: 15, reorderLevel: 15,
          expiryDate: DateTime(2027, 6, 30)),
    ]);
  }

  Medicine? findById(String id) {
    for (final m in medicines) {
      if (m.id == id) return m;
    }
    return null;
  }

  List<Medicine> search(String keyword) {
    final k = keyword.toLowerCase();
    return medicines
        .where((m) =>
            m.name.toLowerCase().contains(k) ||
            m.category.toLowerCase().contains(k))
        .toList();
  }

  Medicine addMedicine({
    required String name,
    required String category,
    required double price,
    required int quantity,
    required int reorderLevel,
    required DateTime expiryDate,
  }) {
    final id = 'M${(medicines.length + 1).toString().padLeft(3, '0')}';
    final med = Medicine(
      id: id,
      name: name,
      category: category,
      price: price,
      quantity: quantity,
      reorderLevel: reorderLevel,
      expiryDate: expiryDate,
    );
    medicines.add(med);
    return med;
  }

  bool restock(String id, int amount) {
    final med = findById(id);
    if (med == null || amount <= 0) return false;
    med.quantity += amount;
    return true;
  }

  /// Checks whether [qty] of [med] can be sold.
  /// Returns an error message, or null when the sale is allowed.
  String? checkSale(Medicine med, int qty, DateTime today, List<SaleItem> cart) {
    if (qty <= 0) return 'Quantity must be greater than zero.';
    if (med.isExpired(today)) {
      return '${med.name} has EXPIRED and cannot be sold.';
    }
    int alreadyInCart = 0;
    for (final item in cart) {
      if (item.medicineId == med.id) alreadyInCart += item.quantity;
    }
    if (qty + alreadyInCart > med.quantity) {
      return 'Insufficient stock for ${med.name}. Available: ${med.quantity}.';
    }
    return null;
  }

  /// Deducts the sold quantities from stock and records the sale.
  Sale completeSale(String cashier, List<SaleItem> cart, DateTime today) {
    for (final item in cart) {
      final med = findById(item.medicineId);
      if (med != null) med.quantity -= item.quantity;
    }
    _saleCounter++;
    final sale = Sale('S$_saleCounter', cashier, today, List.of(cart));
    sales.add(sale);
    return sale;
  }

  List<Medicine> lowStockList() => medicines.where((m) => m.isLowStock).toList();

  List<Medicine> expiredList(DateTime today) =>
      medicines.where((m) => m.isExpired(today)).toList();

  List<Medicine> expiringSoonList(DateTime today) => medicines
      .where((m) => !m.isExpired(today) && m.daysToExpiry(today) <= 30)
      .toList();

  double totalRevenue() => sales.fold(0.0, (sum, s) => sum + s.total);

  String topSellingItem() {
    final Map<String, int> units = {};
    for (final sale in sales) {
      for (final item in sale.items) {
        units[item.name] = (units[item.name] ?? 0) + item.quantity;
      }
    }
    String bestName = '';
    int bestUnits = 0;
    units.forEach((name, count) {
      if (count > bestUnits) {
        bestName = name;
        bestUnits = count;
      }
    });
    return bestUnits == 0 ? 'N/A' : '$bestName ($bestUnits units)';
  }
}

// ------------------------ HELPER FUNCTIONS ----------------------

String readText(String prompt) {
  stdout.write(prompt);
  return (stdin.readLineSync() ?? '').trim();
}

int? readInt(String prompt) => int.tryParse(readText(prompt));

double? readDouble(String prompt) => double.tryParse(readText(prompt));

String two(int n) => n.toString().padLeft(2, '0');

String fmtDate(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

String money(double v) => v.toStringAsFixed(2);

String cut(String s, int max) => s.length <= max ? s : s.substring(0, max);

String center(String text, int width) {
  final left = (width - text.length) ~/ 2;
  return ' ' * (left < 0 ? 0 : left) + text;
}

// ---------------------------- SCREENS ---------------------------

User? login(List<User> users) {
  print('\n--- LOGIN ---');
  print('Demo accounts you can use:');
  print('  Admin      -> username: admin   password: admin123');
  print('  Pharmacist -> username: pharm   password: pharm123');
  for (int attempt = 1; attempt <= 3; attempt++) {
    final name = readText('Username: ').toLowerCase();
    final pass = readText('Password: ');
    for (final user in users) {
      if (user.username == name && user.password == pass) return user;
    }
    print('Invalid username or password. Attempts left: ${3 - attempt}');
    print('(Tip: type the details exactly as shown above.)');
  }
  return null;
}

void printMenu(User user) {
  print('\n========== PHARMATRACK SL - MAIN MENU ==========');
  print('Logged in as: ${user.username} (${user.role})');
  print('1. View all medicines');
  print('2. Search medicine');
  print('3. Add new medicine (Admin)');
  print('4. Restock medicine (Admin)');
  print('5. Sell medicine');
  print('6. View alerts (low stock / expiry)');
  print('7. Sales report (Admin)');
  print('0. Logout');
  print('=' * 48);
}

void printMedicineTable(List<Medicine> list, DateTime today) {
  if (list.isEmpty) {
    print('No medicines found.');
    return;
  }
  print('ID'.padRight(6) +
      'Name'.padRight(24) +
      'Category'.padRight(13) +
      'Price(NLe)'.padLeft(11) +
      'Qty'.padLeft(6) +
      '  ' +
      'Expiry'.padRight(12) +
      'Status');
  print('-' * 87);
  for (final m in list) {
    print(m.id.padRight(6) +
        cut(m.name, 23).padRight(24) +
        cut(m.category, 12).padRight(13) +
        money(m.price).padLeft(11) +
        m.quantity.toString().padLeft(6) +
        '  ' +
        fmtDate(m.expiryDate).padRight(12) +
        m.status(today));
  }
}

void viewAll(PharmacyService s, DateTime today) {
  print('\n--- STOCK LIST (as of ${fmtDate(today)}) ---');
  printMedicineTable(s.medicines, today);
  print('Total medicines: ${s.medicines.length}');
}

void searchFlow(PharmacyService s, DateTime today) {
  print('\n--- SEARCH MEDICINE ---');
  final keyword = readText('Enter name or category: ');
  if (keyword.isEmpty) {
    print('Search keyword cannot be empty.');
    return;
  }
  printMedicineTable(s.search(keyword), today);
}

void addMedicineFlow(PharmacyService s) {
  print('\n--- ADD NEW MEDICINE ---');
  final name = readText('Medicine name: ');
  final category = readText('Category: ');
  final price = readDouble('Price per unit (NLe): ');
  final qty = readInt('Quantity received: ');
  final reorder = readInt('Reorder level: ');
  final expiry = DateTime.tryParse(readText('Expiry date (YYYY-MM-DD): '));

  if (name.isEmpty || category.isEmpty || price == null || price <= 0 ||
      qty == null || qty < 0 || reorder == null || reorder < 0 || expiry == null) {
    print('Invalid input. Medicine was not added.');
    return;
  }
  final med = s.addMedicine(
    name: name,
    category: category,
    price: price,
    quantity: qty,
    reorderLevel: reorder,
    expiryDate: expiry,
  );
  print('Medicine added successfully with ID ${med.id}.');
}

void restockFlow(PharmacyService s) {
  print('\n--- RESTOCK MEDICINE ---');
  final id = readText('Medicine ID: ').toUpperCase();
  final amount = readInt('Quantity to add: ');
  if (amount != null && s.restock(id, amount)) {
    final med = s.findById(id)!;
    print('Restocked ${med.name}. New quantity: ${med.quantity}.');
  } else {
    print('Restock failed: invalid medicine ID or quantity.');
  }
}

void printReceipt(Sale sale) {
  const w = 47;
  print('\n' + '=' * w);
  print(center('PHARMATRACK SL - SALES RECEIPT', w));
  print('=' * w);
  print('Receipt No : ${sale.id}');
  print('Date       : ${fmtDate(sale.date)}');
  print('Cashier    : ${sale.cashier}');
  print('-' * w);
  print('Item'.padRight(24) +
      'Qty'.padLeft(4) +
      'Price'.padLeft(9) +
      'Total'.padLeft(10));
  for (final item in sale.items) {
    print(cut(item.name, 23).padRight(24) +
        item.quantity.toString().padLeft(4) +
        money(item.unitPrice).padLeft(9) +
        money(item.subtotal).padLeft(10));
  }
  print('-' * w);
  print('TOTAL (NLe)'.padRight(37) + money(sale.total).padLeft(10));
  print(center('Thank you for your purchase!', w));
  print('=' * w);
}

void sellFlow(PharmacyService s, User user, DateTime today) {
  print('\n--- NEW SALE ---');
  final cart = <SaleItem>[];
  while (true) {
    final id = readText('Enter medicine ID (press Enter to finish): ').toUpperCase();
    if (id.isEmpty) break;

    final med = s.findById(id);
    if (med == null) {
      print('Error: medicine not found.');
      continue;
    }
    final qty = readInt('Quantity: ');
    if (qty == null) {
      print('Error: please enter a valid whole number.');
      continue;
    }
    final error = s.checkSale(med, qty, today, cart);
    if (error != null) {
      print('Error: $error');
      continue;
    }
    cart.add(SaleItem(med.id, med.name, med.price, qty));
    print('Added: ${med.name} x$qty');
  }

  if (cart.isEmpty) {
    print('No items selected. Sale cancelled.');
    return;
  }
  printReceipt(s.completeSale(user.username, cart, today));
}

void printAlerts(PharmacyService s, DateTime today) {
  print('\n---------- LOW STOCK ALERTS ----------');
  final low = s.lowStockList();
  if (low.isEmpty) print(' None');
  for (final m in low) {
    print(' - ${m.name}: ${m.quantity} left (reorder level: ${m.reorderLevel})');
  }

  print('\n---------- EXPIRED MEDICINES ---------');
  final expired = s.expiredList(today);
  if (expired.isEmpty) print(' None');
  for (final m in expired) {
    print(' - ${m.name} expired on ${fmtDate(m.expiryDate)}');
  }

  print('\n------- EXPIRING WITHIN 30 DAYS ------');
  final soon = s.expiringSoonList(today);
  if (soon.isEmpty) print(' None');
  for (final m in soon) {
    print(' - ${m.name} expires in ${m.daysToExpiry(today)} days '
        '(${fmtDate(m.expiryDate)})');
  }
}

void salesReport(PharmacyService s) {
  print('\n=============== SALES REPORT ===============');
  if (s.sales.isEmpty) {
    print('No sales recorded yet.');
    return;
  }
  print('Sale ID'.padRight(9) +
      'Date'.padRight(12) +
      'Cashier'.padRight(12) +
      'Items'.padLeft(5) +
      'Total(NLe)'.padLeft(13));
  print('-' * 51);
  for (final sale in s.sales) {
    print(sale.id.padRight(9) +
        fmtDate(sale.date).padRight(12) +
        sale.cashier.padRight(12) +
        sale.items.length.toString().padLeft(5) +
        money(sale.total).padLeft(13));
  }
  print('-' * 51);
  print('Total transactions : ${s.sales.length}');
  print('Total revenue      : NLe ${money(s.totalRevenue())}');
  print('Top-selling item   : ${s.topSellingItem()}');
}

// ---------------------------- MAIN MENU -------------------------

void runMenu(PharmacyService s, User user, DateTime today) {
  var running = true;
  while (running) {
    printMenu(user);
    final choice = readText('Enter choice: ');
    switch (choice) {
      case '1':
        viewAll(s, today);
        break;
      case '2':
        searchFlow(s, today);
        break;
      case '3':
        if (user.isAdmin) {
          addMedicineFlow(s);
        } else {
          print('Access denied: this option is for Admin only.');
        }
        break;
      case '4':
        if (user.isAdmin) {
          restockFlow(s);
        } else {
          print('Access denied: this option is for Admin only.');
        }
        break;
      case '5':
        sellFlow(s, user, today);
        break;
      case '6':
        printAlerts(s, today);
        break;
      case '7':
        if (user.isAdmin) {
          salesReport(s);
        } else {
          print('Access denied: this option is for Admin only.');
        }
        break;
      case '0':
        running = false;
        break;
      default:
        print('Invalid choice. Please enter a number from the menu.');
    }
  }
}

void main() {
  final service = PharmacyService();
  service.loadSampleData();

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  print('=' * 47);
  print(center('PHARMATRACK SL', 47));
  print(center('Pharmacy Inventory & Sales System', 47));
  print('=' * 47);

  final user = login(service.users);
  if (user == null) {
    print('Too many failed attempts. Exiting.');
    return;
  }
  print('\nWelcome, ${user.username} (${user.role})!');
  runMenu(service, user, today);
  print('\nLogged out. Goodbye!');
}
