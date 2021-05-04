import 'package:strophe/src/core/Strophe.Builder.dart';
import 'package:strophe/src/core/Strophe.SASLMechanism.dart';
import 'package:strophe/src/plugins/plugins.dart';
import 'package:xml/xml.dart' as xml;

/// Class: Strophe
/// An object container for all Strophe library functions.
///
/// This class is just a container for all the objects and constants
/// used in the library.  It is not meant to be instantiated, but to
/// provide a namespace for library objects, constants, and functions.
///
class Strophe {
  static const String VERSION = '0.0.1';

  /// Function: $build
  /// Create a Strophe.Builder.
  /// This is an alias for 'new Strophe.Builder(name, attrs)'.
  ///
  /// Parameters:
  ///   (String) name - The root element name.
  ///   (Object) attrs - The attributes for the root element in object notation.
  ///
  /// Returns:
  ///   A new Strophe.Builder object.
  ///
  static StropheBuilder $build(String name, Map<String, dynamic> attrs) {
    return StropheBuilder(name, attrs);
  }

  /// Function: $msg
  /// Create a Strophe.Builder with a <message/> element as the root.
  ///
  /// Parameters:
  ///   (Object) attrs - The <message/> element attributes in object notation.
  ///
  /// Returns:
  ///   A new Strophe.Builder object.
  ///
  static StropheBuilder $msg([Map<String, dynamic> attrs]) {
    return StropheBuilder("message", attrs);
  }

  /// Function: $iq
  /// Create a Strophe.Builder with an <iq/> element as the root.
  ///
  /// Parameters:
  ///   (Object) attrs - The <iq/> element attributes in object notation.
  ///
  /// Returns:
  ///   A new Strophe.Builder object.
  ///
  static StropheBuilder $iq([Map<String, dynamic> attrs]) {
    return StropheBuilder("iq", attrs);
  }

  /// Function: $pres
  /// Create a Strophe.Builder with a <presence/> element as the root.
  ///
  /// Parameters:
  ///   (Object) attrs - The <presence/> element attributes in object notation.
  ///
  /// Returns:
  ///   A new Strophe.Builder object.
  ///
  static StropheBuilder $pres([Map<String, dynamic> attrs]) {
    return StropheBuilder("presence", attrs);
  }

  /// Constants: XMPP Namespace Constants
  /// Common namespace constants from the XMPP RFCs and XEPs.
  ///
  /// NS.HTTPBIND - HTTP BIND namespace from XEP 124.
  /// NS.BOSH - BOSH namespace from XEP 206.
  /// NS.CLIENT - Main XMPP client namespace.
  /// NS.AUTH - Legacy authentication namespace.
  /// NS.ROSTER - Roster operations namespace.
  /// NS.PROFILE - Profile namespace.
  /// NS.DISCO_INFO - Service discovery info namespace from XEP 30.
  /// NS.DISCO_ITEMS - Service discovery items namespace from XEP 30.
  /// NS.MUC - Multi-User Chat namespace from XEP 45.
  /// NS.SASL - XMPP SASL namespace from RFC 3920.
  /// NS.STREAM - XMPP Streams namespace from RFC 3920.
  /// NS.BIND - XMPP Binding namespace from RFC 3920.
  /// NS.SESSION - XMPP Session namespace from RFC 3920.
  /// NS.XHTML_IM - XHTML-IM namespace from XEP 71.
  /// NS.XHTML - XHTML body namespace from XEP 71.
  /// TODO: use enums
  static final Map<String, String> NS = {
    'HTTPBIND': "http://jabber.org/protocol/httpbind",
    'BOSH': "urn:xmpp:xbosh",
    'CLIENT': "jabber:client",
    'AUTH': "jabber:iq:auth",
    'ROSTER': "jabber:iq:roster",
    'PROFILE': "jabber:iq:profile",
    'DISCO_INFO': "http://jabber.org/protocol/disco#info",
    'DISCO_ITEMS': "http://jabber.org/protocol/disco#items",
    'MUC': "http://jabber.org/protocol/muc",
    'SASL': "urn:ietf:params:xml:ns:xmpp-sasl",
    'STREAM': "http://etherx.jabber.org/streams",
    'FRAMING': "urn:ietf:params:xml:ns:xmpp-framing",
    'BIND': "urn:ietf:params:xml:ns:xmpp-bind",
    'SESSION': "urn:ietf:params:xml:ns:xmpp-session",
    'VERSION': "jabber:iq:version",
    'STANZAS': "urn:ietf:params:xml:ns:xmpp-stanzas",
    'XHTML_IM': "http://jabber.org/protocol/xhtml-im",
    'XHTML': "http://www.w3.org/1999/xhtml",
  };

