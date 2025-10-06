import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math; // added for logarithmic scoring
import 'package:supabase_flutter/supabase_flutter.dart';

class IngredientEntry {
  final String original;
  final String name;
  final double? quantity; // retained for backward compatibility (single value)
  final String? unit;
  // New: support ranges & tags
  final double? quantityMin;
  final double? quantityMax;
  final List<String> tags;

  IngredientEntry({
    required this.original,
    required this.name,
    this.quantity,
    this.unit,
    this.quantityMin,
    this.quantityMax,
    this.tags = const [],
  });

  IngredientEntry copyWith({
    String? original,
    String? name,
    double? quantity,
    String? unit,
    double? quantityMin,
    double? quantityMax,
    List<String>? tags,
  }) => IngredientEntry(
    original: original ?? this.original,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    quantityMin: quantityMin ?? this.quantityMin,
    quantityMax: quantityMax ?? this.quantityMax,
    tags: tags ?? this.tags,
  );

  Map<String,dynamic> toMap() => {
    'o': original,
    'n': name,
    'q': quantity, // legacy single
    'u': unit,
    'qMin': quantityMin,
    'qMax': quantityMax,
    't': tags,
  };
  factory IngredientEntry.fromMap(Map<String,dynamic> m) => IngredientEntry(
    original: m['o'] as String,
    name: m['n'] as String,
    quantity: (m['q'] is num) ? (m['q'] as num).toDouble() : null,
    unit: m['u'] as String?,
    quantityMin: (m['qMin'] is num) ? (m['qMin'] as num).toDouble() : (m['q'] is num ? (m['q'] as num).toDouble(): null),
    quantityMax: (m['qMax'] is num) ? (m['qMax'] as num).toDouble() : (m['q'] is num ? (m['q'] as num).toDouble(): null),
    tags: (m['t'] is List) ? (m['t'] as List).whereType<String>().toList() : const [],
  );
}

enum AddResult { added, duplicate, invalid }

class IngredientsProvider extends ChangeNotifier {
  static const _prefsKeyV1 = 'ingredients_v1'; // legacy (List<String>)
  static const _prefsKeyV2 = 'ingredients_v2'; // new structured list
  static const _prefsKeyUsage = 'ingredients_usage_v1';
  static const _remoteTable = 'pantry_items';
  final List<IngredientEntry> _entries = [];
  final Map<String,int> _usage = {}; // usage frequency for ranking suggestions
  bool _loaded = false;
  String? _currentUserId;
  bool _remoteSyncing = false;
  String? _lastRemoteError;

  // Basic synonym + canonical forms (can be expanded)
  static const Map<String, String> _synonyms = {
    'tomatoes': 'tomato',
    'potatoes': 'potato',
    'chillies': 'chili',
    'chilies': 'chili',
    'chilli': 'chili',
    'bell peppers': 'bell pepper',
    'bell pepper': 'bell pepper',
    'capsicum': 'bell pepper',
    'mushrooms': 'mushroom',
    'eggs': 'egg',
    'onions': 'onion',
    'carrots': 'carrot',
    'cloves garlic': 'garlic',
    'pickles': 'pickle',
  };

  // Backwards-compatible simple names list (unique, sorted)
  List<String> get ingredients => _entries.map((e)=>e.name).toSet().toList()..sort();
  List<IngredientEntry> get entries => List.unmodifiable(_entries);
  bool get isLoaded => _loaded;
  bool get remoteSyncing => _remoteSyncing;
  String? get lastRemoteError => _lastRemoteError;
  String? get currentUserId => _currentUserId;

  String _storageKey(String base, String? userId) => '${base}_${userId ?? 'anon'}';

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // Additional default tags for hash (#) suggestions
  static const List<String> _defaultTags = [
    'vegan','vegetarian','glutenfree','dairyfree','lowcarb','keto','paleo','spicy','sweet','savory','organic','fresh','quick','simple','holiday','grill','bake'
  ];

