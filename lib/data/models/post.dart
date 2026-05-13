enum NobTier {
  observer,
  explorer,
  noble;

  String get label {
    switch (this) {
      case NobTier.observer: return 'Observer';
      case NobTier.explorer: return 'Explorer';
      case NobTier.noble: return 'Noble';
    }
  }

  static NobTier fromString(String? s) {
    switch (s) {
      case 'explorer': return NobTier.explorer;
      case 'noble': return NobTier.noble;
      default: return NobTier.observer;
    }
  }
}