  /// Constants: XHTML_IM Namespace
  /// contains allowed tags, tag attributes, and css properties.
  /// Used in the createHtml function to filter incoming html into the allowed XHTML-IM subset.
  /// See http://xmpp.org/extensions/xep-0071.html#profile-summary for the list of recommended
  /// allowed tags and their attributes.
  /// TODO: convert into a class
  static Map<String, dynamic> XHTML = {
    "tags": [
      'a',
      'blockquote',
      'br',
      'cite',
      'em',
      'img',
      'li',
      'ol',
      'p',
      'span',
      'strong',
      'ul',
      'body'
    ],
    'attributes': {
      'a': ['href'],
      'blockquote': ['style'],
      'br': [],
      'cite': ['style'],
      'em': [],
      'img': ['src', 'alt', 'style', 'height', 'width'],
      'li': ['style'],
      'ol': ['style'],
      'p': ['style'],
      'span': ['style'],
      'strong': [],
      'ul': ['style'],
      'body': []
    },
    'css': [
      'background-color',
      'color',
      'font-family',
      'font-size',
      'font-style',
      'font-weight',
      'margin-left',
      'margin-right',
      'text-align',
      'text-decoration'
    ],
    /** Function: XHTML.validTag
     *
     * Utility method to determine whether a tag is allowed
     * in the XHTML_IM namespace.
     *
     * XHTML tag names are case sensitive and must be lower case.
     */
    'validTag': (String tag) {
      for (int i = 0; i < Strophe.XHTML['tags'].length; i++) {
        if (tag == Strophe.XHTML['tags'][i]) {
          return true;
        }
      }
      return false;
    },
    /** Function: XHTML.validAttribute
     *
     * Utility method to determine whether an attribute is allowed
     * as recommended per XEP-0071
     *
     * XHTML attribute names are case sensitive and must be lower case.
     */
    'validAttribute': (String tag, String attribute) {
      if (Strophe.XHTML['attributes'][tag] != null &&
          Strophe.XHTML['attributes'][tag].length > 0) {
        for (int i = 0; i < Strophe.XHTML['attributes'][tag].length; i++) {
          if (attribute == Strophe.XHTML['attributes'][tag][i]) {
            return true;
          }
        }
      }
      return false;
    },
    'validCSS': (style) {
      for (int i = 0; i < Strophe.XHTML['css'].length; i++) {
        if (style == Strophe.XHTML['css'][i]) {
          return true;
        }
      }
      return false;
    }
  };

  /// Constants: Connection Status Constants
  /// Connection status constants for use by the connection handler
  /// callback.
  ///
  /// Status.ERROR - An error has occurred
  /// Status.CONNECTING - The connection is currently being made
  /// Status.CONNFAIL - The connection attempt failed
  /// Status.AUTHENTICATING - The connection is authenticating
  /// Status.AUTHFAIL - The authentication attempt failed
  /// Status.CONNECTED - The connection has succeeded
  /// Status.DISCONNECTED - The connection has been terminated
  /// Status.DISCONNECTING - The connection is currently being terminated
  /// Status.ATTACHED - The connection has been attached
  /// Status.REDIRECT - The connection has been redirected
  /// Status.CONNTIMEOUT - The connection has timed out
  /// TODO: use enums
  static const Map<String, int> Status = {
    'ERROR': 0,
    'CONNECTING': 1,
    'CONNFAIL': 2,
    "AUTHENTICATING": 3,
    "AUTHFAIL": 4,
    "CONNECTED": 5,
    "DISCONNECTED": 6,
    "DISCONNECTING": 7,
    "ATTACHED": 8,
    "REDIRECT": 9,
    "CONNTIMEOUT": 10
  };

