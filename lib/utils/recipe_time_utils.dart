int? deriveReadyInMinutes(Map<String, dynamic> details) {
  final ready = details['readyInMinutes'];
  final prep = details['preparationMinutes'];
  final cook = details['cookingMinutes'];
  final additional = details['additionalMinutes'];

  int sumParts = 0;
  if (prep is int && prep > 0) {
    sumParts += prep;
  }
  if (cook is int && cook > 0) {
    sumParts += cook;
  }
  if (additional is int && additional > 0) {
    sumParts += additional;
  }

  int stepsTotal = 0;
  final analyzed = details['analyzedInstructions'];
  if (analyzed is List && analyzed.isNotEmpty) {
    for (final instr in analyzed) {
      final steps = instr is Map ? instr['steps'] : null;
      if (steps is List) {
        for (final step in steps) {
          if (step is Map) {
            final length = step['length'];
            if (length is Map) {
              final num = length['number'];
              final unit = (length['unit'] ?? '').toString().toLowerCase();
              if (num is int && num > 0) {
                if (unit.contains('min')) {
                  stepsTotal += num;
                } else if (unit.contains('hour')) {
                  stepsTotal += num * 60;
                }
              }
            }
          }
        }
      }
    }
  }

  int derived = 0;
  if (sumParts > 0) {
    derived = sumParts;
  }
  if (stepsTotal > 0) {
    if (derived == 0) {
      derived = stepsTotal;
    } else if ((stepsTotal - derived).abs() / derived > 0.2) {
      if (derived == 45 && stepsTotal != 45) {
        derived = stepsTotal;
      } else if (stepsTotal < derived && stepsTotal >= (derived * 0.5)) {
        derived = stepsTotal;
      }
    }
  }

  if (derived == 0 && ready is int && ready > 0) {
    derived = ready;
  }
  if (ready == 45 && derived != 45 && derived > 0) {
    return derived;
  }

  return derived > 0 ? derived : null;
}
