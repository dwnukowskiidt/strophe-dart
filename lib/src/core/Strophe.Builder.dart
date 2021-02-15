import 'package:strophe/src/core/core.dart';
import 'package:xml/xml.dart' as xml;
import 'package:xml/xml.dart';

/// Class: Strophe.Builder
///  XML DOM builder.
///
///  This object provides an interface similar to JQuery but for building
///  DOM elements easily and rapidly.  All the functions except for toString()
///  and tree() return the object, so calls can be chained.  Here's an
///  example using the $iq() builder helper.
///  > $iq({to: 'you', from: 'me', type: 'get', id: '1'})
///  >     .c('query', {xmlns: 'strophe:example'})
///  >     .c('example')
///  >     .toString()
///
///  The above generates this XML fragment
///  > <iq to='you' from='me' type='get' id='1'>
///  >   <query xmlns='strophe:example'>
///  >     <example/>
///  >   </query>
///  > </iq>
///  The corresponding DOM manipulations to get a similar fragment would be
///  a lot more tedious and probably involve several helper variables.
///
///  Since adding children makes new operations operate on the child, up()
///  is provided to traverse up the tree.  To add two children, do
///  > builder.c('child1', ...).up().c('child2', ...)
///  The next operation on the Builder will be relative to the second child.
class StropheBuilder {
  List<int> node = [];
  xml.XmlNode nodeTree;

  /// Constructor: Strophe.Builder
  ///  Create a Strophe.Builder object.
  ///
  ///  The attributes should be passed in object notation.  For example
  ///  > var b = new Builder('message', {to: 'you', from: 'me'});
  ///  or
  ///  > var b = new Builder('messsage', {'xml:lang': 'en'});
  ///
  ///  Parameters:
  ///    (String) name - The name of the root element.
  ///    (Object) attrs - The attributes for the root element in object notation.
  ///
  ///  Returns:
  ///    A new Strophe.Builder.
  StropheBuilder(String name, [Map<String, dynamic> attrs]) {
    // Set correct namespace for jabber:client elements
    if (name == "presence" || name == "message" || name == "iq") {
      if (attrs != null && attrs['xmlns'] == null) {
        attrs['xmlns'] = Strophe.NS['CLIENT'];
      } else if (attrs == null) {
        attrs = {'xmlns': Strophe.NS['CLIENT']};
      }
    }

    // Holds the tree being built.
    this.nodeTree = Strophe.xmlElement(name, attrs: attrs);

    // Points to the current operation node.
    this.node = [0];
  }

  /// Function: tree
  /// Return the DOM tree.
  ///
  /// This function returns the current DOM tree as an element object.  This
  /// is suitable for passing to functions like Strophe.Connection.send().
  ///
  /// Returns:
  /// The DOM tree as a element object.
  xml.XmlElement tree() {
    if (this.nodeTree is xml.XmlDocument) {
      xml.XmlDocument doc = this.nodeTree as xml.XmlDocument;
      return doc.rootElement;
    }
    return this.nodeTree;
  }

  /// Function: toString
  ///  Serialize the DOM tree to a String.
  ///
  ///  This function returns a string serialization of the current DOM
  ///  tree.  It is often used internally to pass data to a
  ///  Strophe.Request object.
  ///
  ///  Returns:
  ///    The serialized DOM tree in a String.
  ///
  String toString() {
    return Strophe.serialize(this.nodeTree);
  }

  /// Function: up
  /// Make the current parent element the new current element.
  ///
  /// This function is often used after c() to traverse back up the tree.
  /// For example, to add two children to the same element
  /// > builder.c('child1', {}).up().c('child2', {});
  ///
  /// Returns:
  /// The Stophe.Builder object.
  StropheBuilder up() {
    if (this.node.length > 0) this.node.removeLast();
    return this;
  }

  /// Function: root
  /// Make the root element the new current element.
  ///
  /// When at a deeply nested element in the tree, this function can be used
  /// to jump back to the root of the tree, instead of having to repeatedly
  /// call up().
  ///
  /// Returns:
  /// The Stophe.Builder object.
  StropheBuilder root() {
    this.node = [];
    this.nodeTree = this.nodeTree.root;
    return this;
  }

