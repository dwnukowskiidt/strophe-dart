/// PrivateClass: Strophe.TimedHandler
/// _Private_ helper class for managing timed handlers.
///
/// A Strophe.TimedHandler encapsulates a user provided callback that
/// should be called after a certain period of time or at regular
/// intervals.  The return value of the callback determines whether the
/// Strophe.TimedHandler will continue to fire.
///
/// Users will not use Strophe.TimedHandler objects directly, but instead
/// they will use Strophe.Connection.addTimedHandler() and
/// Strophe.Connection.deleteTimedHandler().
///

/// PrivateConstructor: Strophe.TimedHandler
/// Create and initialize a new Strophe.TimedHandler object.
///
/// Parameters:
///   (Integer) period - The number of milliseconds to wait before the
///     handler is called.
///   (Function) handler - The callback to run when the handler fires.  This
///     function should take no arguments.
///
/// Returns:
///   A new Strophe.TimedHandler object.
///
class StropheTimedHandler {
  int period;
  Function handler;
  int lastCalled;
  bool user = true;

  StropheTimedHandler(int period, Function handler) {
    this.period = period;
    this.handler = handler;
    this.lastCalled = DateTime.now().millisecondsSinceEpoch;
  }

  /// PrivateFunction: run
  ///  Run the callback for the Strophe.TimedHandler.
  ///
  ///  Returns:
  ///    true if the Strophe.TimedHandler should be called again, and false
  ///      otherwise.
  ///
  bool run() {
    this.lastCalled = DateTime.now().millisecondsSinceEpoch;
    return this.handler();
  }

  /// PrivateFunction: reset
  ///  Reset the last called time for the Strophe.TimedHandler.
  ///
  void reset() {
    this.lastCalled = DateTime.now().millisecondsSinceEpoch;
  }

  /// PrivateFunction: toString
  ///  Get a string representation of the Strophe.TimedHandler object.
  ///
  ///  Returns:
  ///    The string representation.
  ///
  String toString() {
    return "{TimedHandler: " +
        this.handler.toString() +
        "(" +
        this.period.toString() +
        ")}";
  }
}
