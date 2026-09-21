import 'dart:math' as math;

/// Analog-meter mapping of a usage fraction onto a dB-like scale.
///
/// Full scale (`1.0`) is 0 dB. Readings collapse onto a −30 dB floor so the
/// needle has somewhere to rest at idle, matching a classic VU face.
abstract final class AnalogLevel {
  static const double floorDb = -30;
  static const double ceilingDb = 0;
  static const List<double> ticks = <double>[-30, -20, -10, -5, 0];

  /// Decibels relative to full scale for an occupancy ratio.
  static double dbFor(double ratio) {
    if (!ratio.isFinite || ratio <= 0) {
      return floorDb;
    }
    final double db = 20 * math.log(ratio.clamp(0, 1)) / math.ln10;
    return db.clamp(floorDb, ceilingDb);
  }

  /// Arc travel from the floor to the ceiling, as a `0..=1` fraction.
  static double sweep(double ratio) {
    return (dbFor(ratio) - floorDb) / (ceilingDb - floorDb);
  }
}

/// Inertial glide of the analog needle toward a new occupancy.
///
/// Position stays continuous when the target changes mid-flight, so a
/// one-second sample cadence reads as a sweep instead of a step.
abstract final class NeedleMotion {
  /// Natural frequency, in radians per second. Lower settles more slowly.
  static const double omega = 4.2;

  static ({double position, double velocity}) step({
    required double position,
    required double velocity,
    required double target,
    required double dt,
  }) {
    if (!dt.isFinite || dt <= 0) {
      return (position: position, velocity: velocity);
    }

    final double stiffness = omega * omega;
    final double damping = 2 * omega;
    final double acceleration =
        stiffness * (target - position) - damping * velocity;
    final double nextVelocity = velocity + acceleration * dt;
    return (position: position + nextVelocity * dt, velocity: nextVelocity);
  }
}
