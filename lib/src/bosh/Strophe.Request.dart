import 'dart:convert';
import 'dart:html';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:strophe/src/core/core.dart';
import 'package:xml/xml.dart';

/// PrivateClass: Strophe.Request
/// _Private_ helper class that provides a cross implementation abstraction
/// for a BOSH related XMLHttpRequest.
///
/// The Strophe.Request class is used internally to encapsulate BOSH request
/// information.  It is not meant to be used from user's code.
///

/// PrivateConstructor: Strophe.Request
/// Create and initialize a new Strophe.Request object.
///
/// Parameters:
///   (XMLElement) elem - The XML data to be sent in the request.
///   (Function) func - The function that will be called when the
///     XMLHttpRequest readyState changes.
///   (Integer) rid - The BOSH rid attribute associated with this request.
///   (Integer) sends - The number of times this same request has been sent.
///
class StropheRequest {
  int id;

  XmlElement xmlData;

  String data;

  Function origFunc;

  Function func;

  num date;

  String rid;

  int sends;

  bool abort;

  int dead;

  http.Client xhr;
  http.Response response;

  StropheRequest(XmlElement elem, Function func, String rid, [int sends]) {
    this.id = ++Strophe.requestId;
    this.xmlData = elem;
    this.data = Strophe.serialize(elem);
    // save original function in case we need to make a new request
    // from this one.
    this.origFunc = func;
    this.func = func;
    this.rid = rid;
    this.date = null;
    this.sends = sends ?? 0;
    this.abort = false;
    this.dead = null;

    this.xhr = this._newXHR();
  }

  num age() {
    if (this.date == null || this.date == 0) {
      return 0;
    }
    int now = DateTime.now().millisecondsSinceEpoch;
    return (now - this.date) / 1000;
  }

  num timeDead() {
    if (this.dead == null) {
      return 0;
    }
    int now = DateTime.now().millisecondsSinceEpoch;
    return (now - this.dead) / 1000;
  }

  /// PrivateFunction: getResponse
  /// Get a response from the underlying XMLHttpRequest.
  ///
  /// This function attempts to get a response from the request and checks
  /// for errors.
  ///
  /// Throws:
  ///   "parsererror" - A parser error occured.
  ///   "badformat" - The entity has sent XML that cannot be processed.
  ///
  /// Returns:
  ///   The DOM element tree of the response.
  ///
  XmlElement getResponse() {
    String body = response.body;
    XmlElement node;
    try {
      node = XmlDocument.parse(body).rootElement;
      if (node == null) {
        throw {'message': 'Parsing produced null node'};
      }
    } catch (e) {
      // if (node.name == "parsererror") {
      Strophe.error("invalid response received" + e.toString());
      Strophe.error("responseText: " + body);
      Strophe.error("responseXML: " + Strophe.serialize(node));
      throw "parsererror";
      //}
    }
    return node;
  }

  /// PrivateFunction: _newXHR
  /// _Private_ helper function to create XMLHttpRequests.
  ///
  /// This function creates XMLHttpRequests across all implementations.
  ///
  /// Returns:
  ///   A new XMLHttpRequest.
  ///
  http.Client _newXHR() {
    return http.Client();
  }
}

/// This is to match only the XMLHttpRequest.readyState that are used in JS code
/// https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest/readyState
enum ReadyState {
  unsent,
  sent, // In theory this corrisponds to HEADERS_RECEIVED state
  done,
}

// class StropheHttpClient extends http.BaseClient {
//   ReadyState readyState = ReadyState.unsent;

//   @override
//   Future<http.StreamedResponse> send(http.BaseRequest request) {
//     super.send(request);
//   }
// }