  /// Function: attrs
  /// Add or modify attributes of the current element.
  ///
  /// The attributes should be passed in object notation.  This function
  /// does not move the current element pointer.
  ///
  /// Parameters:
  /// (Object) moreattrs - The attributes to add/modify in object notation.
  ///
  /// Returns:
  /// The Strophe.Builder object.
  StropheBuilder attrs(Map<String, dynamic> moreattrs) {
    moreattrs.forEach((String key, dynamic value) {
      if (value == null || value.isEmpty) {
        this
            .nodeTree
            .firstChild
            .attributes
            .removeWhere((xml.XmlAttribute attr) {
          return attr.name.qualified == key;
        });
      } else {
        this
            .nodeTree
            .firstChild
            .attributes
            .add(xml.XmlAttribute(xml.XmlName.fromString(key), value));
      }
    });
    return this;
  }

  /// Function: c
  /// Add a child to the current element and make it the new current
  /// element.
  ///
  /// This function moves the current element pointer to the child,
  /// unless text is provided.  If you need to add another child, it
  /// is necessary to use up() to go back to the parent in the tree.
  ///
  /// Parameters:
  /// (String) name - The name of the child.
  /// (Object) attrs - The attributes of the child in object notation.
  /// (String) text - The text to add to the child.
  ///
  /// Returns:
  /// The Strophe.Builder object.
  StropheBuilder c(String name, [Map<String, dynamic> attrs, dynamic text]) {
    xml.XmlNode child = Strophe.xmlElement(name, attrs: attrs, text: text);
    xml.XmlElement xmlElement = child is xml.XmlDocument
        ? child.rootElement
        : (child as xml.XmlElement);

    xml.XmlNode currentNode = this.nodeTree.children[0];
    for (int i = 1; i < this.node.length; i++) {
      currentNode = currentNode.children[this.node[i]];
    }
    currentNode.children.add(Strophe.copyElement(xmlElement));
    this.node.add(currentNode.children.length - 1);
    return this;
  }

  /// Function: cnode
  /// Add a child to the current element and make it the new current
  /// element.
  ///
  /// This function is the same as c() except this instead of using a
  /// name and an attributes object to create the child it uses an
  /// existing DOM element object.
  ///
  /// Parameters:
  /// (XMLElement) elem - A DOM element.
  ///
  /// Returns:
  /// The Strophe.Builder object.
  StropheBuilder cnode(xml.XmlNode elem) {
    xml.XmlNode newElem = Strophe.copyElement(elem);
    xml.XmlNode currentNode = this.nodeTree.children[0];
    for (int i = 1; i < this.node.length; i++) {
      currentNode = currentNode.children[this.node[i]];
    }
    if (newElem != null) currentNode.children.add(Strophe.copyElement(newElem));
    this.node.add(currentNode.children.length - 1);
    return this;
  }

  /// Function: t
  /// Add a child text element.
  ///
  /// This *does not* make the child the new current element since there
  /// are no children of text elements.
  ///
  /// Parameters:
  /// (String) text - The text data to append to the current element.
  ///
  /// Returns:
  /// The Strophe.Builder object.
  StropheBuilder t(String text) {
    xml.XmlNode currentNode = this.nodeTree.children[0];
    for (int i = 1; i < this.node.length; i++) {
      currentNode = currentNode.children[this.node[i]];
    }
    currentNode.children.add(Strophe.copyElement(xml.XmlText(text ?? '')));
    return this;
  }

  /// Function: h
  /// Replace current element contents with the HTML passed in.
  ///
  /// This *does not* make the child the new current element
  ///
  /// Parameters:
  /// (String) html - The html to insert as contents of current element.
  ///
  /// Returns:
  /// The Strophe.Builder object.
  StropheBuilder h(String html) {
    xml.XmlNode fragment = Strophe.xmlElement('body');

    // force the browser to try and fix any invalid HTML tags
    fragment.children.add(Strophe.xmlTextNode(html));

    // copy cleaned html into an xml dom
    xml.XmlNode xhtml = Strophe.createHtml(fragment);
    xml.XmlNode currentNode = this.nodeTree.children[0];
    for (int i = 1; i < this.node.length; i++) {
      currentNode = currentNode.children[this.node[i]];
    }
    currentNode.children.add(Strophe.copyElement(xhtml));
    return this;
  }

  ///
  /// Extra methods (not included in Strophe js)
  ///

  xml.XmlElement get currentNode {
    xml.XmlNode _currentNode = this.nodeTree.children[0];
    for (int i = 1; i < this.node.length; i++) {
      _currentNode = _currentNode.children[this.node[i]];
    }
    return _currentNode is xml.XmlDocument
        ? _currentNode.rootElement
        : _currentNode as xml.XmlElement;
  }
}
