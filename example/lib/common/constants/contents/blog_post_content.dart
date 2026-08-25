import 'package:novident_editor/novident_editor.dart';

/// Content for `Novident Showcase ▸ How we built a rich-text editor`.
///
/// A faithful reproduction of the AppFlowy blog post "How we built a highly
/// customizable rich-text editor for Flutter" (Dec 2022, by Lucas). It is a
/// realistic long-form article that naturally exercises headings, paragraphs,
/// inline styles, links, lists, quotes and code-formatted examples.
final Document blogPostDocument = Document(
  root: pageNode(
    children: <Node>[
      headingNode(
        level: 1,
        text: 'How we built a highly customizable rich-text editor for Flutter',
      ),
      paragraphNode(
        delta: Delta()
          ..insert('By ')
          ..insert('Lucas', attributes: <String, dynamic>{RichTextKeys.bold: true})
          ..insert(' @ AppFlowy · Dec 12, 2022 · 18 min read'),
      ),
      paragraphNode(
        text: 'We have been looking for a rich-text editor that meets our '
            'needs. To date, we still haven\'t found a solution, so we '
            'decided to design and develop the new AppFlowy Editor component '
            'ourselves.',
      ),
      paragraphNode(
        delta: Delta()
          ..insert('This article describes the technical design of the ')
          ..insert(
            'AppFlowy Editor',
            attributes: <String, dynamic>{
              RichTextKeys.href: 'https://pub.dev/packages/appflowy_editor',
            },
          )
          ..insert('. AppFlowy is an open-source alternative to Notion built '
              'with Rust and Flutter.'),
      ),
      paragraphNode(
        text: 'An editor is a core component in AppFlowy. In many scenarios, '
            'such as Document, Grid, and Board, the editor component we used '
            'till v0.0.5 is unable to support certain business requirements.',
      ),
      paragraphNode(
        text: 'We have therefore been seeking an editor that will support all '
            'of AppFlowy\'s use cases and we have concluded that we need to '
            'design and develop our own editor for AppFlowy which we will '
            'call the AppFlowy Editor.',
      ),
      quoteNode(
        delta: Delta()
          ..insert(
            'Before diving into our own editor, we would like to give a '
            'special thanks to flutter_quill, its author, and the community. '
            'Without you, we wouldn\'t have made it this far.',
          ),
      ),
      headingNode(level: 2, text: 'Issues with the Editor Component'),
      paragraphNode(
        text: 'As mentioned earlier, in the early versions (v0.0.1 to v0.0.5) '
            'of AppFlowy, we used flutter_quill as our editor component. In '
            'the process of using this library, we have encountered problems '
            'with extensibility, consistency, and code coverage.',
      ),
      headingNode(level: 3, text: 'Issues with Extensibility'),
      paragraphNode(
        text: 'We have encountered difficulty with quickly extending new '
            'components (aka plug-ins) and shortcuts. When it comes to '
            'components, an example issue is our requirement to insert Grid '
            'and Board into existing documents. We only need to define a new '
            'node with a new type and define a corresponding NodeWidgetBuilder '
            'to render these components in the AppFlowy Editor.',
      ),
      headingNode(level: 3, text: 'Issues with Self-Consistent Production Process'),
      paragraphNode(
        text: 'We have been unable to support self-consistent context '
            'production processes, such as inserting new components via the '
            'slash command or a floating toolbar. The new AppFlowy Editor '
            'supports customizing toolbar items and slash menus.',
      ),
      headingNode(level: 3, text: 'Issues with Code Coverage and Stability'),
      paragraphNode(
        text: 'The previous editor component lacked stability and sufficient '
            'code coverage. To date, the code coverage of the AppFlowy Editor '
            'is stable at 79 to 80%. Meanwhile, we try to make sure to fix '
            'known issues and add new test cases to cover them.',
      ),
      headingNode(level: 2, text: 'Replacement Approach'),
      paragraphNode(
        text: 'We have been actively looking for alternatives in the '
            'open-source community, such as super_editor. During our research, '
            'we found that super_editor allows for extending new components in '
            'a way that can also support customized shortcuts.',
      ),
      paragraphNode(
        text: 'However, the underlying data structure of super_editor is a '
            'list that does not support nesting. We feel this data structure '
            'is not appropriate for nodes with parent-child relationships. For '
            'example, in the case of multi-level lists, the form of each level '
            'is inconsistent.',
      ),
      paragraphNode(
        text: 'To date, we still haven\'t found a solution that suits our '
            'needs. For the above reasons, we have decided to design and '
            'develop the new AppFlowy Editor component ourselves.',
      ),
      headingNode(level: 2, text: 'Solution Overview'),
      paragraphNode(
        text: 'Before starting a new editor project, we\'ll examine some '
            'existing editor implementations. There are not many editor '
            'projects based on Flutter, so we\'ll refer to well-known '
            'front-end editor implementations, such as Quill.js and Slate.js.',
      ),
      paragraphNode(
        delta: Delta()
          ..insert('We believe that the foundation of the editor lies in ')
          ..insert(
            'the design of the data structure',
            attributes: <String, dynamic>{RichTextKeys.bold: true},
          )
          ..insert('.'),
      ),
      paragraphNode(
        text: 'Quill.js uses Delta as the data structure, while Slate.js uses '
            'tree nodes as the data structure. Ultimately we have elected to '
            'use a tree node like Slate.js to assemble the documents while '
            'continuing to use Delta for the data storage of text nodes.',
      ),
      headingNode(level: 3, text: 'Why Use a Combination of Node Tree and Delta?'),
      paragraphNode(text: 'Why do we use a node tree?'),
      bulletedListNode(
        text: 'The entirety of the document data is described using a single '
            'Delta data which does not allow us to easily describe complex '
            'nested scenarios.',
      ),
      bulletedListNode(
        text: 'When there is an issue with a paragraph or document, restoring '
            'the document becomes relatively difficult.',
      ),
      paragraphNode(text: 'Why do we still use Delta for the text node?'),
      bulletedListNode(
        text: 'If text with different styles continues to be split into '
            'different nodes, it will increase the complexity of the tree '
            'node structure.',
      ),
      bulletedListNode(
        text: 'The ability to export a text change delta is already supported '
            'in Flutter, so it is easy to substitute the Flutter text change '
            'delta to Delta.',
      ),
      bulletedListNode(
        text: 'Considering that our previous version is using flutter-quill as '
            'the editor component, it is simpler to keep Delta for text nodes '
            'in doing a data migration.',
      ),
      headingNode(level: 2, text: 'Detailed Design for AppFlowy Editor'),
      paragraphNode(
        text: 'We will state the design of AppFlowy Editor through the '
            'following three aspects.',
      ),
      numberedListNode(
        delta: Delta()
          ..insert('What is the data made of? (keywords: Node, Delta, Document)'),
      ),
      numberedListNode(
        delta: Delta()
          ..insert('How to update the data? (keywords: Position, Path, Operation, Transaction, EditorState, Apply)'),
      ),
      numberedListNode(
        delta: Delta()
          ..insert('How to render widgets through the data? (keywords: Render Plugins)'),
      ),
      headingNode(level: 3, text: 'Editor Data Structure'),
      paragraphNode(
        text: 'AppFlowy Editor treats a document as a collection of nodes. '
            'For example, a paragraph is a TextNode and an image is an '
            'ImageNode. We use LinkedList to organize the relationship between '
            'nodes, which provides a relatively efficient way to insert and '
            'delete nodes.',
      ),
      paragraphNode(text: 'A node must contain the fields listed below.'),
      bulletedListNode(
        delta: Delta()
          ..insert('The ')
          ..insert('Type', attributes: <String, dynamic>{RichTextKeys.bold: true})
          ..insert(' field is used to find the renderer and control how to '
              'serialize and deserialize the current node.'),
      ),
      bulletedListNode(
        delta: Delta()
          ..insert('The ')
          ..insert('Attributes', attributes: <String, dynamic>{RichTextKeys.bold: true})
          ..insert(' field indicates what data should be presented and '
              'synced. An ImageNode, for example, uses the image_src in its '
              'attributes to describe the link where to load the image.'),
      ),
      bulletedListNode(
        delta: Delta()
          ..insert('The ')
          ..insert('Children', attributes: <String, dynamic>{RichTextKeys.bold: true})
          ..insert(' field indicates the children nodes, such as the embedded '
              'bulleted list or the block in the table component.'),
      ),
      headingNode(level: 3, text: 'Example Node Definitions'),
      paragraphNode(text: 'Below is the definition of a Node in Dart:'),
      paragraphNode(
        delta: Delta()
          ..insert('class Node extends ChangeNotifier with LinkedListEntry<Node> { ... }'),
        attributes: <String, dynamic>{RichTextKeys.code: true},
      ),
      paragraphNode(text: 'And the JSON representation of an ImageNode:'),
      paragraphNode(
        delta: Delta()
          ..insert('{ "type": "image", "attributes": { "image_src": "https://i.ibb.co/WKQwVDn/Xnip2022-09-02-15-49-51.jpg", "align": "left", "width": 285 } }'),
        attributes: <String, dynamic>{RichTextKeys.code: true},
      ),
      headingNode(level: 3, text: 'Updating Data in the Editor'),
      paragraphNode(
        text: 'Before we update the data, we must know which part of the data '
            'needs to be updated. In other words, we need to locate the '
            'position of a node.',
      ),
      paragraphNode(text: 'Nodes may be located in a variety of manners:'),
      bulletedListNode(
        delta: Delta()
          ..insert('Path', attributes: <String, dynamic>{RichTextKeys.bold: true})
          ..insert(' — an integer array consisting of a node\'s position in '
              'its ancestor\'s node and the position of its ancestors. All '
              'data change operations are performed based on the Path.'),
      ),
      bulletedListNode(
        delta: Delta()
          ..insert('Position', attributes: <String, dynamic>{RichTextKeys.bold: true})
          ..insert(' — locates the offset of a node. It consists of a path '
              'and an offset, and is usually used for text editing and cursor '
              'locating.'),
      ),
      bulletedListNode(
        delta: Delta()
          ..insert('Selection', attributes: <String, dynamic>{RichTextKeys.bold: true})
          ..insert(' — represents the range of the selection. The cursor is '
              'also a special kind of selection, except that start and end '
              'coincide.'),
      ),
      headingNode(level: 3, text: 'Operation Types'),
      paragraphNode(
        text: 'AppFlowy Editor uses Operation objects to manipulate the '
            'document data instead of changing the node data directly. All '
            'changes to the document are triggered by an Operation.',
      ),
      paragraphNode(text: 'The operations defined in AppFlowy Editor include:'),
      bulletedListNode(
        delta: Delta()
          ..insert('Insert', attributes: <String, dynamic>{RichTextKeys.bold: true})
          ..insert(' — inserting a list of nodes into the document at a given '
              'path. Its reverse operation is Delete.'),
      ),
      bulletedListNode(
        delta: Delta()
          ..insert('Delete', attributes: <String, dynamic>{RichTextKeys.bold: true})
          ..insert(' — deleting a list of nodes at a given path. Its reverse '
              'operation is Insert.'),
      ),
      bulletedListNode(
        delta: Delta()
          ..insert('Update', attributes: <String, dynamic>{RichTextKeys.bold: true})
          ..insert(' — updating a node\'s attributes at the given path. Its '
              'reverse operation is itself.'),
      ),
      bulletedListNode(
        delta: Delta()
          ..insert('UpdateText', attributes: <String, dynamic>{RichTextKeys.bold: true})
          ..insert(' — updating the text delta in the text node, which is '
              'consistent with the Delta logic.'),
      ),
      headingNode(level: 3, text: 'Transactions'),
      paragraphNode(
        text: 'The AppFlowy Editor uses a Transaction to describe a set of '
            'changes to the document which must be treated as atomic. It '
            'consists of a collection of Operations and changes to the '
            'selection before and after.',
      ),
      paragraphNode(
        text: 'The purpose of using a transaction is to apply a collection of '
            'sequential operations that cannot be split apart. For example, '
            'pressing the enter key in front of "AppFlowy!" will actually '
            'produce two consecutive operations: insert a new TextNode at '
            'path [1], and delete "AppFlowy!" at path [0].',
      ),
      headingNode(level: 3, text: 'EditorState and Apply'),
      paragraphNode(
        text: 'EditorState is responsible for managing the state of the '
            'document. It holds the Document, and updates the document data '
            'through the apply function given a Transaction.',
      ),
      paragraphNode(text: 'To summarize how data changes:'),
      numberedListNode(
        delta: Delta()
          ..insert('EditorState holds the Document, and Document is a '
              'collection of Node objects.'),
      ),
      numberedListNode(
        delta: Delta()
          ..insert('The end-user manipulates a Node to generate a Selection '
              'and Operations, which forms a Transaction.'),
      ),
      numberedListNode(
        delta: Delta()
          ..insert('Apply the Transaction to EditorState to refresh the '
              'Document.'),
      ),
      headingNode(level: 3, text: 'Rendering Widgets Using the Data'),
      paragraphNode(
        text: 'NodeWidgetBuilder is an abstract protocol, responsible for '
            'converting a Node to a Widget. Each node owns its corresponding '
            'NodeWidgetBuilder.',
      ),
      paragraphNode(
        text: 'When AppFlowy Editor starts to render the Nodes, it will first '
            'recursively traverse the Document. For each Node it encounters, '
            'the editor will find the corresponding NodeWidgetBuilder from the '
            'mapping relationship according to the node\'s type and then call '
            'the build function to generate a Widget.',
      ),
      dividerNode(),
      paragraphNode(
        text: 'Thanks for reading this article. If you build something with '
            'the editor, we would love to hear about it.',
      ),
    ],
  ),
);