  /// Constants: Log Level Constants
  /// Logging level indicators.
  ///
  /// LogLevel.DEBUG - Debug output
  /// LogLevel.INFO - Informational output
  /// LogLevel.WARN - Warnings
  /// LogLevel.ERROR - Errors
  /// LogLevel.FATAL - Fatal errors
  ///
  static const Map<String, int> LogLevel = const {
    'DEBUG': 0,
    'INFO': 1,
    'WARN': 2,
    'ERROR': 3,
    'FATAL': 4
  };

  /// PrivateConstants: DOM Element Type Constants
  /// DOM element types.
  ///
  /// ElementType.NORMAL - Normal element.
  /// ElementType.TEXT - Text data element.
  /// ElementType.FRAGMENT - XHTML fragment element.
  ///
  // probably replaced by xml.XmlNodeType
  static const Map<String, int> ElementType = const {
    'NORMAL': 1,
    'TEXT': 3,
    'CDATA': 4,
    'FRAGMENT': 11
  };

  /// PrivateConstants: Timeout Values
  /// Timeout values for error states.  These values are in seconds.
  /// These should not be changed unless you know exactly what you are
  /// doing.
  ///
  /// TIMEOUT - Timeout multiplier. A waiting request will be considered
  /// failed after Math.floor(TIMEOUT * wait) seconds have elapsed.
  /// This defaults to 1.1, and with default wait, 66 seconds.
  /// SECONDARY_TIMEOUT - Secondary timeout multiplier. In cases where
  /// Strophe can detect early failure, it will consider the request
  /// failed if it doesn't return after
  /// Math.floor(SECONDARY_TIMEOUT * wait) seconds have elapsed.
  /// This defaults to 0.1, and with default wait, 6 seconds.
  static const num TIMEOUT = 1.1;
  static const num SECONDARY_TIMEOUT = 0.1;

  /// Function: addNamespace
  ///  This function is used to extend the current namespaces in
  ///  Strophe.NS.  It takes a key and a value with the key being the
  ///  name of the new namespace, with its actual value.
  ///  For example:
  ///  Strophe.addNamespace('PUBSUB', "http://jabber.org/protocol/pubsub");
  ///
  ///  Parameters:
  ///    (String) name - The name under which the namespace will be
  ///      referenced under Strophe.NS
  ///    (String) value - The actual namespace.
  static void addNamespace(String name, String value) {
    Strophe.NS[name] = value;
  }

  /// Function: forEachChild
  ///  Map a function over some or all child elements of a given element.
  ///
  ///  This is a small convenience function for mapping a function over
  ///  some or all of the children of an element.  If elemName is null, all
  ///  children will be passed to the function, otherwise only children
  ///  whose tag names match elemName will be passed.
  ///
  ///  Parameters:
  ///    (XMLElement) elem - The element to operate on.
  ///    (String) elemName - The child element tag name filter.
  ///    (Function) func - The function to apply to each child.  This
  ///      function should take a single argument, a DOM element.
  static void forEachChild(xml.XmlNode elem, String elemName, Function func) {
    if (elem == null) return;
    var childNode;
    for (int i = 0; i < elem.children.length; i++) {
      try {
        if (elem.children.elementAt(i) is xml.XmlElement)
          childNode = elem.children.elementAt(i);
        else if (elem.children.elementAt(i) is xml.XmlDocument)
          childNode =
              (elem as xml.XmlDocument).rootElement.children.elementAt(i);
      } catch (e) {
        childNode = null;
      }
      if (childNode == null) continue;
      if (childNode.nodeType == xml.XmlNodeType.ELEMENT &&
          (elemName == null || isTagEqual(childNode, elemName))) {
        func(childNode);
      }
    }
  }

  /// Function: isTagEqual
  ///  Compare an element's tag name with a string.
  ///
  ///  This function is case sensitive.
  ///
  ///  Parameters:
  ///    (XMLElement) el - A DOM element.
  ///    (String) name - The element name.
  ///
  ///  Returns:
  ///    true if the element's tag name matches _el_, and false
  ///    otherwise.
  static bool isTagEqual(xml.XmlElement el, String name) {
    return el.name.qualified == name;
  }

