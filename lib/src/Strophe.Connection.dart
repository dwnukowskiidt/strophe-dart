import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:strophe/src/Strophe.Builder.dart';
import 'package:strophe/src/enums.dart';
import 'package:strophe/src/plugins/plugins.dart';
import 'package:strophe/src/sessionstorage.dart';
import 'package:xml/xml.dart' as xml;

import 'package:strophe/src/Strophe.Handler.dart';
import 'package:strophe/src/Strophe.TimedHandler.dart';
import 'package:strophe/src/bosh.dart';
import 'package:strophe/src/core.dart';
import 'package:strophe/src/utils.dart';
import 'package:xml/xml.dart';

class StropheConnection {
  String service;
  String pass;
  String authcid;
  String authzid;
  String servtype;
  Map<String, dynamic> options;

  String jid;

  ServiceType _proto;

  String domain;

  xml.XmlElement features;

  Map<String, dynamic> _saslData;

  bool doSession = false;

  bool doBind = false;

  Function _startConnection;

  Function _attachConnection;

  ///
  /// @typedef DeferredSendIQ Object
  /// @property {Element} iq - The IQ to send.
  /// @property {function} resolve - The resolve method of the deferred Promise.
  /// @property {function} reject - The reject method of the deferred Promise.
  /// @property {number} timeout - The ID of the timeout task that needs to be cleared, before sending the IQ.
  ///

  /// Deferred IQs to be sent upon reconnect.
  /// @type {Array<DeferredSendIQ>}
  /// @private
  // todo: List<DeferredSendIQ> _deferredIQs = [];

  RegisterPlugin get register {
    return Strophe.connectionPlugins['register'];
  }

  DiscoPlugin get disco {
    return Strophe.connectionPlugins['disco'];
  }

  RosterPlugin get roster {
    return Strophe.connectionPlugins['roster'];
  }

  AdministrationPlugin get admin {
    return Strophe.connectionPlugins['admin'];
  }

  CapsPlugin get caps {
    return Strophe.connectionPlugins['caps'];
  }

  MucPlugin get muc {
    return Strophe.connectionPlugins['muc'];
  }

  BookMarkPlugin get bookmarks {
    return Strophe.connectionPlugins['bookmarks'];
  }

  LastActivity get lastactivity {
    return Strophe.connectionPlugins['lastactivity'];
  }

  PepPlugin get pep {
    return Strophe.connectionPlugins['pep'];
  }

  PrivacyPlugin get privacy {
    return Strophe.connectionPlugins['privacy'];
  }

  PubsubPlugin get pubsub {
    return Strophe.connectionPlugins['pubsub'];
  }

  PrivateStorage get private {
    return Strophe.connectionPlugins['private'];
  }

  VCardTemp get vcard {
    return Strophe.connectionPlugins['vcard'];
  }

  ChatStatesNotificationPlugin get chatstates {
    return Strophe.connectionPlugins['chatstates'];
  }

  List<StropheTimedHandler> timedHandlers;

  List<StropheHandler> handlers;

  List<StropheTimedHandler> removeTimeds;

  List<StropheHandler> removeHandlers;

  List<StropheTimedHandler> addTimeds;

  Map<String, Map<int, Function>> protocolErrorHandlers;

  List<StropheHandler> addHandlers;

  Timer _idleTimeout;

  StropheTimedHandler _disconnectTimeout;

  bool authenticated = false;

  bool connected = false;

  bool disconnecting = false;

  bool doAuthentication = false;

  bool paused = false;

  bool restored = false;

  List<dynamic> _data;

  int _uniqueId;

  StropheHandler _saslSuccessHandler;

  StropheHandler _saslFailureHandler;

  StropheHandler _saslChallengeHandler;

  int maxRetries;

  List<Cookie> cookies;

  List<StropheRequest> _requests;

  ConnectCallBack connectCallback;

  StropheSASLMechanism _saslMechanism;

  Map Function(xml.XmlElement elem) _xmlInputCallback =
      (xml.XmlElement elem) => {};

  Map Function(xml.XmlElement elem) _xmlOutputCallback =
      (xml.XmlElement elem) => {};

  RawInputCallback _rawInputCallback = (String elem) => {};
  RawInputCallback _connexionErrorInputCallback = (String error) => {};

  RawInputCallback _rawOutputCallback = (String elem) => {};

  // The service URL
  int get uniqueId {
    return this._uniqueId;
  }

  List get requests {
    return this._requests;
  }

  Function _reset;
  ConnexionCallback _connectCb;
  AuthenticateCallback _authenticate;

  StropheConnection(String service, [Map options]) {
    // The service URL
    this.service = service;
    // Configuration options
    this.options = options ?? {};
    String proto = this.options['protocol'] ?? "";

    // Select protocal based on service or options
    if (service.indexOf("ws:") == 0 ||
        service.indexOf("wss:") == 0 ||
        proto.indexOf("ws") == 0) {
      this._proto = Strophe.Websocket(this);
    } else {
      this._proto = Strophe.Bosh(this);
    }
    /* The connected JID. */
    this.jid = "";
    /* the JIDs domain */
    this.domain = null;
    /* stream:features */
    this.features = null;

    // SASL
    this._saslData = {};
    this.doSession = false;
    this.doBind = false;

    // handler lists
    this.timedHandlers = [];
    this.handlers = [];
    this.removeTimeds = [];
    this.removeHandlers = [];
    this.addTimeds = [];
    this.addHandlers = [];
    this.protocolErrorHandlers = {
      'HTTP': {},
      'websocket': {},
    };
    this._idleTimeout = null;
    this._disconnectTimeout = null;

    this.authenticated = false;
    this.connected = false;
    this.disconnecting = false;
    this.doAuthentication = true;
    this.paused = false;
    this.restored = false;

    this._data = [];
    this._uniqueId = 0;

    this._saslSuccessHandler = null;
    this._saslFailureHandler = null;
    this._saslChallengeHandler = null;

    // Max retries before disconnecting
    this.maxRetries = 5;

    // Call onIdle callback every 1/10th of a second
    // XXX: setTimeout should be called only with function expressions (23974bc1)
    this._idleTimeout = Timer(const Duration(milliseconds: 100), () {
      this._onIdle(); // TODO: check if timer is a good approach here
    });

    this.cookies = Utils.addCookies(this.options['cookies']);
    this.registerSASLMechanisms(this.options['mechanisms']);

    this.initializeFunction();
    this._startConnection = this._connect; // TODO: what is this?
    this._attachConnection = this._attach; // TODO: what is this?

    // initialize plugins
    Strophe.connectionPlugins.forEach((String key, PluginClass value) {
      Strophe.connectionPlugins[key].init(this);
    });
  }

