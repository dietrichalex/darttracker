class CheckoutLogic {
  // Professional routes for high finishes
  static const Map<int, String> _checkouts = {
    170: "T20, T20, Bull", 167: "T20, T19, Bull", 164: "T20, T18, Bull", 161: "T20, T17, Bull",
    160: "T20, T20, D20", 158: "T20, T20, D19", 157: "T20, T19, D20", 156: "T20, T20, D18",
    155: "T20, T19, D19", 154: "T20, T18, D20", 153: "T20, T19, D18", 152: "T20, T20, D16",
    151: "T20, T17, D20", 150: "T20, T18, D18", 149: "T20, T19, D16", 148: "T20, T16, D20",
    147: "T20, T17, D18", 146: "T20, T18, D16", 145: "T20, T15, D20", 144: "T20, T20, D12",
    143: "T20, T17, D16", 142: "T20, T14, D20", 141: "T20, T19, D12", 140: "T20, T16, D16",
    139: "T19, T14, D20", 138: "T20, T18, D12", 137: "T19, T16, D16", 136: "T20, T20, D8",
    135: "T20, T15, D15", 134: "T20, T14, D16", 133: "T20, T19, D8", 132: "T20, T16, D12",
    131: "T20, T13, D16", 130: "T20, T20, D5", 129: "T19, T16, D12", 128: "T18, T14, D16",
    127: "T20, T17, D8", 126: "T19, T19, D6", 125: "Bull, T17, D12", 124: "T20, T16, D8",
    123: "T19, T16, D9", 122: "T18, T20, D4", 121: "T20, T11, D14", 120: "T20, S20, D20",
    119: "T19, T10, D16", 118: "T20, S18, D20", 117: "T20, S17, D20", 116: "T20, S16, D20",
    115: "T20, S15, D20", 114: "T20, S14, D20", 113: "T20, S13, D20", 112: "T20, S12, D20",
    111: "T20, S11, D20", 110: "T20, S10, D20", 109: "T20, S9, D20", 108: "T20, S16, D16",
    107: "T19, S18, D16", 106: "T20, S10, D18", 105: "T20, S13, D16", 104: "T18, S18, D16",
    103: "T20, S3, D20", 102: "T20, S10, D16", 101: "T17, Bull", 100: "T20, D20",
    // Common 2-dart finishes
    90: "T18, D18", 80: "T20, D10", 70: "T18, D8", 60: "S20, D20", 50: "S10, D20", 40: "D20"
  };

  static String getRoute(int score) {
    if (score > 170) return "";
    
    // Bogey numbers (Impossible in 3 darts)
    if ([169, 168, 166, 165, 163, 162, 159].contains(score)) {
      return "No Checkout";
    }

    if (_checkouts.containsKey(score)) {
      return _checkouts[score]!;
    }

    // Dynamic Fallback Calculation
    if (score <= 40 && score % 2 == 0) {
      return "D${score ~/ 2}";
    } 
    if (score <= 40 && score % 2 != 0) {
      return "S1, D${(score - 1) ~/ 2}"; // E.g., 3 left -> S1, D1
    }
    
    return "Finish Available";
  }
}