  /// PrivateVariable: _xmlGenerator
  ///  _Private_ variable that caches a DOM document to
  ///  generate elements.
  static xml.XmlBuilder _xmlGenerator;

  /// PrivateFunction: _makeGenerator
  ///  _Private_ function that creates a dummy XML DOM document to serve as
  ///  an element and text node generator.
  static xml.XmlBuilder _makeGenerator() {
    xml.XmlBuilder builder = xml.XmlBuilder();
    //builder.element('strophe', namespace: 'jabber:client');
    return builder;
  }

  /// Function: xmlGenerator
  ///  Get the DOM document to generate elements.
  ///
  ///  Returns:
  ///    The currently used DOM document.
  static xml.XmlBuilder xmlGenerator() {
    //if (Strophe._xmlGenerator == null) {
    Strophe._xmlGenerator = Strophe._makeGenerator();
    //}
    return Strophe._xmlGenerator;
  }

  /// PrivateFunction: _getIEXmlDom
  ///  Gets IE xml doc object
  ///
  ///  Returns:
  ///    A Microsoft XML DOM Object
  ///  See Also:
  ///    http://msdn.microsoft.com/en-us/library/ms757837%28VS.85%29.aspx
  // todo: _getIEXmlDom

  /// Function: xmlElement
  ///  Create an XML DOM element.
  ///
  ///  This function creates an XML DOM element correctly across all
  ///  implementations. Note that these are not HTML DOM elements, which
  ///  aren't appropriate for XMPP stanzas.
  ///
  ///  Parameters:
  ///    (String) name - The name for the element.
  ///    (Array|Object) attrs - An optional array or object containing
  ///      key/value pairs to use as element attributes. The object should
  ///      be in the format {'key': 'value'} or {key: 'value'}. The array
  ///      should have the format [['key1', 'value1'], ['key2', 'value2']].
  ///    (String) text - The text child data for the element.
  ///
  ///  Returns:
  ///    A new XML DOM element.
  static xml.XmlNode xmlElement(String name, {dynamic attrs, String text}) {
    if (name == null || name.isEmpty || name.trim().length == 0) {
      return null;
    }
    if (attrs != null &&
        (attrs is! List<List<String>>) &&
        (attrs is! Map<String, dynamic>)) {
      return null;
    }
    Map<String, String> attributes = {};
    if (attrs != null) {
      if (attrs is List<List<String>>) {
        for (int i = 0; i < attrs.length; i++) {
          List<String> attr = attrs[i];
          if (attr.length == 2 && attr[1] != null && attr.isNotEmpty) {
            attributes[attr[0]] = attr[1].toString();
          }
        }
      } else if (attrs is Map<String, dynamic>) {
        List<String> keys = attrs.keys.toList();
        for (int i = 0, len = keys.length; i < len; i++) {
          String key = keys[i];
          if (key != null && key.isNotEmpty && attrs[key] != null) {
            attributes[key] = attrs[key].toString();
          }
        }
      }
    }
    xml.XmlBuilder builder = Strophe.xmlGenerator();
    builder.element(name, attributes: attributes, nest: text);
    return builder.buildDocument();
  }

  /// Function: xmlescape
  ///  Excapes invalid xml characters.
  ///
  ///  Parameters:
  ///     (String) text - text to escape.
  ///
  ///  Returns:
  ///      Escaped text.
  static String xmlescape(String text) {
    text = text.replaceAll(RegExp(r'&'), "&amp;");
    text = text.replaceAll(RegExp(r'<'), "&lt;");
    text = text.replaceAll(RegExp(r'>'), "&gt;");
    text = text.replaceAll(RegExp(r"'"), "&apos;");
    text = text.replaceAll(RegExp(r'"'), "&quot;");
    return text;
  }

  /// Function: xmlunescape
  ///  Unexcapes invalid xml characters.
  ///
  ///  Parameters:
  ///     (String) text - text to unescape.
  ///
  ///  Returns:
  ///      Unescaped text.
  static String xmlunescape(String text) {
    text = text.replaceAll(RegExp(r'&amp;'), "&");
    text = text.replaceAll(RegExp(r'&lt;'), "<");
    text = text.replaceAll(RegExp(r'&gt;'), ">");
    text = text.replaceAll(RegExp(r"&apos;"), "'");
    text = text.replaceAll(RegExp(r'&quot;'), '"');
    return text;
  }