  initializeFunction() {
    // TODO: check if this is needed to be done this way? maybe the _reset func
    // can leave as normal func

    this._reset = () {
      this._proto.reset();

      // SASL
      this.doSession = false;
      this.doBind = false;

      // handler lists
      this.timedHandlers = [];
      this.handlers = [];
      this.removeTimeds = [];
      this.removeHandlers = [];
      this.addTimeds = [];
      this.addHandlers = [];

      this.authenticated = false;
      this.connected = false;
      this.disconnecting = false;
      this.restored = false;

      this._data = [];
      this._requests = [];
      this._uniqueId = 0;
    };

    this._connectCb = (req, [Function _callback, String raw]) {
      Strophe.info("_connect_cb was called");
      this.connected = true;

      xml.XmlElement bodyWrap;
      try {
        bodyWrap = this._proto.reqToData(req);
      } catch (e) {
        if (e.toString() != "badformat") {
          throw e;
        }
        this._changeConnectStatus(
            Strophe.Status['CONNFAIL'], Strophe.ErrorCondition['BAD_FORMAT']);
        this._doDisconnect(Strophe.ErrorCondition['BAD_FORMAT']);
      }
      if (bodyWrap == null) {
        return;
      }

      //if (this.xmlInput != Strophe.Connection.xmlInput) { // TODO: this here is also commented out
      if (bodyWrap.name.qualified == this._proto.strip &&
          bodyWrap.children.length > 0) {
        this.xmlInput(bodyWrap.firstChild);
      } else {
        this.xmlInput(bodyWrap);
      }
      //}
      //if (this.rawInput != Strophe.Connection.rawInput) {
      if (raw != null) {
        this.rawInput(raw);
      } else {
        this.rawInput(Strophe.serialize(bodyWrap));
      }
      //}

      int conncheck = this._proto.connectCb(bodyWrap);
      if (conncheck == Strophe.Status['CONNFAIL']) {
        return;
      }

      // Check for the stream:features tag
      bool hasFeatures;
      if (bodyWrap.getAttribute('xmlns') == Strophe.NS['STREAM']) {
        hasFeatures = bodyWrap.findAllElements("features").length > 0 ??
            bodyWrap.findAllElements("stream:features").length > 0;
      } else {
        hasFeatures = bodyWrap.findAllElements("stream:features").length > 0 ??
            bodyWrap.findAllElements("features").length > 0;
      }
      if (!hasFeatures) {
        this._noAuthReceived(_callback);
        return;
      }

      List<StropheSASLMechanism> matched = [];
      String mech;
      List<xml.XmlElement> mechanisms =
          bodyWrap.findAllElements("mechanism").toList();
      if (mechanisms.length > 0) {
        for (int i = 0; i < mechanisms.length; i++) {
          mech = Strophe.getText(mechanisms.elementAt(i));
          if (this.mechanisms[mech] != null) {
            matched.add(this.mechanisms[mech]);
          }
        }
      }
      if (matched.length == 0) {
        if (bodyWrap.findAllElements("auth").length == 0) {
          // There are no matching SASL mechanisms and also no legacy
          // auth available.
          this._noAuthReceived(
              _callback); // TODO: in orig JS this is called on _proto
          return;
        }
      }
      if (this.doAuthentication != false) {
        this.authenticate(matched);
      }
    };
    this._authenticate = (List<StropheSASLMechanism> matched) {
      this._attemptSASLAuth(matched).then((bool result) {
        if (result != true) {
          this._attemptLegacyAuth();
        }
      });
    };
  }

  addConnectionPlugin(String name, PluginClass ptype) {
    Strophe.addConnectionPlugin(name, ptype);
    ptype.init(this);
  }

  ServiceType get proto {
    return this._proto;
  }

  set proto(ServiceType pro) {
    this._proto = pro;
  }

  List<dynamic> get data {
    return this._data;
  }

  set data(data) {
    this._data = data;
  }

  Timer get idleTimeout {
    return this._idleTimeout;
  }

  set idleTimeout(Timer newTimeout) {
    this._idleTimeout = newTimeout;
  }

  /// Function: reset
  /// Reset the connection.
  ///
  /// This function should be called after a connection is disconnected
  /// before this connection is reused.
  ///
  set reset(Function callback) {
    this._reset = callback;
  }

  Function get reset {
    if (_reset == null) {
      initializeFunction();
    }
    return this._reset;
  }

  /// Function: pause
  /// Pause the request manager.
  ///
  /// This will prevent Strophe from sending any more requests to the
  /// server.  This is very useful for temporarily pausing
  /// BOSH-Connections while a lot of send() calls are happening quickly.
  /// This causes Strophe to send the data in a single request, saving
  /// many request trips.
  ///
  pause() {
    this.paused = true;
  }

  /// Function: resume
  /// Resume the request manager.
  ///
  /// This resumes after pause() has been called.
  ///
  resume() {
    this.paused = false;
  }

  /// Function: getUniqueId
  /// Generate a unique ID for use in <iq/> elements.
  ///
  /// All <iq/> stanzas are required to have unique id attributes.  This
  /// function makes creating these easy.  Each connection instance has
  /// a counter which starts from zero, and the value of this counter
  /// plus a colon followed by the suffix becomes the unique id. If no
  /// suffix is supplied, the counter is used as the unique id.
  ///
  /// Suffixes are used to make debugging easier when reading the stream
  /// data, and their use is recommended.  The counter resets to 0 for
  /// every new connection for the same reason.  For connections to the
  /// same server this authenticate the same way, all the ids should be
  /// the same, which makes it easy to see changes.  This is useful for
  /// automated testing as well.
  ///
  /// Parameters:
  /// (String) suffix - A optional suffix to append to the id.
  ///
  /// Returns:
  /// A unique string to be used for the id attribute.
  ///
  String getUniqueId([String suffix]) {
    String uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
        .replaceAllMapped(new RegExp(r"[xy]"), (Match c) {
      int r = new Random().nextInt(16) | 0;
      int v = c.group(0) == 'x' ? r : r & 0x3 | 0x8;
      return v.toRadixString(16);
    });
    if (suffix != null) {
      return uuid + ":" + suffix;
    } else {
      return uuid + "";
    }
  }

  /// Function: addProtocolErrorHandler
  /// Register a handler function for when a protocol (websocker or HTTP)
  /// error occurs.
  ///
  /// NOTE: Currently only HTTP errors for BOSH requests are handled.
  /// Patches this handle websocket errors would be very welcome.
  ///
  /// Parameters:
  /// (String) protocol - 'HTTP' or 'websocket'
  /// (Integer) status_code - Error status code (e.g 500, 400 or 404)
  /// (Function) callback - Function this will fire on Http error
  ///
  /// Example:
  /// function onError(err_code){
  /// //do stuff
  /// }
  ///
  /// var conn = Strophe.connect('http://example.com/http-bind');
  /// conn.addProtocolErrorHandler('HTTP', 500, onError);
  /// // Triggers HTTP 500 error and onError handler will be called
  /// conn.connect('user_jid@incorrect_jabber_host', 'secret', onConnect);
  ///
  addProtocolErrorHandler(String protocol, int statusCode, Function callback) {
    this.protocolErrorHandlers[protocol][statusCode] = callback;
  }

  /// Function: connect
  /// Starts the connection process.
  ///
  /// As the connection process proceeds, the user supplied callback will
  /// be triggered multiple times with status updates.  The callback
  /// should take two arguments - the status code and the error condition.
  ///
  /// The status code will be one of the values in the Strophe.Status
  /// constants.  The error condition will be one of the conditions
  /// defined in RFC 3920 or the condition 'strophe-parsererror'.
  ///
  /// The Parameters _wait_, _hold_ and _route_ are optional and only relevant
  /// for BOSH connections. Please see XEP 124 for a more detailed explanation
  /// of the optional parameters.
  ///
  /// Parameters:
  /// (String) jid - The user's JID.  This may be a bare JID,
  /// or a full JID.  If a node is not supplied, SASL OAUTHBEARER or
  /// SASL ANONYMOUS authentication will be attempted (OAUTHBEARER will
  /// process the provided password value as an access token).
  /// (String) pass - The user's password.
  /// (Function) callback - The connect callback function.
  /// (Integer) wait - The optional HTTPBIND wait value.  This is the
  /// time the server will wait before returning an empty result for
  /// a request.  The default setting of 60 seconds is recommended.
  /// (Integer) hold - The optional HTTPBIND hold value.  This is the
  /// number of connections the server will hold at one time.  This
  /// should almost always be set to 1 (the default).
  /// (String) route - The optional route value.
  /// (String) authcid - The optional alternative authentication identity
  /// (username) if intending to impersonate another user.
  /// When using the SASL-EXTERNAL authentication mechanism, for example
  /// with client certificates, then the authcid value is used to
  /// determine whether an authorization JID (authzid) should be sent to
  /// the server. The authzid should not be sent to the server if the
  /// authzid and authcid are the same. So to prevent it from being sent
  /// (for example when the JID is already contained in the client
  /// certificate), set authcid to this same JID. See XEP-178 for more
  /// details.
  ///
  Function get connect {
    return this._startConnection ?? _connect;
  }

  set connect(Function value) {
    // TODO: figure out why there is a setter and a getter for this func
    this._startConnection = value;
  }

