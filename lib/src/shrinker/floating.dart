import 'dart:math' as math;
import '../shrinkable.dart';
import '../stream.dart';
import 'integer.dart';

/// Decomposes a floating point number into a fraction and exponent (base 2).
/// Similar to C++ frexp. Returns the fraction in [0.5, 1.0) or (-1.0, -0.5] and the exponent.
/// The value is reconstructed as: value = fraction * 2^exponent
({double fraction, int exponent}) _decomposeFloat(double value) {
  if (value == 0.0 || !value.isFinite) {
    return (fraction: value, exponent: 0);
  }

  // Extract the sign
  final sign = value < 0 ? -1.0 : 1.0;
  final absValue = value.abs();

  // Use log2 to get the exponent
  final log2 = math.log(absValue) / math.ln2;
  final exponent = log2.floor() + 1;
  final fraction = absValue * math.pow(2.0, -exponent) * sign;

  // Normalize fraction to be in [0.5, 1.0) or (-1.0, -0.5]
  // Recompute to ensure exact decomposition
  final recomputed = fraction * math.pow(2.0, exponent);
  if ((recomputed - value).abs() > 1e-10) {
    // Fallback: recompute exactly
    final exactExp = (math.log(absValue) / math.ln2).floor() + 1;
    final exactFrac = absValue * math.pow(2.0, -exactExp) * sign;
    return (fraction: exactFrac, exponent: exactExp);
  }

  return (fraction: fraction, exponent: exponent);
}

/// Composes a floating point number from fraction and exponent (base 2).
/// Similar to C++ ldexp. Returns fraction * 2^exponent.
double _composeFloat(double fraction, int exponent) {
  return fraction * math.pow(2.0, exponent);
}

/// Creates a stream of shrinkable floating point values.
LazyStream<Shrinkable<double>> _shrinkableFloatStream(double value) {
  if (value == 0.0) {
    return LazyStream<Shrinkable<double>>(null);
  } else if (value.isNaN) {
    return LazyStream<Shrinkable<double>>(Shrinkable<double>(0.0));
  } else {
    double fraction = 0.0;
    int exponent = 0;

    if (value == double.infinity) {
      final max = double.maxFinite;
      final decomposed = _decomposeFloat(max);
      fraction = decomposed.fraction;
      exponent = decomposed.exponent;
    } else if (value == double.negativeInfinity) {
      final min = -double.maxFinite;
      final decomposed = _decomposeFloat(min);
      fraction = decomposed.fraction;
      exponent = decomposed.exponent;
    } else {
      final decomposed = _decomposeFloat(value);
      fraction = decomposed.fraction;
      exponent = decomposed.exponent;
    }

    // Shrink exponent using binary search
    final expShrinkable = binarySearchShrinkable(exponent);
    Shrinkable<double> doubleShrinkable =
        expShrinkable.map((exp) => _composeFloat(fraction, exp));

    // Prepend 0.0
    // Note: capture shrinks() before reassigning to match jsproptest behavior
    final shrinksStream = doubleShrinkable.shrinks();
    doubleShrinkable = doubleShrinkable.withShrinks(() {
      final zero = LazyStream<Shrinkable<double>>(Shrinkable<double>(0.0));
      return zero.concat(shrinksStream);
    });

    // Shrink fraction within (0.0 and 0.5)
    doubleShrinkable = doubleShrinkable.andThen((shr) {
      final value = shr.value;
      if (value == 0.0) {
        return LazyStream<Shrinkable<double>>(null);
      }
      final decomposed = _decomposeFloat(value);
      final exp = decomposed.exponent;
      if (value > 0) {
        return LazyStream<Shrinkable<double>>(
            Shrinkable<double>(_composeFloat(0.5, exp)));
      } else {
        return LazyStream<Shrinkable<double>>(
            Shrinkable<double>(_composeFloat(-0.5, exp)));
      }
    });

    // Integer-ify: try to shrink to nearest integer
    doubleShrinkable = doubleShrinkable.andThen((shr) {
      final value = shr.value;
      final intValue = value > 0 ? value.floor() : value.ceil();
      if (intValue != 0 && intValue.abs() < value.abs()) {
        return LazyStream<Shrinkable<double>>(
            Shrinkable<double>(intValue.toDouble()));
      } else {
        return LazyStream<Shrinkable<double>>(null);
      }
    });

    return doubleShrinkable.shrinks();
  }
}

/// Creates a Shrinkable for floating point numbers.
Shrinkable<double> shrinkableFloat(double value) {
  return Shrinkable<double>(value)
      .withShrinks(() => _shrinkableFloatStream(value));
}