  /// Function: xmlTextNode
  ///  Creates an XML DOM text node.
  ///
  ///  Parameters:
  ///    (String) text - The content of the text node.
  ///
  ///  Returns:
  ///    A new XML DOM text node.
  static xml.XmlNode xmlTextNode(String text) {
    xml.XmlBuilder builder = Strophe.xmlGenerator();
    builder.element('strophe', nest: text);
    return builder.buildDocument();
  }

  /// Function: xmlHtmlNode
  ///  Creates an XML DOM html node.
  ///
  ///  Parameters:
  ///    (String) html - The content of the html node.
  ///
  ///  Returns:
  ///    A new XML DOM text node.
  static xml.XmlNode xmlHtmlNode(String html) {
    xml.XmlNode parsed;
    try {
      parsed = xml.XmlDocument.parse(html);
    } catch (e) {
      parsed = null;
    }
    return parsed;
  }

  /// Function: getText
  ///  Get the concatenation of all text children of an element.
  ///
  ///  Parameters:
  ///    (XMLElement) elem - A DOM element.
  ///
  ///  Returns:
  ///    A String with the concatenated text of all text element children.
  static String getText(xml.XmlNode elem) {
    if (elem == null) {
      return null;
    }
    String str = '';
    if (elem.children.length == 0 && elem.nodeType == xml.XmlNodeType.TEXT) {
      str += elem.toString();
    }

    for (int i = 0; i < elem.children.length; i++) {
      if (elem.children[i].nodeType == xml.XmlNodeType.TEXT) {
        str += elem.children[i].toString();
      }
    }
    return Strophe.xmlescape(str);
  }

  /// Function: copyElement
  ///  Copy an XML DOM element.
  ///
  ///  This function copies a DOM element and all its descendants and returns
  ///  the new copy.
  ///
  ///  Parameters:
  ///    (XMLElement) elem - A DOM element.
  ///
  ///  Returns:
  ///    A new, copied DOM element tree.
  static xml.XmlNode copyElement(xml.XmlNode elem) {
    var el = elem;
    if (elem.nodeType == xml.XmlNodeType.ELEMENT) {
      el = elem.copy();
    } else if (elem.nodeType == xml.XmlNodeType.TEXT) {
      el = elem;
    } else if (elem.nodeType == xml.XmlNodeType.DOCUMENT) {
      el = elem.document.rootElement;
    }
    return el;
  }

  /// Function: createHtml
  ///  Copy an HTML DOM element into an XML DOM.
  ///
  ///  This function copies a DOM element and all its descendants and returns
  ///  the new copy.
  ///
  ///  Parameters:
  ///    (HTMLElement) elem - A DOM element.
  ///
  ///  Returns:
  ///    A new, copied DOM element tree.
  static xml.XmlNode createHtml(xml.XmlNode elem) {
    xml.XmlNode el;
    String tag;
    if (elem.nodeType == xml.XmlNodeType.ELEMENT) {
      // XHTML tags must be lower case.
      //tag = elem.
      if (Strophe.XHTML['validTag'](tag)) {
        try {
          el = Strophe.copyElement(elem);
        } catch (e) {
          // invalid elements
          el = Strophe.xmlTextNode('');
        }
      } else {
        el = Strophe.copyElement(elem);
      }
    } else if (elem.nodeType == xml.XmlNodeType.DOCUMENT_FRAGMENT) {
      el = Strophe.copyElement(elem);
    } else if (elem.nodeType == xml.XmlNodeType.TEXT) {
      el = Strophe.xmlTextNode(elem.toString());
    }
    return el;
  }