  _connect(String jid, String pass, ConnectCallBack callback,
      [int wait, int hold, String route, String authcid]) {
    this.jid = jid;

    /// Variable: authzid
    /// Authorization identity.
    ///
    this.authzid = Strophe.getBareJidFromJid(this.jid);

    /// Variable: authcid
    /// Authentication identity (User name).
    ///
    this.authcid = authcid ?? Strophe.getNodeFromJid(this.jid);

    /// Variable: pass
    /// Authentication identity (User password).
    ///
    this.pass = pass;

    /// Variable: servtype
    /// Digest MD5 compatibility.
    ///
    this.servtype = "xmpp";

    this.connectCallback = callback;
    this.disconnecting = false;
    this.connected = false;
    this.authenticated = false;
    this.restored = false;

    // parse jid for domain
    this.domain = Strophe.getDomainFromJid(this.jid);

    this._changeConnectStatus(Strophe.Status['CONNECTING'], null);

    this._proto.connect(wait, hold, route);
  }

  /// Function: attach
  /// Attach to an already created and authenticated BOSH session.
  ///
  /// This function is provided to allow Strophe to attach to BOSH
  /// sessions which have been created externally, perhaps by a Web
  /// application.  This is often used to support auto-login type features
  /// without putting user credentials into the page.
  ///
  /// Parameters:
  /// (String) jid - The full JID this is bound by the session.
  /// (String) sid - The SID of the BOSH session.
  /// (String) rid - The current RID of the BOSH session.  This RID
  /// will be used by the next request.
  /// (Function) callback The connect callback function.
  /// (Integer) wait - The optional HTTPBIND wait value.  This is the
  /// time the server will wait before returning an empty result for
  /// a request.  The default setting of 60 seconds is recommended.
  /// Other settings will require tweaks to the Strophe.TIMEOUT value.
  /// (Integer) hold - The optional HTTPBIND hold value.  This is the
  /// number of connections the server will hold at one time.  This
  /// should almost always be set to 1 (the default).
  /// (Integer) wind - The optional HTTBIND window value.  This is the
  /// allowed range of request ids this are valid.  The default is 5.
  Function get attach {
    return this._attachConnection ?? _attach;
  }

  set attach(Function value) {
    this._attachConnection = value;
  }

  _attach(String jid, String sid, int rid, Function callback, int wait,
      int hold, int wind) {
    if (this._proto is StropheBosh) {
      this._proto.attach(jid, sid, rid, callback, wait, hold, wind);
    } else {
      throw {
        'name': 'StropheSessionError',
        'message':
            'The "attach" method can only be used with a BOSH connection.'
      };
    }
  }

  /// Function: restore
  /// Attempt to restore a cached BOSH session.
  ///
  /// This function is only useful in conjunction with providing the
  /// "keepalive":true option when instantiating a new Strophe.Connection.
  ///
  /// When "keepalive" is set to true, Strophe will cache the BOSH tokens
  /// RID (Request ID) and SID (Session ID) and then when this function is
  /// called, it will attempt to restore the session from those cached
  /// tokens.
  ///
  /// This function must therefore be called instead of connect or attach.
  ///
  /// For an example on how to use it, please see examples/restore.js
  ///
  /// Parameters:
  /// (String) jid - The user's JID.  This may be a bare JID or a full JID.
  /// (Function) callback - The connect callback function.
  /// (Integer) wait - The optional HTTPBIND wait value.  This is the
  /// time the server will wait before returning an empty result for
  /// a request.  The default setting of 60 seconds is recommended.
  /// (Integer) hold - The optional HTTPBIND hold value.  This is the
  /// number of connections the server will hold at one time.  This
  /// should almost always be set to 1 (the default).
  /// (Integer) wind - The optional HTTBIND window value.  This is the
  /// allowed range of request ids this are valid.  The default is 5.
  void restore(String jid, Function callback, int wait, int hold, int wind) {
    if (this._sessionCachingSupported()) {
      this._proto.restore(jid, callback, wait, hold, wind);
    } else {
      throw {
        'name': 'StropheSessionError',
        'message':
            'The "restore" method can only be used with a BOSH connection.'
      };
    }
  }

  /// PrivateFunction: _sessionCachingSupported
  /// Checks whether sessionStorage and JSON are supported and whether we're
  /// using BOSH.
  bool sessionCachingSupported() {
    return this._sessionCachingSupported();
  }

  bool _sessionCachingSupported() {
    if (this._proto is StropheBosh) {
      try {
        SessionStorage.setItem('_strophe_', '_strophe_');
        SessionStorage.removeItem('_strophe_');
      } catch (e) {
        return false;
      }
      return true;
    }
    return false;
  }

  /// Function: xmlInput
  /// User overrideable function this receives XML data coming into the
  /// connection.
  ///
  /// The default function does nothing.  User code can override this with
  /// > Strophe.Connection.xmlInput = function (elem) {
  /// >   (user code)
  /// > };
  ///
  /// Due to limitations of current Browsers' XML-Parsers the opening and closing
  /// <stream> tag for WebSocket-Connoctions will be passed as selfclosing here.
  ///
  /// BOSH-Connections will have all stanzas wrapped in a <body> tag. See
  /// <Strophe.Bosh.strip> if you want to strip this tag.
  ///
  /// Parameters:
  /// (XMLElement) elem - The XML data received by the connection.
  ///
  set xmlInput(XmlInputCallback callback) {
    this._xmlInputCallback = callback;
  }

  XmlInputCallback get xmlInput {
    return this._xmlInputCallback;
  }

  /// Function: xmlOutput
  /// User overrideable function this receives XML data sent to the
  /// connection.
  ///
  /// The default function does nothing.  User code can override this with
  /// > Strophe.Connection.xmlOutput = function (elem) {
  /// >   (user code)
  /// > };
  ///
  /// Due to limitations of current Browsers' XML-Parsers the opening and closing
  /// <stream> tag for WebSocket-Connoctions will be passed as selfclosing here.
  ///
  /// BOSH-Connections will have all stanzas wrapped in a <body> tag. See
  /// <Strophe.Bosh.strip> if you want to strip this tag.
  ///
  /// Parameters:
  /// (XMLElement) elem - The XMLdata sent by the connection.
  ///
  set xmlOutput(XmlInputCallback callback) {
    this._xmlOutputCallback = callback;
  }

  XmlInputCallback get xmlOutput {
    return this._xmlOutputCallback;
  }

  /// Function: rawInput
  /// User overrideable function this receives raw data coming into the
  /// connection.
  ///
  /// The default function does nothing.  User code can override this with
  /// > Strophe.Connection.rawInput = function (data) {
  /// >   (user code)
  /// > };
  ///
  /// Parameters:
  /// (String) data - The data received by the connection.
  ///
  set rawInput(RawInputCallback callback) {
    this._rawInputCallback = callback;
  }

  RawInputCallback get rawInput {
    return this._rawInputCallback;
  }

  /// Function: rawOutput
  /// User overrideable function this receives raw data sent to the
  /// connection.
  ///
  /// The default function does nothing.  User code can override this with
  /// > Strophe.Connection.rawOutput = function (data) {
  /// >   (user code)
  /// > };
  ///
  /// Parameters:
  /// (String) data - The data sent by the connection.
  ///
  set rawOutput(RawInputCallback callback) {
    this._rawOutputCallback = callback;
  }

  RawInputCallback get rawOutput {
    return this._rawOutputCallback;
  }

  /// Function: nextValidRid
  /// User overrideable function this receives the new valid rid.
  ///
  /// The default function does nothing. User code can override this with
  /// > Strophe.Connection.nextValidRid = function (rid) {
  /// >    (user code)
  /// > };
  ///
  /// Parameters:
  /// (Number) rid - The next valid rid
  ///
  nextValidRid(int rid) {
    return;
  }

  /// Function: send
  /// Send a stanza.
  ///
  /// This function is called to add data onto the send queue to
  /// go out over the wire.  Whenever a request is sent to the BOSH
  /// server, all pending data is sent and the queue is flushed.
  ///
  /// Parameters:
  /// (XMLElement |
  /// [XMLElement] |
  /// Strophe.Builder) elem - The stanza to send.
  ///
  void send(dynamic elem) {
    if (elem == null) {
      return;
    }
    if (elem is List) {
      for (int i = 0; i < elem.length; i++) {
        if (elem[i] is xml.XmlNode) {
          this._queueData(elem[i]);
        } else if (elem[i] is StropheBuilder) {
          this._queueData(elem[i].tree());
        }
      }
    } else {
      if (elem is xml.XmlNode) {
        this._queueData(elem);
      } else if (elem is StropheBuilder) {
        this._queueData(elem.tree());
      }
    }
    this._proto.send();
  }

