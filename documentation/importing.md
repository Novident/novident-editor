# Importing data

Currently, we have supported three methods for importing data to initialize Novident Editor.

1. From Novident Document JSON

```dart
const document = r'''{
  "document": {
    "type": "page",
    "children": [
      {
        "type": "heading",
        "data": {
            "delta": [{ "insert": "Hello Novident!" }],
            "level": 1
        }
      }
    ]
  }
}''';
final json = Map<String, Object>.from(jsonDecode(document));
final editorState = EditorState(
  document: Document.fromJson(json),
);
```

2. From Markdown

```dart
const markdown = r'''# Hello Novident!''';
final editorState = EditorState(
  document: markdownToDocument(markdown),
);
```

3. From Quill Delta

See the examples in [Novident Quill Parser](https://pub.dev/packages/novident_editor_quill_parser)
