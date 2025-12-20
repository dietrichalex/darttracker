class CheckoutLogic {
  
  /// Returns a checkout string or empty if impossible with [dartsLeft]
  static String getRecommendation(int score, int dartsLeft) {
    if (score > 170) return "";
    if (score <= 1) return ""; // Cannot finish on 1 or 0 (already handled)

    // 1. One Dart Finishes
    if (dartsLeft >= 1) {
      String? oneDart = _tryOneDart(score);
      if (oneDart != null) return oneDart;
    }

    // 2. Two Dart Finishes
    if (dartsLeft >= 2) {
      String? twoDart = _tryTwoDarts(score);
      if (twoDart != null) return twoDart;
    }

    // 3. Three Dart Finishes
    if (dartsLeft == 3) {
      // Check our preferred pro list first for style points (e.g. 170)
      if (_preferredThreeDart.containsKey(score)) {
        return _preferredThreeDart[score]!;
      }
      // Otherwise calculate a generic route
      return _calculateThreeDarts(score);
    }

    return "";
  }

  // --- HELPERS ---

  static String? _tryOneDart(int score) {
    if (score == 50) return "Bull";
    if (score <= 40 && score % 2 == 0) return "D${score ~/ 2}";
    return null;
  }

  static String? _tryTwoDarts(int score) {
    // We prioritize High Triples to leave a clean double
    // Iterate Setup Darts: T20 down to T1, then Bull, then S20 down to S1
    
    // List of sensible setup darts to try
    final List<int> setups = [
      60, 57, 54, 51, 48, 45, 42, 39, 36, 33, 30, 27, 24, 21, 18, 15, 12, 9, 6, 3, // Triples
      50, 25, // Bull
      20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1 // Singles
    ];

    for (int setup in setups) {
      int remainder = score - setup;
      if (remainder <= 1) continue; // Bust or 1 left
      
      String? finish = _tryOneDart(remainder);
      if (finish != null) {
        return "${_label(setup)}, $finish";
      }
    }
    return null;
  }

  static String _calculateThreeDarts(int score) {
    // Strategy: Throw a T20 (or T19/T18), then check if finishable in 2
    // Setup Darts we prefer for 1st dart
    final List<int> firstDarts = [60, 57, 54, 51, 50, 25, 20, 19]; 
    
    for (int first in firstDarts) {
      int remainder = score - first;
      if (remainder <= 1) continue;

      String? finishTwo = _tryTwoDarts(remainder);
      if (finishTwo != null) {
        return "${_label(first)}, $finishTwo";
      }
    }
    
    // Fallback: If score is small (e.g. 35 with 3 darts), standard logic implies S3, D16
    if (score <= 40 && score % 2 != 0) {
      return "S1, D${(score - 1) ~/ 2}";
    }

    return "";
  }

  static String _label(int val) {
    if (val == 50) return "Bull";
    if (val == 25) return "25";
    if (val > 20 && val % 3 == 0) return "T${val ~/ 3}";
    // Note: This simple labeler assumes standard inputs from our list. 
    // Ideally we track multiplier source, but for setups, high vals are T.
    return "S$val"; 
  }

  // Only keep the "Iconic" finishes that algorithm might miss or do weirdly
  static const Map<int, String> _preferredThreeDart = {
    170: "T20, T20, Bull",
    167: "T20, T19, Bull",
    164: "T20, T18, Bull",
    161: "T20, T17, Bull",
    132: "Bull, Bull, D16", // Flashy
    121: "T20, T11, D14",   // Standard pro route
  };
}