  /// Function: flush
  /// Immediately send any pending outgoing data.
  ///
  /// Normally send() queues outgoing data until the next idle period
  /// (100ms), which optimizes network use in the common cases when
  /// several send()s are called in succession. flush() can be used to
  /// immediately send all pending data.
  ///
  flush() {
    // cancel the pending idle period and run the idle function
    // immediately
    if (this._idleTimeout != null) this._idleTimeout.cancel();
    this._onIdle();
  }

  /// Function: sendPresence
  /// Helper function to send presence stanzas. The main benefit is for
  /// sending presence stanzas for which you expect a responding presence
  /// stanza with the same id (for example when leaving a chat room).
  ///
  /// Parameters:
  /// (XMLElement) elem - The stanza to send.
  /// (Function) callback - The callback function for a successful request.
  /// (Function) errback - The callback function for a failed or timed
  /// out request.  On timeout, the stanza will be null.
  /// (Integer) timeout - The time specified in milliseconds for a
  /// timeout to occur.
  ///
  /// Returns:
  /// The id used to send the presence.
  ///
  String sendPresence(xml.XmlNode element,
      [Function callback, Function errback, int timeout]) {
    StropheTimedHandler timeoutHandler;
    xml.XmlElement elem = element is xml.XmlDocument
        ? element.rootElement
        : (element as xml.XmlElement);
    String id = elem.getAttribute("id");
    if (id == null || id.isEmpty) {
      // inject id if not found
      id = this.getUniqueId("sendPresence");
      elem.attributes
          .add(new xml.XmlAttribute(new xml.XmlName.fromString('id'), id));
    }

    if (callback == null || errback == null) {
      StropheHandler handler = this.addHandler((stanza) {
        // remove timeout handler if there is one
        if (timeoutHandler != null) {
          this.deleteTimedHandler(timeoutHandler);
        }
        String type = elem.getAttribute("type");
        if (type == 'error') {
          if (errback != null) {
            errback(stanza);
          }
        } else if (callback != null) {
          callback(stanza);
        }
      }, null, 'presence', null, id);

      // if timeout specified, set up a timeout handler.
      if (timeout != null && timeout > 0) {
        timeoutHandler = this.addTimedHandler(timeout, () {
          // get rid of normal handler
          this.deleteHandler(handler);
          // call errback on timeout with null stanza
          if (errback != null) {
            errback(null);
          }
          return false;
        });
      }
    }
    this.send(elem);
    return id;
  }

  /// Function: sendIQ
  /// Helper function to send IQ stanzas.
  ///
  /// Parameters:
  /// (XMLElement) elem - The stanza to send.
  /// (Function) callback - The callback function for a successful request.
  /// (Function) errback - The callback function for a failed or timed
  /// out request.  On timeout, the stanza will be null.
  /// (Integer) timeout - The time specified in milliseconds for a
  /// timeout to occur.
  ///
  /// Returns:
  /// The id used to send the IQ.
  ///
  String sendIQ(
    xml.XmlNode el, [
    Function(XmlElement stanza) onSuccess,
    Function(XmlElement stanza) onError,
    int timeout,
  ]) {
    StropheTimedHandler timeoutHandler;
    xml.XmlElement elem = el;
    if (el is xml.XmlDocument) {
      elem = el.rootElement;
    } else if (el is xml.XmlElement) {
      elem = el;
    }
    String id = elem.getAttribute("id");
    if (id == null && id.isNotEmpty) {
      // inject id if not found
      id = this.getUniqueId("sendIQ");
      elem.attributes
          .add(new xml.XmlAttribute(new xml.XmlName.fromString('id'), id));
    }

    if (onSuccess != null || onError != null) {
      StropheHandler handler = this.addHandler((stanza) {
        // remove timeout handler if there is one
        if (timeoutHandler != null) {
          this.deleteTimedHandler(timeoutHandler);
        }
        if (stanza is xml.XmlDocument) {
          stanza = stanza.rootElement;
        }
        String iqtype = stanza.getAttribute("type");
        if (iqtype == 'result') {
          if (onSuccess != null) {
            onSuccess(stanza);
          }
        } else if (iqtype == 'error') {
          if (onError != null) {
            onError(stanza);
          }
        } else {
          throw {
            'name': "StropheError",
            'message': "Got bad IQ type of " + iqtype
          };
        }
      }, null, 'iq', ['error', 'result'], id);
      // if timeout specified, set up a timeout handler.
      if (timeout != null && timeout > 0) {
        timeoutHandler = this.addTimedHandler(timeout, () {
          // get rid of normal handler
          this.deleteHandler(handler);
          // call errback on timeout with null stanza
          if (onError != null) {
            onError(null);
          }
          return false;
        });
      }
    }
    this.send(elem);
    return id;
  }

  /// PrivateFunction: _queueData
  /// Queue outgoing data for later sending.  Also ensures this the data
  /// is a DOMElement.
  ///
  _queueData(xml.XmlNode element) {
    xml.XmlElement elem = element is xml.XmlDocument
        ? element.rootElement
        : (element as xml.XmlElement);

    if (elem == null || elem.name == null) {
      throw {
        'name': "StropheError",
        'message': "Cannot queue non-DOMElement.",
      };
    }
    this._data.add(elem);
  }

  /// PrivateFunction: _sendRestart
  /// Send an xmpp:restart stanza.
  ///
  _sendRestart() {
    this._data.add("restart");
    this._proto.sendRestart();
    // XXX: setTimeout should be called only with function expressions (23974bc1)
    this._idleTimeout = new Timer(new Duration(milliseconds: 100), () {
      this._onIdle();
    });
  }

  /// Function: addTimedHandler
  /// Add a timed handler to the connection.
  ///
  /// This function adds a timed handler.  The provided handler will
  /// be called every period milliseconds until it returns false,
  /// the connection is terminated, or the handler is removed.  Handlers
  /// this wish to continue being invoked should return true.
  ///
  /// Because of method binding it is necessary to save the result of
  /// this function if you wish to remove a handler with
  /// deleteTimedHandler().
  ///
  /// Note this user handlers are not active until authentication is
  /// successful.
  ///
  /// Parameters:
  /// (Integer) period - The period of the handler.
  /// (Function) handler - The callback function.
  ///
  /// Returns:
  /// A reference to the handler this can be used to remove it.
  ///
  StropheTimedHandler addTimedHandler(int period, Function handler) {
    StropheTimedHandler thand = Strophe.TimedHandler(period, handler);
    this.addTimeds.add(thand);
    return thand;
  }

  /// Function: deleteTimedHandler
  /// Delete a timed handler for a connection.
  ///
  /// This function removes a timed handler from the connection.  The
  /// handRef parameter is *not* the function passed to addTimedHandler(),
  /// but is the reference returned from addTimedHandler().
  ///
  /// Parameters:
  /// (Strophe.TimedHandler) handRef - The handler reference.
  ///
  deleteTimedHandler(StropheTimedHandler handRef) {
    // this must be done in the Idle loop so this we don't change
    // the handlers during iteration
    this.removeTimeds.add(handRef);
  }

