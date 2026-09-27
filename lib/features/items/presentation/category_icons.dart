import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../logic/item_category.dart';

/// The icon the design gives each built-in category. A category a member
/// added gets the generic one.
IconData categoryIcon(String stored) =>
    switch (BuiltInCategory.fromKey(normalizeCategory(stored))) {
      BuiltInCategory.produce => Symbols.eco_rounded,
      BuiltInCategory.dairy => Symbols.egg_rounded,
      BuiltInCategory.meatFish => Symbols.set_meal_rounded,
      BuiltInCategory.bakery => Symbols.bakery_dining_rounded,
      BuiltInCategory.pantry => Symbols.kitchen_rounded,
      BuiltInCategory.frozen => Symbols.ac_unit_rounded,
      BuiltInCategory.drinks => Symbols.local_drink_rounded,
      BuiltInCategory.household => Symbols.cleaning_services_rounded,
      BuiltInCategory.other || null => Symbols.category_rounded,
    };