  /// Function: escapeNode
  ///  Escape the node part (also called local part) of a JID.
  ///
  ///  Parameters:
  ///    (String) node - A node (or local part).
  ///
  ///  Returns:
  ///    An escaped node (or local part).
  static String escapeNode(String node) {
    return node
        .replaceAll(RegExp(r"^\s+|\s+$"), '')
        .replaceAll(RegExp(r"\\"), "\\5c")
        .replaceAll(RegExp(r" "), "\\20")
        .replaceAll(RegExp(r'"'), "\\22")
        .replaceAll(RegExp(r'&'), "\\26")
        .replaceAll(RegExp(r"'"), "\\27")
        .replaceAll(RegExp(r'/'), "\\2f")
        .replaceAll(RegExp(r':'), "\\3a")
        .replaceAll(RegExp(r'<'), "\\3c")
        .replaceAll(RegExp(r'>'), "\\3e")
        .replaceAll(RegExp(r'@'), "\\40");
  }

  /// Function: unescapeNode
  ///  Unescape a node part (also called local part) of a JID.
  ///
  ///  Parameters:
  ///    (String) node - A node (or local part).
  ///
  ///  Returns:
  ///    An unescaped node (or local part).
  static String unescapeNode(String node) {
    return node
        .replaceAll(RegExp(r"\\5c"), "\\")
        .replaceAll(RegExp(r"\\20"), " ")
        .replaceAll(RegExp(r'\\22'), '"')
        .replaceAll(RegExp(r'\\26'), "&")
        .replaceAll(RegExp(r"\\27"), "'")
        .replaceAll(RegExp(r'\\2f'), "/")
        .replaceAll(RegExp(r'\\3a'), ":")
        .replaceAll(RegExp(r'\\3c'), "<")
        .replaceAll(RegExp(r'\\3e'), ">")
        .replaceAll(RegExp(r'\\40'), "@");
  }

  /// Function: getNodeFromJid
  ///  Get the node portion of a JID String.
  ///
  ///  Parameters:
  ///    (String) jid - A JID.
  ///
  ///  Returns:
  ///    A String containing the node.
  static String getNodeFromJid(String jid) {
    if (jid.indexOf("@") < 0) {
      return null;
    }
    return jid.split("@")[0];
  }

  /// Function: getDomainFromJid
  ///  Get the domain portion of a JID String.
  ///
  ///  Parameters:
  ///    (String) jid - A JID.
  ///
  ///  Returns:
  ///    A String containing the domain.
  static String getDomainFromJid(String jid) {
    String bare = Strophe.getBareJidFromJid(jid);
    if (bare.indexOf("@") < 0) {
      return bare;
    } else {
      List<String> parts = bare.split("@");
      parts.removeAt(0);
      return parts.join('@');
    }
  }

  /// Function: getResourceFromJid
  ///  Get the resource portion of a JID String.
  ///
  ///  Parameters:
  ///    (String) jid - A JID.
  ///
  ///  Returns:
  ///    A String containing the resource.
  static String getResourceFromJid(String jid) {
    List<String> s = jid.split('/');
    if (s.length < 2) {
      return null;
    }
    s.removeAt(0);
    return s.join('/');
  }

  /// Function: getBareJidFromJid
  ///  Get the bare JID from a JID String.
  ///
  ///  Parameters:
  ///    (String) jid - A JID.
  ///
  ///  Returns:
  ///    A String containing the bare JID.
  static String getBareJidFromJid(String jid) {
    return jid?.isNotEmpty == true ? jid.split("/")[0] : null;
  }

  /// PrivateFunction: _handleError
  ///  _Private_ function that properly logs an error to the console
  static handleError(Exception e) {
    Strophe.fatal("error: " +
        e.hashCode.toString() +
        " - " +
        e.runtimeType.toString() +
        ": " +
        e.toString() +
        StackTrace.current.toString());
  }

  /// Function: log
  ///  User overrideable logging function.
  ///
  ///  This function is called whenever the Strophe library calls any
  ///  of the logging functions.  The default implementation of this
  ///  function logs only fatal errors.  If client code wishes to handle the logging
  ///  messages, it should override this with
  ///  > Strophe.log = function (level, msg) {
  ///  >   (user code here)
  ///  > };
  ///
  ///  Please note that data sent and received over the wire is logged
  ///  via Strophe.Connection.rawInput() and Strophe.Connection.rawOutput().
  ///
  ///  The different levels and their meanings are
  ///
  ///    DEBUG - Messages useful for debugging purposes.
  ///    INFO - Informational messages.  This is mostly information like
  ///      'disconnect was called' or 'SASL auth succeeded'.
  ///    WARN - Warnings about potential problems.  This is mostly used
  ///      to report transient connection errors like request timeouts.
  ///    ERROR - Some error occurred.
  ///    FATAL - A non-recoverable fatal error occurred.
  ///
  ///  Parameters:
  ///    (Integer) level - The log level of the log message.  This will
  ///      be one of the values in Strophe.LogLevel.
  ///    (String) msg - The log message.
  static void log(int level, String msg) {
    // if (level != Strophe.LogLevel['FATAL']) {
    print(msg);
    // }
  }