  /// Function: addHandler
  /// Add a stanza handler for the connection.
  ///
  /// This function adds a stanza handler to the connection.  The
  /// handler callback will be called for any stanza this matches
  /// the parameters.  Note this if multiple parameters are supplied,
  /// they must all match for the handler to be invoked.
  ///
  /// The handler will receive the stanza this triggered it as its argument.
  /// *The handler should return true if it is to be invoked again;
  /// returning false will remove the handler after it returns.*
  ///
  /// As a convenience, the ns parameters applies to the top level element
  /// and also any of its immediate children.  This is primarily to make
  /// matching /iq/query elements easy.
  ///
  /// Options
  /// ~~~~~~~
  /// With the options argument, you can specify boolean flags this affect how
  /// matches are being done.
  ///
  /// Currently two flags exist:
  ///
  /// - matchBareFromJid:
  /// When set to true, the from parameter and the
  /// from attribute on the stanza will be matched as bare JIDs instead
  /// of full JIDs. To use this, pass {matchBareFromJid: true} as the
  /// value of options. The default value for matchBareFromJid is false.
  ///
  /// - ignoreNamespaceFragment:
  /// When set to true, a fragment specified on the stanza's namespace
  /// URL will be ignored when it's matched with the one configured for
  /// the handler.
  ///
  /// This means this if you register like this:
  /// >   connection.addHandler(
  /// >       handler,
  /// >       'http://jabber.org/protocol/muc',
  /// >       null, null, null, null,
  /// >       {'ignoreNamespaceFragment': true}
  /// >   );
  ///
  /// Then a stanza with XML namespace of
  /// 'http://jabber.org/protocol/muc#user' will also be matched. If
  /// 'ignoreNamespaceFragment' is false, then only stanzas with
  /// 'http://jabber.org/protocol/muc' will be matched.
  ///
  /// Deleting the handler
  /// ~~~~~~~~~~~~~~~~~~~~
  /// The return value should be saved if you wish to remove the handler
  /// with deleteHandler().
  ///
  /// Parameters:
  /// (Function) handler - The user callback.
  /// (String) ns - The namespace to match.
  /// (String) name - The stanza name to match.
  /// (String|Array) type - The stanza type (or types if an array) to match.
  /// (String) id - The stanza id attribute to match.
  /// (String) from - The stanza from attribute to match.
  /// (String) options - The handler options
  ///
  /// Returns:
  /// A reference to the handler this can be used to remove it.
  ///
  StropheHandler addHandler(Function handler, String ns, String name,
      [dynamic type, String id, String from, options]) {
    StropheHandler hand =
        Strophe.Handler(handler, ns, name, type, id, from, options);
    this.addHandlers.add(hand);
    return hand;
  }

  /// Function: deleteHandler
  /// Delete a stanza handler for a connection.
  ///
  /// This function removes a stanza handler from the connection.  The
  /// handRef parameter is *not* the function passed to addHandler(),
  /// but is the reference returned from addHandler().
  ///
  /// Parameters:
  ///   (Strophe.Handler) handRef - The handler reference.
  ///
  deleteHandler(StropheHandler handRef) {
    // this must be done in the Idle loop so this we don't change
    // the handlers during iteration
    this.removeHandlers.add(handRef);
    // If a handler is being deleted while it is being added,
    // prevent it from getting added
    int i = this.addHandlers.indexOf(handRef);
    if (i >= 0) {
      this.addHandlers.removeAt(i);
    }
  }

  /// Function: registerSASLMechanisms
  ///
  /// Register the SASL mechanisms which will be supported by this instance of
  /// Strophe.Connection (i.e. which this XMPP client will support).
  ///
  /// Parameters:
  ///   (Array) mechanisms - Array of objects with Strophe.SASLMechanism prototypes
  ///
  registerSASLMechanisms(mechanisms) {
    this.mechanisms = {};
    mechanisms = mechanisms ??
        [
          Strophe.SASLAnonymous,
          Strophe.SASLExternal,
          Strophe.SASLMD5, // TODO: not on master branch of Strophe JS
          Strophe.SASLOAuthBearer,
          Strophe.SASLXOAuth2, // TODO: this is only on master of Strophe JS
          Strophe.SASLPlain,
          Strophe.SASLSHA1
        ];
    mechanisms.forEach(this.registerSASLMechanism);
  }

  /// Function: registerSASLMechanism
  ///
  /// Register a single SASL mechanism, to be supported by this client.
  ///
  ///  Parameters:
  ///    (Object) mechanism - Object with a Strophe.SASLMechanism prototype
  ///
  registerSASLMechanism(StropheSASLMechanism mechanism) {
    this.mechanisms[mechanism.name] = mechanism;
  }

  /// Function: disconnect
  /// Start the graceful disconnection process.
  ///
  /// This function starts the disconnection process.  This process starts
  /// by sending unavailable presence and sending BOSH body of type
  /// terminate.  A timeout handler makes sure this disconnection happens
  /// even if the BOSH server does not respond.
  /// If the Connection object isn't connected, at least tries to abort all pending requests
  /// so the connection object won't generate successful requests (which were already opened).
  ///
  /// The user supplied connection callback will be notified of the
  /// progress as this process happens.
  ///
  /// Parameters:
  ///   (String) reason - The reason the disconnect is occuring.
  ///
  disconnect([String reason = ""]) {
    this._changeConnectStatus(Strophe.Status['DISCONNECTING'], reason);

    Strophe.info("Disconnect was called because: " + reason);
    if (this.connected) {
      StropheBuilder pres;
      this.disconnecting = true;
      if (this.authenticated) {
        pres = Strophe.$pres({
          'xmlns': Strophe.NS['CLIENT'],
          'type': 'unavailable',
        });
      }
      // setup timeout handler
      this._disconnectTimeout =
          this._addSysTimedHandler(3000, this._onDisconnectTimeout);
      this._proto.disconnect(pres?.tree());
    } else {
      Strophe.info(
          "Disconnect was called before Strophe connected to the server");
      this._proto.abortAllRequests();
      this._doDisconnect();
    }
  }

// PrivateFunction: _changeConnectStatus
//  _Private_ helper function this makes sure plugins and the user's
//  callback are notified of connection status changes.
//
//  Parameters:
//    (Integer) status - the new connection status, one of the values
//      in Strophe.Status
//    (String) condition - the error condition or null
//    (XMLElement) elem - The triggering stanza.
//
  changeConnectStatus(int status, String condition, [xml.XmlNode elem]) {
    this._changeConnectStatus(status, condition, elem);
  }

  _changeConnectStatus(int status, [String condition, xml.XmlNode elem]) {
    // notify all plugins listening for status changes
    Strophe.connectionPlugins.forEach((String key, PluginClass plugin) {
      if (plugin.statusChanged != null) {
        try {
          plugin.statusChanged(status, condition);
        } catch (err) {
          Strophe.error("" +
              key +
              " plugin caused an exception " +
              "changing status: " +
              err);
        }
      }
    });

    // notify the user's callback
    if (this.connectCallback != null) {
      try {
        if (connectCallback != null)
          this.connectCallback(status, condition, elem);
      } catch (e) {
        if (e is Error) Strophe.handleError(e);
        Strophe.error("User connection callback caused an " +
            "exception: " +
            e.toString());
      }
    }
  }

  /// PrivateFunction: _doDisconnect
  ///  _Private_ function to disconnect.
  ///
  ///  This is the last piece of the disconnection logic.  This resets the
  ///  connection and alerts the user's connection callback.
  ///
  doDisconnect([condition]) {
    return this._doDisconnect(condition);
  }

  _doDisconnect([condition]) {
    if (this._idleTimeout != null) {
      this._idleTimeout.cancel();
    }

    // Cancel Disconnect Timeout
    if (this._disconnectTimeout != null) {
      this.deleteTimedHandler(this._disconnectTimeout);
      this._disconnectTimeout = null;
    }
    Strophe.info("_doDisconnect was called");
    this._proto.doDisconnect();

    this.authenticated = false;
    this.disconnecting = false;
    this.restored = false;

    // delete handlers
    this.handlers = [];
    this.timedHandlers = [];
    this.removeTimeds = [];
    this.removeHandlers = [];
    this.addTimeds = [];
    this.addHandlers = [];

    // tell the parent we disconnected
    this._changeConnectStatus(Strophe.Status['DISCONNECTED'], condition);
    this.connected = false;
  }

  /// PrivateFunction: _dataRecv
  /// _Private_ handler to processes incoming data from the the connection.
  ///
  /// Except for _connect_cb handling the initial connection request,
  /// this function handles the incoming data for all requests.  This
  /// function also fires stanza handlers this match each incoming
  /// stanza.
  ///
  /// Parameters:
  ///   (Strophe.Request) req - The request this has data ready.
  ///   (string) req - The stanza a raw string (optiona).
  ///
  dataRecv(req, [String raw]) {
    this._dataRecv(req, raw);
  }

