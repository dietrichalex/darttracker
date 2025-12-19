class CheckoutLogic {
  static const Map<int, String> _table = {
    170: "T20, T20, Bull", 167: "T20, T19, Bull", 164: "T20, T18, Bull",
    161: "T20, T17, Bull", 160: "T20, T20, D20", 158: "T20, T20, D19",
    141: "T20, T19, D12", 121: "T20, T11, D14", 101: "T20, S1, D20",
    100: "T20, D20", 90: "T18, D18", 80: "T20, D10", 70: "T10, D20",
    60: "S20, D20", 50: "Bull", 40: "D20", 32: "D16", 16: "D8", 8: "D4", 4: "D2", 2: "D1"
    // Note: You can expand this table to include every single number 2-158.
  };

  static String getRoute(int score) {
    if (score > 170 || score == 169 || score == 168 || score == 166 || score == 165 || score == 163 || score == 162 || score == 159) {
      return "No Checkout";
    }
    return _table[score] ?? "Finish Available";
  }
}