  // Expanded pantry / produce / protein / spice suggestions
  static const List<String> _extended = [
    'apple','banana','orange','strawberry','blueberry','raspberry','grape','pineapple','mango','avocado','broccoli','cauliflower','zucchini','cucumber','bell pepper','jalapeno','chili','potato','sweet potato','pumpkin','squash','kale','lettuce','cabbage','corn','peas','green beans','black beans','kidney beans','chickpeas','lentils','quinoa','oats','bread','tortilla','buttermilk','cream','heavy cream','whipping cream','sour cream','cottage cheese','mozzarella','cheddar','parmesan','feta','goat cheese','ricotta','almond milk','coconut milk','coconut cream','peanut butter','almond butter','tahini','sesame oil','canola oil','vegetable oil','sunflower oil','coconut oil','brown sugar','powdered sugar','vanilla','cinnamon','nutmeg','clove','paprika','smoked paprika','cumin','turmeric','coriander','cardamom','cayenne','chili powder','italian seasoning','rosemary','thyme','sage','dill','mint','cilantro','bay leaf','yeast','baking powder','baking soda','cornstarch','cocoa powder','chocolate chips','maple syrup','molasses','mustard','mayonnaise','ketchup','hot sauce','sriracha','barbecue sauce','fish sauce','oyster sauce','hoisin sauce','sesame seeds','pumpkin seeds','sunflower seeds','chia seeds','flax seeds','walnut','almond','pecan','cashew','pistachio','hazelnut','shrimp','salmon','tuna','cod','tilapia','anchovy','clam','mussel','scallop','tofu','tempeh','seitan','bacon','sausage','ham','turkey','lamb','duck','eggplant','arugula','leek','shallot','scallion','green onion','lime juice','lemon juice','zest','ginger root','garlic powder','onion powder','broth','chicken broth','beef broth','vegetable broth','stock','gelatin','panko','breadcrumbs','noodles','spaghetti','linguine','fettuccine','udon','soba','rice vinegar','balsamic vinegar','apple cider vinegar','red wine vinegar','white wine vinegar','white vinegar','powdered gelatin','agave','salsa','guacamole','relish','pickle','pickle juice','capers'
  ];

  // Recent additions (in-memory, not persisted) to boost suggestions
  final List<String> _recent = [];
  static const int _recentCap = 12;

  Future<void> load() async {
    if (_loaded) return;
    await _loadFor(userId: _currentUserId);
  }