  _dataRecv(req, [String raw]) {
    Strophe.info("_dataRecv called");
    xml.XmlElement elem = this._proto.reqToData(req);
    if (elem == null) {
      return;
    }
    //if (this.xmlInput != Strophe.Connection.xmlInput) { // TODO: find out why some code is commented out
    if (elem.name.qualified == this._proto.strip && elem.children.length > 0) {
      this.xmlInput(elem.firstChild);
    } else {
      this.xmlInput(elem);
    }
    //}
    //if (this.rawInput != Strophe.Connection.rawInput) {
    if (raw != null) {
      this.rawInput(raw);
    } else {
      this.rawInput(Strophe.serialize(elem));
    }
    //}

    // remove handlers scheduled for deletion
    int i;
    StropheHandler hand;
    while (this.removeHandlers.length > 0) {
      hand = this.removeHandlers.removeLast();
      i = this.handlers.indexOf(hand);
      if (i >= 0) {
        this.handlers.removeAt(i);
      }
    }

    // add handlers scheduled for addition
    while (this.addHandlers.length > 0) {
      this.handlers.add(this.addHandlers.removeLast());
    }

    // handle graceful disconnect
    if (this.disconnecting && this._proto.emptyQueue()) {
      this._doDisconnect();
      return;
    }

    xml.XmlElement stanza;
    if (elem.name.qualified == this._proto.strip) {
      stanza = elem.firstChild as xml.XmlElement;
    } else {
      stanza = elem;
    }
    String type = stanza.getAttribute('type');
    if (type == null) {
      try {
        type = (elem.firstChild as xml.XmlElement).getAttribute('type');
      } catch (e) {}
    }
    String cond;
    Iterable<xml.XmlElement> conflict;
    if (type != null && type == "terminate") {
      // Don't process stanzas this come in after disconnect
      if (this.disconnecting) {
        return;
      }

      // an error occurred
      cond = elem.getAttribute('condition');
      conflict = elem.document.findAllElements("conflict");
      if (cond != null) {
        if (cond == "remote-stream-error" && conflict.length > 0) {
          cond = "conflict";
        }
        this._changeConnectStatus(Strophe.Status['CONNFAIL'], cond);
      } else {
        this._changeConnectStatus(Strophe.Status['CONNFAIL'],
            Strophe.ErrorCondition['UNKOWN_REASON']);
      }
      this._doDisconnect(cond);
      return;
    }

    // send each incoming stanza through the handler chain
    Strophe.forEachChild(elem, null, (child) {
      // process handlers
      List<StropheHandler> newList = this.handlers;
      this.handlers = [];
      for (int i = 0; i < newList.length; i++) {
        StropheHandler hand = newList.elementAt(i);
        // encapsulate 'handler.run' not to lose the whole handler list if
        // one of the handlers throws an exception
        try {
          if (hand.isMatch(child) && (this.authenticated || !hand.user)) {
            if (hand.run(child)) {
              this.handlers.add(hand);
            }
          } else {
            this.handlers.add(hand);
          }
        } catch (e) {
          // if the handler throws an exception, we consider it as false
          Strophe.warn('Removing Strophe handlers due to uncaught exception: ' +
              e.toString());
        }
      }
    });
  }

  /// Attribute: mechanisms
  /// SASL Mechanisms available for Connection.
  ///
  Map<String, StropheSASLMechanism> mechanisms = {};

  /// PrivateFunction: _connect_cb
  /// _Private_ handler for initial connection request.
  ///
  /// This handler is used to process the initial connection request
  /// response from the BOSH server. It is used to set up authentication
  /// handlers and start the authentication process.
  ///
  /// SASL authentication will be attempted if available, otherwise
  /// the code will fall back to legacy authentication.
  ///
  /// Parameters:
  ///   (Strophe.Request) req - The current request.
  ///   (Function) _callback - low level (xmpp) connect callback function.
  ///     Useful for plugins with their own xmpp connect callback (when they
  ///     want to do something special).
  ///
  set connectCb(ConnexionCallback param) {
    this._connectCb = param;
  }

  ConnexionCallback get connectCb {
    if (_reset == null) {
      initializeFunction();
    }
    return this._connectCb;
  }

  /// Function: sortMechanismsByPriority
  ///
  /// Sorts an array of objects with prototype SASLMechanism according to
  /// their priorities.
  ///
  /// Parameters:
  ///   (Array) mechanisms - Array of SASL mechanisms.
  ///
  List<StropheSASLMechanism> sortMechanismsByPriority(
      List<StropheSASLMechanism> mechanisms) {
    // Sorting mechanisms according to priority.
    int higher;
    StropheSASLMechanism swap;
    for (int i = 0; i < mechanisms.length - 1; ++i) {
      higher = i;
      for (int j = i + 1; j < mechanisms.length; ++j) {
        if (mechanisms[j].priority > mechanisms[higher].priority) {
          higher = j;
        }
      }
      if (higher != i) {
        swap = mechanisms[i];
        mechanisms[i] = mechanisms[higher];
        mechanisms[higher] = swap;
      }
    }
    return mechanisms;
  }

  /// PrivateFunction: _attemptSASLAuth
  ///
  /// Iterate through an array of SASL mechanisms and attempt authentication
  /// with the highest priority (enabled) mechanism.
  ///
  /// Parameters:
  ///   (Array) mechanisms - Array of SASL mechanisms.
  ///
  /// Returns:
  ///   (Boolean) mechanism_found - true or false, depending on whether a
  ///         valid SASL mechanism was found with which authentication could be
  ///         started.
  ///
  Future<bool> _attemptSASLAuth(List<StropheSASLMechanism> mechanisms) async {
    mechanisms = this.sortMechanismsByPriority(mechanisms ?? []);

    bool mechanismFound = false;
    for (int i = 0; i < mechanisms.length; ++i) {
      if (!mechanisms[i].test(this)) {
        continue;
      }
      this._saslSuccessHandler =
          this._addSysHandler(this._saslSuccessCb, null, "success", null, null);
      this._saslFailureHandler =
          this._addSysHandler(this._saslFailureCb, null, "failure", null, null);
      this._saslChallengeHandler = this
          ._addSysHandler(this._saslChallengeCb, null, "challenge", null, null);

      this._saslMechanism = mechanisms[i];
      this._saslMechanism.onStart(this);

      StropheBuilder requestAuthExchange = Strophe.$build("auth",
          {'xmlns': Strophe.NS['SASL'], 'mechanism': this._saslMechanism.name});
      if (this._saslMechanism.isClientFirst) {
        String response = await this._saslMechanism.onChallenge(this, null);
        requestAuthExchange.t(base64.encode(response.runes.toList()));
      }
      this.send(requestAuthExchange.tree());
      mechanismFound = true;
      break;
    }
    return mechanismFound;
  }

  /// PrivateFunction: _attemptLegacyAuth
  ///
  /// Attempt legacy (i.e. non-SASL) authentication.
  ///
  _attemptLegacyAuth() {
    if (Strophe.getNodeFromJid(this.jid) == null) {
      // we don't have a node, which is required for non-anonymous
      // client connections
      this._changeConnectStatus(Strophe.Status['CONNFAIL'],
          Strophe.ErrorCondition['MISSING_JID_NODE']);
      this.disconnect(Strophe.ErrorCondition[
          'MISSING_JID_NODE']); // TODO: convert all the ErrorCondition to enums
    } else {
      // Fall back to legacy authentication
      this._changeConnectStatus(Strophe.Status['AUTHENTICATING'], null);
      this._addSysHandler(this._auth1Cb, null, null, null, "_auth_1");
      this.send(
        Strophe.$iq({
          'type': "get",
          'to': this.domain,
          'id': "_auth_1",
        })
            .c("query", {'xmlns': Strophe.NS['AUTH']})
            .c("username", {})
            .t(Strophe.getNodeFromJid(this.jid))
            .tree(),
      );
    }
  }

