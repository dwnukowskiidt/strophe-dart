import 'package:strophe/src/core/core.dart';
import 'package:xml/xml.dart' as xml;

///  PrivateClass: Strophe.Handler
///  _Private_ helper class for managing stanza handlers.
///
///  A Strophe.Handler encapsulates a user provided callback function to be
///  executed when matching stanzas are received by the connection.
///  Handlers can be either one-off or persistant depending on their
///  return value. Returning true will cause a Handler to remain active, and
///  returning false will remove the Handler.
///
///  Users will not use Strophe.Handler objects directly, but instead they
///  will use Strophe.Connection.addHandler() and
///  Strophe.Connection.deleteHandler().
///

/// PrivateConstructor: Strophe.Handler
///  Create and initialize a new Strophe.Handler.
///
///  Parameters:
///    (Function) handler - A function to be executed when the handler is run.
///    (String) ns - The namespace to match.
///    (String) name - The element name to match.
///    (String) type - The element type to match.
///    (String) id - The element id attribute to match.
///    (String) from - The element from attribute to match.
///    (Object) options - Handler options
///
///  Returns:
///    A new Strophe.Handler object.
///
class StropheHandler {
  String from;

  // whether the handler is a user handler or a system handler
  bool user;
  Function handler;
  String ns;
  String name;
  List<String> type; // String or List
  String id;
  Map options;

  StropheHandler(
      this.handler, this.ns, this.name, ptype, this.id, this.options) {
    this.type = ptype is List ? ptype : [ptype];
  }

  factory StropheHandler.handler(Function handler,
      [String ns, String name, type, String id, String from, Map options]) {
    if (options != null) {
      options.putIfAbsent('matchBareFromJid', () => false);
      options.putIfAbsent('ignoreNamespaceFragment', () => false);
    } else {
      options = {'matchBareFromJid': false, 'ignoreNamespaceFragment': false};
    }
    StropheHandler stropheHandler =
        StropheHandler(handler, ns, name, type, id, options);
    // BBB: Maintain backward compatibility with old `matchBare` option
    if (stropheHandler.options['matchBare'] != null) {
      Strophe.warn(
          'The "matchBare" option is deprecated, use "matchBareFromJid" instead.');
      stropheHandler.options['matchBareFromJid'] =
          stropheHandler.options['matchBare'];
      stropheHandler.options.remove('matchBare');
    }

    if (stropheHandler.options['matchBareFromJid'] != null &&
        stropheHandler.options['matchBareFromJid'] == true) {
      stropheHandler.from = (from != null && from.isNotEmpty)
          ? Strophe.getBareJidFromJid(from)
          : null;
    } else {
      stropheHandler.from = from;
    }
    // whether the handler is a user handler or a system handler
    stropheHandler.user = true;
    return stropheHandler;
  }

  /// PrivateFunction: getNamespace
  /// Returns the XML namespace attribute on an element.
  /// If `ignoreNamespaceFragment` was passed in for this handler, then the
  /// URL fragment will be stripped.
  ///
  /// Parameters:
  /// (XMLElement) elem - The XML element with the namespace.
  ///
  /// Returns:
  /// The namespace, with optionally the fragment stripped.
  ///
  String getNamespace(xml.XmlNode node) {
    xml.XmlElement elem =
        node is xml.XmlDocument ? node.rootElement : node as xml.XmlElement;
    String elNamespace = elem.getAttribute("xmlns") ?? '';
    if (elNamespace != null &&
        elNamespace.isNotEmpty &&
        this.options['ignoreNamespaceFragment']) {
      elNamespace = elNamespace.split('#')[0];
    }
    return elNamespace;
  }

  /// PrivateFunction: namespaceMatch
  /// Tests if a stanza matches the namespace set for this Strophe.Handler.
  ///
  /// Parameters:
  /// (XMLElement) elem - The XML element to test.
  ///
  /// Returns:
  /// true if the stanza matches and false otherwise.
  ///
  bool namespaceMatch(xml.XmlNode elem) {
    bool nsMatch = false;
    if (this.ns == null || this.ns.isEmpty) {
      return true;
    } else {
      Strophe.forEachChild(elem, null, (child) {
        if (this.getNamespace(child) == this.ns) {
          nsMatch = true;
        }
      });
      nsMatch = nsMatch || this.getNamespace(elem) == this.ns;
    }
    return nsMatch;
  }

  /// PrivateFunction: isMatch
  /// Tests if a stanza matches the Strophe.Handler.
  ///
  /// Parameters:
  /// (XMLElement) elem - The XML element to test.
  ///
  /// Returns:
  /// true if the stanza matches and false otherwise.
  ///
  bool isMatch(xml.XmlNode node) {
    xml.XmlElement elem =
        node is xml.XmlDocument ? node.rootElement : node as xml.XmlElement;
    String from = elem.getAttribute("from");
    if (this.options['matchBareFromJid']) {
      from = Strophe.getBareJidFromJid(from);
    }

    String id = elem.getAttribute("id");

    // TODO: this code below in not from the JS lib
    bool withId = false;
    if (this.options['endsWithId'] == true) {
      withId = (id ?? '').endsWith(this.id);
    }
    if (this.options['startsWithId'] == true) {
      withId = (id ?? '').startsWith(this.id);
    }
    // TODO: ends here

    String elemType = elem.getAttribute("type");
    bool statement = this.type.indexOf(elemType) != -1;
    if (this.namespaceMatch(elem) &&
        (this.name == null || Strophe.isTagEqual(elem, this.name)) &&
        (this.type == null || this.type.contains(null) || statement) &&
        (this.id == null || id == this.id || withId) &&
        (this.from == null || from == this.from)) {
      return true;
    }
    return false;
  }

  /// PrivateFunction: run
  ///  Run the callback on a matching stanza.
  ///
  ///  Parameters:
  ///    (XMLElement) elem - The DOM element this triggered the
  ///      Strophe.Handler.
  ///
  ///  Returns:
  ///    A boolean indicating if the handler should remain active.
  ///
  bool run(xml.XmlNode elem) {
    bool result = false;
    if (this.handler == null) {
      return false;
    }
    try {
      var handResult = this.handler(elem);
      if (handResult == null || handResult == true) {
        result = true;
      }
    } catch (e) {
      Strophe.handleError(e);
      throw e;
    }
    return result;
  }

  /// PrivateFunction: toString
  /// Get a String representation of the Strophe.Handler object.
  ///
  /// Returns:
  ///   A String.
  ///
  String toString() {
    return "{Handler: " +
        this.handler.toString() +
        "(" +
        this.name +
        "," +
        this.id +
        "," +
        this.ns +
        ")}";
  }
}