  Future<void> _loadFor({required String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final String storageKeyV2 = _storageKey(_prefsKeyV2, userId);
    final String storageKeyUsage = _storageKey(_prefsKeyUsage, userId);

    _entries.clear();
    _usage.clear();

    String? rawV2 = prefs.getString(storageKeyV2);
    if (rawV2 == null && userId == null) {
      rawV2 = prefs.getString(_prefsKeyV2);
    }

    if (rawV2 != null) {
      try {
        final list = (json.decode(rawV2) as List).cast<Map>();
        _entries.addAll(list.map((m) => IngredientEntry.fromMap(Map<String, dynamic>.from(m))));
      } catch (e) {
        debugPrint('IngredientsProvider: failed to decode structured pantry data: $e');
      }
    } else if (userId == null) {
      final rawV1 = prefs.getString(_prefsKeyV1);
      if (rawV1 != null) {
        try {
          final list = (json.decode(rawV1) as List).cast<String>();
          for (final s in list) {
            final parsed = _parseIngredient(s);
            if (parsed.name.isNotEmpty && !_isDuplicate(parsed)) {
              _entries.add(parsed);
            }
          }
        } catch (e) {
          debugPrint('IngredientsProvider: failed to migrate legacy pantry data: $e');
        }
      }
    }

    String? rawUsage = prefs.getString(storageKeyUsage);
    if (rawUsage == null && userId == null) {
      rawUsage = prefs.getString(_prefsKeyUsage);
    }
    if (rawUsage != null) {
      try {
        final m = (json.decode(rawUsage) as Map).cast<String, dynamic>();
        m.forEach((k, v) {
          if (v is num) _usage[k] = v.toInt();
        });
      } catch (e) {
        debugPrint('IngredientsProvider: failed to decode usage map: $e');
      }
    }

    _loaded = true;
    await _persist();
    notifyListeners();
  }

  Future<void> switchUser(String? userId) async {
    if (_currentUserId == userId) return;
    if (_loaded) {
      await _persist();
    }
    _currentUserId = userId;
    _loaded = false;
    _recent.clear();
    await _loadFor(userId: userId);
    if (_currentUserId != null) {
      unawaited(_pullRemoteMerge());
    }
  }

  Future<void> _persist() async {
    if (!_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey(_prefsKeyV2, _currentUserId), json.encode(_entries.map((e)=>e.toMap()).toList()));
    await prefs.setString(_storageKey(_prefsKeyUsage, _currentUserId), json.encode(_usage));
  }

  Map<String, dynamic> _remotePayloadFor(IngredientEntry entry) => {
    'user_id': _currentUserId,
    'name': entry.name,
    'serialized': entry.toMap(),
    'original': entry.original,
  };

  IngredientEntry? _entryFromRemote(dynamic raw, {required String fallbackName, String? fallbackOriginal}) {
    try {
      Map<String, dynamic>? map;
      if (raw is Map<String, dynamic>) {
        map = raw;
      } else if (raw is Map) {
        map = Map<String, dynamic>.from(raw as Map);
      } else if (raw is String) {
        map = Map<String, dynamic>.from(json.decode(raw) as Map);
      }
      if (map == null) {
        return null;
      }
      final entry = IngredientEntry.fromMap(map);
      if (entry.name.isEmpty && fallbackName.isNotEmpty) {
        return entry.copyWith(name: fallbackName, original: fallbackOriginal ?? entry.original);
      }
      return entry;
    } catch (e) {
      debugPrint('IngredientsProvider: failed to parse remote row: $e');
      return null;
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _entriesEqual(IngredientEntry a, IngredientEntry b) {
    return a.original == b.original &&
        a.name == b.name &&
        a.quantity == b.quantity &&
        a.quantityMin == b.quantityMin &&
        a.quantityMax == b.quantityMax &&
        a.unit == b.unit &&
        _listEquals(a.tags, b.tags);
  }

  Future<void> _pullRemoteMerge() async {
    final client = _client;
    final userId = _currentUserId;
    if (client == null || userId == null) {
      return;
    }
    _remoteSyncing = true;
    _lastRemoteError = null;
    notifyListeners();
    try {
      final response = await client
          .from(_remoteTable)
          .select('name, serialized, original')
          .eq('user_id', userId);
      bool changed = false;
      for (final row in response) {
        final name = (row['name'] ?? '') as String;
        final entry = _entryFromRemote(row['serialized'], fallbackName: name, fallbackOriginal: row['original'] as String?);
        if (entry == null || entry.name.isEmpty) continue;
        final idx = _entries.indexWhere((e) => e.name == entry.name);
        if (idx == -1) {
          _entries.add(entry);
          changed = true;
        } else if (!_entriesEqual(_entries[idx], entry)) {
          _entries[idx] = entry;
          changed = true;
        }
      }
      if (changed) {
        await _persist();
        notifyListeners();
      }
      await _pushAllRemote();
    } on PostgrestException catch (e) {
      _lastRemoteError = e.message;
      debugPrint('IngredientsProvider: remote sync error: ${e.message}');
    } catch (e) {
      _lastRemoteError = e.toString();
      debugPrint('IngredientsProvider: remote sync error: $e');
    } finally {
      _remoteSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _pushAllRemote() async {
    final client = _client;
    final userId = _currentUserId;
    if (client == null || userId == null) return;
    if (_entries.isEmpty) return;
    try {
      await client.from(_remoteTable).upsert(_entries.map(_remotePayloadFor).toList());
    } on PostgrestException catch (e) {
      _lastRemoteError = e.message;
      debugPrint('IngredientsProvider: bulk upsert error: ${e.message}');
    } catch (e) {
      _lastRemoteError = e.toString();
      debugPrint('IngredientsProvider: bulk upsert error: $e');
    }
  }

  Future<void> _pushRemoteEntry(IngredientEntry entry) async {
    final client = _client;
    final userId = _currentUserId;
    if (client == null || userId == null) return;
    try {
      await client.from(_remoteTable).upsert(_remotePayloadFor(entry));
    } on PostgrestException catch (e) {
      _lastRemoteError = e.message;
      debugPrint('IngredientsProvider: entry upsert error: ${e.message}');
    } catch (e) {
      _lastRemoteError = e.toString();
      debugPrint('IngredientsProvider: entry upsert error: $e');
    }
  }

  Future<void> _deleteRemote(String name) async {
    final client = _client;
    final userId = _currentUserId;
    if (client == null || userId == null) return;
    try {
      await client.from(_remoteTable).delete().match({'user_id': userId, 'name': name});
    } on PostgrestException catch (e) {
      _lastRemoteError = e.message;
      debugPrint('IngredientsProvider: entry delete error: ${e.message}');
    } catch (e) {
      _lastRemoteError = e.toString();
      debugPrint('IngredientsProvider: entry delete error: $e');
    }
  }

  Future<void> _clearRemote() async {
    final client = _client;
    final userId = _currentUserId;
    if (client == null || userId == null) return;
    try {
      await client.from(_remoteTable).delete().eq('user_id', userId);
    } on PostgrestException catch (e) {
      _lastRemoteError = e.message;
      debugPrint('IngredientsProvider: clear error: ${e.message}');
    } catch (e) {
      _lastRemoteError = e.toString();
      debugPrint('IngredientsProvider: clear error: $e');
    }
  }

  void _incrementUsageInternal(String name) {
    _usage[name] = (_usage[name] ?? 0) + 1;
  }

  void incrementUsage(String name) { // public if UI wants to nudge ranking
    final key = _normalizeName(name);
    if (key.isEmpty) return;
    _incrementUsageInternal(key);
    unawaited(_persist());
  }

  // Public simple add returning result
  Future<AddResult> add(String input) async { // modified to track recent
    final parsed = _parseIngredient(input);
    if (parsed.name.isEmpty) return AddResult.invalid;
    if (_isDuplicate(parsed)) return AddResult.duplicate;
    _entries.add(parsed);
    _incrementUsageInternal(parsed.name);
    _recent.remove(parsed.name); // move to front
    _recent.insert(0, parsed.name);
    if (_recent.length > _recentCap) _recent.removeLast();
    notifyListeners();
    await _persist();
    unawaited(_pushRemoteEntry(parsed));
    return AddResult.added;
  }

  Future<int> addMany(Iterable<String> list) async { // modified to track recent
    int added = 0;
    final List<IngredientEntry> newEntries = [];
    for (final raw in list) {
      final parsed = _parseIngredient(raw);
      if (parsed.name.isEmpty) continue;
      if (_isDuplicate(parsed)) continue;
      _entries.add(parsed);
      _incrementUsageInternal(parsed.name);
      _recent.remove(parsed.name);
      _recent.insert(0, parsed.name);
      if (_recent.length > _recentCap) _recent.removeLast();
      newEntries.add(parsed);
      added++;
    }
    if (added > 0) {
      notifyListeners();
      await _persist();
      for (final entry in newEntries) {
        unawaited(_pushRemoteEntry(entry));
      }
    }
    return added;
  }

  Future<bool> replaceEntry(IngredientEntry existing, String newRaw) async {
    final idx = _entries.indexOf(existing);
    if (idx == -1) return false;
    final parsed = _parseIngredient(newRaw);
    if (parsed.name.isEmpty) return false;
    // Allow same entry name (editing) but prevent collisions with other entries
    if (_entries.where((e)=> e != existing).any((e)=> e.name == parsed.name || _levenshtein(e.name, parsed.name) <= 2)) {
      return false;
    }
    _entries[idx] = parsed;
    notifyListeners();
    await _persist();
    unawaited(_pushRemoteEntry(parsed));
    if (existing.name != parsed.name) {
      unawaited(_deleteRemote(existing.name));
    }
    return true;
  }

  Future<void> remove(String ingredientName) async {
    bool removed = false;
    _entries.removeWhere((e) {
      if (e.name == ingredientName) {
        removed = true;
        return true;
      }
      return false;
    });
    if (!removed) return;
    notifyListeners();
    await _persist();
    unawaited(_deleteRemote(ingredientName));
  }

  Future<void> clear() async {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
    await _persist();
    unawaited(_clearRemote());
  }

  IngredientEntry? entryByName(String name) {
    final key = _normalizeName(name);
    try {return _entries.firstWhere((e)=> e.name == key);} catch (_) {return null;}
  }

  // Public parse preview (non-mutating)
  IngredientEntry parsePreview(String raw) => _parseIngredient(raw);

  // Autocomplete suggestions (static + existing)
  static const _common = [
    'egg','milk','butter','flour','sugar','salt','pepper','garlic','onion','tomato','olive oil','chicken','beef','pork','carrot','celery','parsley','basil','oregano','rice','pasta','lemon','lime','ginger','soy sauce','vinegar','honey','cheese','yogurt','spinach','mushroom'
  ];

  List<String> suggestions(String query, {int limit = 12}) {
    final q = query.trim().toLowerCase();

    // Tag mode (#)
    if (q.startsWith('#')) {
      final tagQ = q.substring(1);
      final existingTags = <String>{};
      for (final e in _entries) { existingTags.addAll(e.tags); }
      final pool = {...existingTags, ..._defaultTags};
      final filtered = tagQ.isEmpty ? pool.toList() : pool.where((t)=> t.startsWith(tagQ) || _levenshtein(t, tagQ) <= 1).toList();
      filtered.sort((a,b){
        final la = _levenshtein(a, tagQ); final lb = _levenshtein(b, tagQ);
        if (la!=lb) return la.compareTo(lb);
        return a.compareTo(b);
      });
      return filtered.take(limit).map((t)=> '#$t').toList();
    }

    // Build candidate set
    final candidates = <String>{
      ..._common,
      ..._extended,
      ..._entries.map((e)=>e.name),
      ..._synonyms.values,
      ..._recent,
    }..removeWhere((e)=> e.isEmpty);

    if (q.isEmpty) {
      final list = candidates.toList();
      list.sort((a,b){
        final ua = _usage[a]??0;
        final ub = _usage[b]??0;
        if (ua!=ub) return ub.compareTo(ua); // usage desc
        final ra = _recent.indexOf(a); final rb = _recent.indexOf(b);
        if (ra!=-1 || rb!=-1) {
          if (ra==-1) return 1; if (rb==-1) return -1; return ra.compareTo(rb); // recent earlier
        }
        return a.compareTo(b);
      });
      return list.take(limit).toList();
    }

    final tokens = q.split(RegExp(r'\s+')).where((t)=>t.isNotEmpty).toList();

    // Precompute token bigrams for slight fuzzy help
    List<String> bigrams(String s) {
      if (s.length < 2) return [s];
      final res = <String>[]; for (int i=0;i<s.length-1;i++){res.add(s.substring(i,i+2));} return res;
    }
    final queryBigrams = bigrams(q);

    double scoreFor(String candidate) {
      final candTokens = candidate.split(' ');
      int matchedTokens = 0;
      double score = 200.0; // higher -> worse; we'll subtract improvements
      for (final qt in tokens) {
        double bestTokenScore = 0.0; // higher is better (to subtract later)
        for (final ct in candTokens) {
          if (ct == qt) {
            if (bestTokenScore < 100.0) {
              bestTokenScore = 100.0; // exact word
            }
            continue;
          }
          if (ct.startsWith(qt)) {
            final closeness = 80.0 - (ct.length - qt.length)*1.5; // shorter remainder better
            if (closeness > bestTokenScore) bestTokenScore = closeness;
          } else if (ct.contains(qt)) {
            final idx = ct.indexOf(qt);
            final closeness = 60.0 - idx; // earlier idx better
            if (closeness > bestTokenScore) bestTokenScore = closeness;
          } else {
            final lev = _levenshtein(ct, qt);
            if (lev <= 2) {
              final closeness = 50.0 - lev*8; // small edit distance
              if (closeness > bestTokenScore) bestTokenScore = closeness;
            } else {
              final qb = bigrams(qt);
              final cb = bigrams(ct);
              final inter = qb.where((b)=> cb.contains(b)).length;
              final denom = (qb.length + cb.length)/2.0;
              if (inter > 0) {
                final sim = (inter/denom)*30.0; // up to 30
                if (sim > bestTokenScore) bestTokenScore = sim;
              }
            }
          }
        }
        if (bestTokenScore > 0) {
          matchedTokens++;
          score -= bestTokenScore; // better match lowers score
        } else {
          score += 10.0; // penalty for missing token
        }
      }
      if (matchedTokens == tokens.length) {
        score -= 15.0; // full coverage bonus
      } else if (matchedTokens > 0) {
        score -= matchedTokens * 3.0;
      }

      if (candidate.startsWith(q)) score -= 25.0; // Proximity bonus

      final cbAll = bigrams(candidate);
      final interAll = queryBigrams.where((b)=> cbAll.contains(b)).length;
      if (interAll > 0) {
        final simAll = (interAll / queryBigrams.length) * 10.0;
        score -= simAll;
      }

      final u = _usage[candidate] ?? 0;
      if (u > 0) score -= (8.0 + math.log(u.toDouble()+1)*4.0);
      final rIndex = _recent.indexOf(candidate);
      if (rIndex != -1) score -= (12.0 - rIndex); // earlier recent gets more boost

      score += candidate.length * 0.4; // slight length penalty
      return score;
    }

    final scored = <String,double>{};
    for (final c in candidates) {
      final s = scoreFor(c);
      if (s < 260.0) { // cutoff
        scored[c] = s;
      }
    }
    final ordered = scored.keys.toList()
      ..sort((a,b){
        final sa = scored[a]!; final sb = scored[b]!;
        if (sa != sb) return sa.compareTo(sb);
        final ua = _usage[a]??0; final ub = _usage[b]??0; 
        if (ua!=ub) return ub.compareTo(ua); // usage desc
        final ra = _recent.indexOf(a); final rb = _recent.indexOf(b);
        if (ra!=-1 || rb!=-1) {
          if (ra==-1) return 1; 
          if (rb==-1) return -1; 
          return ra.compareTo(rb);
        }
        return a.compareTo(b);
      });
    return ordered.take(limit).toList();
  }

  bool _isDuplicate(IngredientEntry entry) {
    return _entries.any((e) => e.name == entry.name || _levenshtein(e.name, entry.name) <= 1);
  }

  IngredientEntry _parseIngredient(String raw) {
    final original = raw.trim();
    if (original.isEmpty) {
      return IngredientEntry(original: raw, name: '');
    }
    String working = original;
    // Extract tags ( #tag )
    final tagRegex = RegExp(r'(?:^|\s)#([a-zA-Z0-9_-]+)');
    final tags = <String>[];
    working = working.replaceAllMapped(tagRegex, (m) { tags.add(m[1]!.toLowerCase()); return ''; });
    working = working.replaceAll(RegExp(r'\s+'), ' ').trim();

    double? qSingle;
    double? qMin;
    double? qMax;
    String? unit;

    // Quantity range like 1-2 or 1–2 (en dash) or 1 to 2
    final rangeRegex = RegExp(r'^([0-9]+(?:\.[0-9]+)?)[ \t]*(?:-|–|to)[ \t]*([0-9]+(?:\.[0-9]+)?)\b', caseSensitive: false);
    final singleRegex = RegExp(r'^([0-9]+(?:\.[0-9]+)?)(?:\b|\s)');
    var namePart = working;

    final rangeMatch = rangeRegex.firstMatch(working);
    if (rangeMatch != null) {
      qMin = double.tryParse(rangeMatch.group(1)!);
      qMax = double.tryParse(rangeMatch.group(2)!);
      namePart = working.substring(rangeMatch.end).trim();
    } else {
      final singleMatch = singleRegex.firstMatch(working);
      if (singleMatch != null) {
        qSingle = double.tryParse(singleMatch.group(1)!);
        namePart = working.substring(singleMatch.end).trim();
      }
    }

    // Optional unit as first word if alphabetical and short or common (cup, tbsp, tsp, g, kg, ml, l, oz, lb)
    final unitRegex = RegExp(r'^(cups?|tbsp|tablespoons?|tsp|teaspoons?|g|kg|ml|l|oz|lb|pounds?|grams?|kilograms?|liters?|litres?)\b', caseSensitive: false);
    final uMatch = unitRegex.firstMatch(namePart);
    if (uMatch != null) {
      unit = uMatch.group(0)!.toLowerCase();
      namePart = namePart.substring(uMatch.end).trim();
    }

    // Normalize unit synonyms
    if (unit != null) {
      switch (unit) {
        case 'tablespoon': case 'tablespoons': unit = 'tbsp'; break;
        case 'teaspoon': case 'teaspoons': unit = 'tsp'; break;
        case 'pounds': case 'pound': unit = 'lb'; break;
        case 'grams': unit = 'g'; break;
        case 'kilograms': unit = 'kg'; break;
        case 'liters': case 'litres': unit = 'l'; break;
      }
    }

    // Clean trailing punctuation
    namePart = namePart.replaceAll(RegExp(r'[.,;:]+$'), '').trim();
    // Lowercase for key, but keep original for original field
    final name = _normalizeName(namePart);

    if (qSingle != null && qMin == null && qMax == null) {
      qMin = qSingle;
      qMax = qSingle;
    }

    return IngredientEntry(
      original: original,
      name: name,
      quantity: qSingle,
      quantityMin: qMin,
      quantityMax: qMax,
      unit: unit,
      tags: tags,
    );
  }

  String _normalizeName(String s) {
    var out = s.toLowerCase();
    out = out.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Improved plural handling
    String singularize(String w) {
      if (w.length <= 3) return w; // too short
      if (_synonyms.containsKey(w)) return w; // mapped explicitly
      if (w.endsWith('ies') && w.length > 4) {
        // berries -> berry
        return '${w.substring(0, w.length - 3)}y';
      }
      if (w.endsWith('oes')) { // tomatoes -> tomato (also potatoes)
        return w.substring(0, w.length - 2);
      }
      const esEndings = ['ches','shes','sses','xes','zes'];
      for (final e in esEndings) {
        if (w.endsWith(e)) {
          return w.substring(0, w.length - 2); // drop 'es'
        }
      }
      // Avoid stripping 'es' from words like 'pickles' (would become 'pickl'). Only remove trailing 's'
      // if preceding char is not 's' and not 'l'. This is a heuristic.
      if (w.endsWith('s') && !w.endsWith('ss')) {
        final prev = w[w.length - 2];
        if (prev != 'l') { // keep words ending with 'ls' (pickles, noodles) intact
          return w.substring(0, w.length - 1);
        }
      }
      return w;
    }

    out = singularize(out);
    // Synonym mapping after singularization
    out = _synonyms[out] ?? out;
    return out;
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final m = a.length;
    final n = b.length;
    List<int> prev = List<int>.generate(n + 1, (i) => i);
    List<int> curr = List<int>.filled(n + 1, 0);
    for (int i = 1; i <= m; i++) {
      curr[0] = i;
      final ca = a.codeUnitAt(i - 1);
      for (int j = 1; j <= n; j++) {
        final cb = b.codeUnitAt(j - 1);
        final cost = (ca == cb) ? 0 : 1;
        curr[j] = [
          prev[j] + 1, // deletion
          curr[j - 1] + 1, // insertion
          prev[j - 1] + cost // substitution
        ].reduce((v, e) => v < e ? v : e);
      }
      final tmp = prev; prev = curr; curr = tmp;
    }
    return prev[n];
  }
}
// end of file