  /// Function: authenticate
  /// Set up authentication
  ///
  /// Continues the initial connection request by setting up authentication
  /// handlers and starting the authentication process.
  ///
  /// SASL authentication will be attempted if available, otherwise
  /// the code will fall back to legacy authentication.
  ///
  /// Parameters:
  ///   (Array) matched - Array of SASL mechanisms supported.
  ///
  set authenticate(AuthenticateCallback callback) {
    this._authenticate = callback;
  }

  AuthenticateCallback get authenticate {
    if (_authenticate == null) {
      initializeFunction();
    }
    return this._authenticate;
  }

  /// PrivateFunction: _saslChallengeCb
  /// _Private_ handler for the SASL challenge
  /// authenticate
  ///
  Future<bool> _saslChallengeCb(elem) async {
    String challenge =
        new String.fromCharCodes(base64.decode(Strophe.getText(elem)));
    String response = await this._saslMechanism.onChallenge(this, challenge);
    StropheBuilder stanza = Strophe.$build('response', {
      'xmlns': Strophe.NS['SASL'],
    });
    if (response != "") {
      stanza.t(base64.encode(response.runes.toList()));
    }
    this.send(stanza.tree());
    return true;
  }

  /// PrivateFunction: _auth1Cb
  /// authenticate                                                                                                                                                                                                                                                                                    *  _Private_ handler for legacy authentication.
  ///
  /// This handler is called in response to the initial <iq type='get'/>
  /// for legacy authentication.  It builds an authentication <iq/> and
  /// sends it, creating a handler (calling back to _auth2Cb()) to
  /// handle the result
  ///
  /// Parameters:
  ///   (XMLElement) elem - The stanza this triggered the callback.
  ///
  /// Returns:
  ///   false to remove the handler.
  ///
  _auth1Cb(elem) {
    // build plaintext auth iq
    StropheBuilder iq = Strophe.$iq({'type': "set", 'id': "_auth_2"})
        .c('query', {'xmlns': Strophe.NS['AUTH']})
        .c('username', {})
        .t(Strophe.getNodeFromJid(this.jid))
        .up()
        .c('password')
        .t(this.pass);

    if (Strophe.getResourceFromJid(this.jid) == null ||
        Strophe.getResourceFromJid(this.jid).isEmpty) {
      // since the user has not supplied a resource, we pick
      // a default one here.  unlike other auth methods, the server
      // cannot do this for us.
      this.jid = Strophe.getBareJidFromJid(this.jid) + '/strophe';
    }
    iq.up().c('resource', {}).t(Strophe.getResourceFromJid(this.jid));

    this._addSysHandler(this._auth2Cb, null, null, null, "_auth_2");
    this.send(iq.tree());
    return false;
  }

  /// PrivateFunction: _saslSuccessCb
  /// _Private_ handler for succesful SASL authentication.
  ///
  /// Parameters:
  ///   (XMLElement) elem - The matching stanza.
  ///
  /// Returns:
  ///   false to remove the handler.
  ///
  bool _saslSuccessCb(elem) {
    String saslData = this._saslData["server-signature"];
    if (saslData != null && saslData.isNotEmpty) {
      String serverSignature;
      String success =
          new String.fromCharCodes(base64.decode(Strophe.getText(elem)));
      RegExp attribMatch = new RegExp(r"([a-z]+)=([^,]+)(,|$)");
      Match matches = attribMatch.firstMatch(success);
      if (matches.group(1) == "v") {
        serverSignature = matches.group(2);
      }
      if (serverSignature != saslData) {
        // remove old handlers
        this.deleteHandler(this._saslFailureHandler);
        this._saslFailureHandler = null;
        if (this._saslChallengeHandler != null) {
          this.deleteHandler(this._saslChallengeHandler);
          this._saslChallengeHandler = null;
        }

        this._saslData = {};
        return this._saslFailureCb(null);
      }
    }
    Strophe.info("SASL authentication succeeded.");

    if (this._saslMechanism != null) {
      this._saslMechanism.onSuccess();
    }

    // remove old handlers
    this.deleteHandler(this._saslFailureHandler);
    this._saslFailureHandler = null;
    if (this._saslChallengeHandler != null) {
      this.deleteHandler(this._saslChallengeHandler);
      this._saslChallengeHandler = null;
    }

    List<StropheHandler> streamFeatureHandlers = [];
    bool wrapper(List<StropheHandler> handlers, elem) {
      while (handlers.length > 0) {
        this.deleteHandler(handlers.removeLast());
      }
      this._saslAuth1Cb(elem);
      return false;
    }

    streamFeatureHandlers.add(this._addSysHandler((elem) {
      return wrapper(streamFeatureHandlers, elem);
    }, null, "stream:features", null, null));
    streamFeatureHandlers.add(this._addSysHandler((elem) {
      return wrapper(streamFeatureHandlers, elem);
    }, Strophe.NS['STREAM'], "features", null, null));

    // we must send an xmpp:restart now
    this._sendRestart();

    return false;
  }

  /// PrivateFunction: _saslAuth1Cb
  /// _Private_ handler to start stream binding.
  ///
  /// Parameters:
  ///   (XMLElement) elem - The matching stanza.
  ///
  /// Returns:
  ///   false to remove the handler.
  ///
  bool _saslAuth1Cb(element) {
    // save stream:features for future usage
    xml.XmlElement elem = element is xml.XmlDocument
        ? element.rootElement
        : (element as xml.XmlElement);
    this.features = elem;
    xml.XmlElement child;
    for (int i = 0; i < elem.children.length; i++) {
      child = elem.children.elementAt(i) as xml.XmlElement;
      if (child.name.qualified == 'bind') {
        this.doBind = true;
      }

      if (child.name.qualified == 'session') {
        this.doSession = true;
      }
    }
    if (!this.doBind) {
      this._changeConnectStatus(Strophe.Status['AUTHFAIL'], null);
      return false;
    } else {
      this._addSysHandler(this._saslBindCb, null, null, null, "_bind_auth_2");

      String resource = Strophe.getResourceFromJid(this.jid);
      if (resource != null && resource.isNotEmpty) {
        this.send(Strophe.$iq({'type': "set", 'id': "_bind_auth_2"})
            .c('bind', {"xmlns": Strophe.NS['BIND']})
            .c('resource', {})
            .t(resource)
            .tree());
      } else {
        this.send(Strophe.$iq({'type': "set", 'id': "_bind_auth_2"})
            .c('bind', {'xmlns': Strophe.NS['BIND']}).tree());
      }
    }
    return false;
  }

  /** PrivateFunction: _saslBindCb
   *  _Private_ handler for binding result and session start.
   *
   *  Parameters:
   *    (XMLElement) elem - The matching stanza.
   *
   *  Returns:
   *    false to remove the handler.
   */
  bool _saslBindCb(xml.XmlElement elem) {
    if (elem.getAttribute("type") == "error") {
      Strophe.info("SASL binding failed.");
      List<xml.XmlElement> conflict = elem.findAllElements("conflict");
      String condition;
      if (conflict.length > 0) {
        condition = Strophe.ErrorCondition['CONFLICT'];
      }
      this._changeConnectStatus(Strophe.Status['AUTHFAIL'], condition, elem);
      return false;
    }

    List<xml.XmlElement> bind = elem.findAllElements("bind").toList();
    List<xml.XmlElement> jidNode;
    if (bind.length > 0) {
      // Grab jid
      jidNode = bind[0].findAllElements("jid").toList();
      if (jidNode.length > 0) {
        this.jid = Strophe.getText(jidNode[0]);

        if (this.doSession) {
          this._addSysHandler(
              this._saslSessionCb, null, null, null, "_session_auth_2");
          this.send(Strophe.$iq({'type': "set", 'id': "_session_auth_2"})
              .c('session', {'xmlns': Strophe.NS['SESSION']}).tree());
        } else {
          this.authenticated = true;
          this._changeConnectStatus(Strophe.Status['CONNECTED'], null);
        }
      }
      return false;
    } else {
      Strophe.info("SASL binding failed.");
      this._changeConnectStatus(Strophe.Status['AUTHFAIL'], null, elem);
      return false;
    }
  }