  /// Function: debug
  ///  Log a message at the Strophe.LogLevel.DEBUG level.
  ///
  ///  Parameters:
  ///    (String) msg - The log message.
  static void debug(String msg) {
    Strophe.log(Strophe.LogLevel['DEBUG'], msg);
  }

  /// Function: info
  ///  Log a message at the Strophe.LogLevel.INFO level.
  ///
  ///  Parameters:
  ///    (String) msg - The log message.
  static void info(String msg) {
    Strophe.log(Strophe.LogLevel['INFO'], msg);
  }

  /// Function: warn
  ///  Log a message at the Strophe.LogLevel.WARN level.
  ///
  ///  Parameters:
  ///    (String) msg - The log message.
  static void warn(String msg) {
    Strophe.log(Strophe.LogLevel['WARN'], msg);
  }

  /// Function: error
  ///  Log a message at the Strophe.LogLevel.ERROR level.
  ///
  ///  Parameters:
  ///    (String) msg - The log message.
  static void error(String msg) {
    Strophe.log(Strophe.LogLevel['ERROR'], msg);
  }

  /// Function: fatal
  ///  Log a message at the Strophe.LogLevel.FATAL level.
  ///
  ///  Parameters:
  ///    (String) msg - The log message.
  static void fatal(String msg) {
    Strophe.log(Strophe.LogLevel['FATAL'], msg);
  }

  /// Function: serialize
  ///  Render a DOM element and all descendants to a String.
  ///
  ///  Parameters:
  ///    (XMLElement) elem - A DOM element.
  ///
  ///  Returns:
  ///    The serialized element tree as a String.
  static String serialize(xml.XmlNode elem) {
    if (elem == null) {
      return null;
    }

    return elem.toXmlString();
  }

  /// PrivateVariable: _requestId
  ///  _Private_ variable that keeps track of the request ids for
  ///  connections.
  static int requestId = 0;

  static Map<String, PluginClass> get connectionPlugins =>
      _connectionPlugins; // TODO: should this be done this way?

  /// PrivateVariable: Strophe.connectionPlugins
  ///  _Private_ variable Used to store plugin names that need
  ///  initialization on Strophe.Connection construction.
  static Map<String, PluginClass> _connectionPlugins = {};

  /// Function: addConnectionPlugin
  ///  Extends the Strophe.Connection object with the given plugin.
  ///
  ///  Parameters:
  ///    (String) name - The name of the extension.
  ///    (Object) ptype - The plugin's prototype.
  static void addConnectionPlugin(String name, ptype) {
    Strophe._connectionPlugins[name] = ptype;
  }

  static StropheSASLAnonymous SASLAnonymous = StropheSASLAnonymous();
  static StropheSASLPlain SASLPlain = StropheSASLPlain();
  static StropheSASLMD5 SASLMD5 = StropheSASLMD5();
  static StropheSASLSHA1 SASLSHA1 = StropheSASLSHA1();
  static StropheSASLOAuthBearer SASLOAuthBearer = StropheSASLOAuthBearer();
  static StropheSASLExternal SASLExternal = StropheSASLExternal();
  // static StropheSASLXOAuth2 SASLXOAuth2 = StropheSASLXOAuth2(); // TODO: this is only on latest master of Strophe JS

  // Helper, doesn't exists in the JS code
  // todo: enum
  static const Map<String, String> ErrorCondition = const {
    'BAD_FORMAT': "bad-format",
    'CONFLICT': "conflict",
    'MISSING_JID_NODE': "x-strophe-bad-non-anon-jid",
    'NO_AUTH_MECH': "no-auth-mech",
    'UNKNOWN_REASON': "unknown",
  };
}