  set connexionError(RawInputCallback callback) {
    this._connexionErrorInputCallback = callback;
  }

  RawInputCallback get connexionError {
    return this._connexionErrorInputCallback;
  }

  /// Sends an IQ immediately if connected or puts it on the send queue otherwise(in contrary to other send methods
  /// which would fail immediately if disconnected).
  /// @param {Element} iq - The IQ to send.
  /// @param {number} timeout - How long to wait for the response. The time when the connection is reconnecting is
  /// included, which means that the IQ may never be sent and still fail with a timeout.

  String sendIQ2(
    xml.XmlNode el, {
    Function(XmlElement stanza) onSuccess,
    Function(XmlElement stanza) onError,
    int timeout,
  }) {
    if (connected) {
      return sendIQ(
        el,
        onSuccess,
        onError,
        timeout,
      );
    } else {
      debugPrint('sendIQ2; not connected');
      return null; // todo: impl
    }
  }

  /** PrivateFunction: _no_auth_received
   *
   * Called on stream start/restart when no stream:features
   * has been received or when no viable authentication mechanism is offered.
   *
   * Sends a blank poll request.
   */
  Function get noAuthReceived {
    return _noAuthReceived;
  }

  _noAuthReceived([Function _callback]) {
    String errorMsg =
        "Server did not offer a supported authentication mechanism";
    Strophe.error(errorMsg);
    this._changeConnectStatus(
        Strophe.Status['CONNFAIL'], Strophe.ErrorCondition['NO_AUTH_MECH']);
    if (_callback != null) {
      _callback();
    }
    this._doDisconnect();
  }

  /** PrivateFunction: _saslSessionCb
   *  _Private_ handler to finish successful SASL connection.
   *
   *  This sets Connection.authenticated to true on success, which
   *  starts the processing of user handlers.
   *
   *  Parameters:
   *    (XMLElement) elem - The matching stanza.
   *
   *  Returns:
   *    false to remove the handler.
   */
  bool _saslSessionCb(xml.XmlElement elem) {
    if (elem.getAttribute("type") == "result") {
      this.authenticated = true;
      this._changeConnectStatus(Strophe.Status['CONNECTED'], null);
    } else if (elem.getAttribute("type") == "error") {
      Strophe.info("Session creation failed.");
      this._changeConnectStatus(Strophe.Status['AUTHFAIL'], null, elem);
      return false;
    }
    return false;
  }

  /** PrivateFunction: _saslFailureCb
   *  _Private_ handler for SASL authentication failure.
   *
   *  Parameters:
   *    (XMLElement) elem - The matching stanza.
   *
   *  Returns:
   *    false to remove the handler.
   */
  /* jshint unused:false */
  _saslFailureCb([xml.XmlElement elem]) {
    // delete unneeded handlers
    if (this._saslSuccessHandler != null) {
      this.deleteHandler(this._saslSuccessHandler);
      this._saslSuccessHandler = null;
    }
    if (this._saslChallengeHandler != null) {
      this.deleteHandler(this._saslChallengeHandler);
      this._saslChallengeHandler = null;
    }

    if (this._saslMechanism != null) this._saslMechanism.onFailure();
    this._changeConnectStatus(Strophe.Status['AUTHFAIL'], null, elem);
    return false;
  }

  /* jshint unused:true */

  /** PrivateFunction: _auth2Cb
   *  _Private_ handler to finish legacy authentication.
   *
   *  This handler is called when the result from the jabber:iq:auth
   *  <iq/> stanza is returned.
   *
   *  Parameters:
   *    (XMLElement) elem - The stanza this triggered the callback.
   *
   *  Returns:
   *    false to remove the handler.
   */
  bool _auth2Cb(xml.XmlElement elem) {
    if (elem.getAttribute("type") == "result") {
      this.authenticated = true;
      this._changeConnectStatus(Strophe.Status['CONNECTED'], null);
    } else if (elem.getAttribute("type") == "error") {
      this._changeConnectStatus(Strophe.Status['AUTHFAIL'], null, elem);
      this.disconnect('authentication failed');
    }
    return false;
  }

  /** PrivateFunction: _addSysTimedHandler
   *  _Private_ function to add a system level timed handler.
   *
   *  This function is used to add a Strophe.TimedHandler for the
   *  library code.  System timed handlers are allowed to run before
   *  authentication is complete.
   *
   *  Parameters:
   *    (Integer) period - The period of the handler.
   *    (Function) handler - The callback function.
   */
  StanzaTimedHandler _addSysTimedHandler(int period, Function handler) {
    StanzaTimedHandler thand = Strophe.TimedHandler(period, handler);
    thand.user = false;
    this.addTimeds.add(thand);
    return thand;
  }

  /** PrivateFunction: _addSysHandler
   *  _Private_ function to add a system level stanza handler.
   *
   *  This function is used to add a Strophe.Handler for the
   *  library code.  System stanza handlers are allowed to run before
   *  authentication is complete.
   *
   *  Parameters:
   *    (Function) handler - The callback function.
   *    (String) ns - The namespace to match.
   *    (String) name - The stanza name to match.
   *    (String) type - The stanza type attribute to match.
   *    (String) id - The stanza id attribute to match.
   */
  StanzaHandler addSysHandler(
      Function handler, String ns, String name, String type, String id) {
    return _addSysHandler(handler, ns, name, type, id);
  }

  StanzaHandler _addSysHandler(
      Function handler, String ns, String name, String type, String id) {
    StanzaHandler hand = Strophe.Handler(handler, ns, name, type, id);
    hand.user = false;
    this.addHandlers.add(hand);
    return hand;
  }

  /** PrivateFunction: _onDisconnectTimeout
   *  _Private_ timeout handler for handling non-graceful disconnection.
   *
   *  If the graceful disconnect process does not complete within the
   *  time allotted, this handler finishes the disconnect anyway.
   *
   *  Returns:
   *    false to remove the handler.
   */
  bool onDisconnectTimeout() {
    return _onDisconnectTimeout();
  }

  bool _onDisconnectTimeout() {
    this._changeConnectStatus(Strophe.Status['CONNTIMEOUT'], null);
    this._proto.onDisconnectTimeout();
    // actually disconnect
    this._doDisconnect();
    return false;
  }

  /** PrivateFunction: _onIdle
   *  _Private_ handler to process events during idle cycle.
   *
   *  This handler is called every 100ms to fire timed handlers this
   *  are ready and keep poll requests going.
   */
  onIdle() {
    this._onIdle();
  }

  _onIdle() {
    int i;
    int since;
    List<StanzaTimedHandler> newList;
    StanzaTimedHandler thand;
    // add timed handlers scheduled for addition
    // NOTE: we add before remove in the case a timed handler is
    // added and then deleted before the next _onIdle() call.
    while (this.addTimeds.length > 0) {
      this.timedHandlers.add(this.addTimeds.removeLast());
    }

    // remove timed handlers this have been scheduled for deletion
    while (this.removeTimeds.length > 0) {
      thand = this.removeTimeds.removeLast();
      i = this.timedHandlers.indexOf(thand);
      if (i >= 0) {
        this.timedHandlers.removeAt(i);
      }
    }

    // call ready timed handlers
    int now = new DateTime.now().millisecondsSinceEpoch;
    newList = [];
    for (i = 0; i < this.timedHandlers.length; i++) {
      thand = this.timedHandlers[i];
      if (this.authenticated || !thand.user) {
        since = thand.lastCalled + thand.period;
        if (since - now <= 0) {
          if (thand.run()) {
            newList.add(thand);
          }
        } else {
          newList.add(thand);
        }
      }
    }
    this.timedHandlers = newList;

    this._idleTimeout.cancel();

    this._proto.onIdle();
    // reactivate the timer only if connected
    if (this.connected) {
      // XXX: setTimeout should be called only with function expressions (23974bc1)
      this._idleTimeout = new Timer(new Duration(milliseconds: 100), () {
        this._onIdle();
      });
    }
  }
}
