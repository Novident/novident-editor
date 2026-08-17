import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

void main() {
  group('Transaction delta change capture', () {
    test('insertText captures start/end/shift', () {
      final doc = Document.blank(withInitialText: true);
      final node = doc.first!;
      final transaction = Transaction(document: doc);
      transaction.insertText(node, 0, 'hello');

      final changes = transaction.deltaChanges[node]!;
      expect(changes, hasLength(1));
      final change = changes.single;
      expect(change.start, 0);
      expect(change.end, 0);
      expect(change.shift, 5);
      expect(change.previousShift, 0);
      expect(change.order, greaterThanOrEqualTo(0));
    });

    test('deleteText captures the deleted range', () {
      final doc = Document.blank(withInitialText: true);
      final node = doc.first!;
      node.updateAttributes({'delta': (Delta()..insert('hello')).toJson()});
      final transaction = Transaction(document: doc);
      transaction.deleteText(node, 2, 3);

      final change = transaction.deltaChanges[node]!.single;
      expect(change.start, 2);
      expect(change.end, 5);
      expect(change.shift, -3);
    });

    test('formatText captures the formatted range with zero shift', () {
      final doc = Document.blank(withInitialText: true);
      final node = doc.first!;
      node.updateAttributes({'delta': (Delta()..insert('hello')).toJson()});
      final transaction = Transaction(document: doc);
      transaction.formatText(node, 1, 3, {RichTextKeys.bold: true});

      final change = transaction.deltaChanges[node]!.single;
      expect(change.start, 1);
      expect(change.end, 4);
      expect(change.shift, 0);
    });

    test('replaceText captures the replaced range and net shift', () {
      final doc = Document.blank(withInitialText: true);
      final node = doc.first!;
      node.updateAttributes({'delta': (Delta()..insert('hello')).toJson()});
      final transaction = Transaction(document: doc);
      transaction.replaceText(node, 1, 2, 'XYZ');

      final change = transaction.deltaChanges[node]!.single;
      expect(change.start, 1);
      expect(change.end, 3);
      expect(change.shift, 1); // +3 inserted − 2 deleted
    });

    test('batch: second change carries the accumulated previousShift', () {
      final doc = Document.blank(withInitialText: true);
      final node = doc.first!;
      // Seed the node so both insert indexes are valid against the current
      // delta (the node is only updated on apply, not on transaction build).
      node.updateAttributes({'delta': (Delta()..insert('ab')).toJson()});
      final transaction = Transaction(document: doc);
      transaction.insertText(node, 0, 'a');
      transaction.insertText(node, 1, 'b');

      final changes = transaction.deltaChanges[node]!;
      expect(changes, hasLength(2));
      expect(changes[0].start, 0);
      expect(changes[0].previousShift, 0);
      expect(changes[1].start, 1); // already shifted by the first insert
      expect(changes[1].previousShift, 1);
      expect(changes[1].order, changes[0].order + 1);
    });

    test('order is monotonic across transactions', () {
      final doc = Document.blank(withInitialText: true);
      final node = doc.first!;
      node.updateAttributes({'delta': (Delta()..insert('ab')).toJson()});
      final a = Transaction(document: doc)..insertText(node, 0, 'x');
      final b = Transaction(document: doc)..insertText(node, 1, 'y');

      final orderA = a.deltaChanges[node]!.single.order;
      final orderB = b.deltaChanges[node]!.single.order;
      expect(orderB, orderA + 1);
    });

    test('abandoned transactions do not leak into new ones', () {
      final doc = Document.blank(withInitialText: true);
      final node = doc.first!;
      // Build a transaction with pending changes but never apply it.
      Transaction(document: doc).insertText(node, 0, 'leak');

      final fresh = Transaction(document: doc);
      expect(fresh.deltaChanges, isEmpty);
      expect(fresh.operations, isEmpty);
    });
  });

  group('EditorState delta change emission', () {
    test('local apply emits the event after the delta is applied', () async {
      final state = EditorState.blank();
      final node = state.document.first!;
      final events = <DeltaChangeEvent>[];
      state.document.listenDeltaChanges(events.add);

      final transaction = state.transaction..insertText(node, 0, 'hola');
      await state.apply(transaction);

      expect(events, hasLength(1));
      expect(events.single.node, same(node));
      expect(events.single.changes, hasLength(1));
      expect(events.single.changes.single.start, 0);
      expect(events.single.changes.single.shift, 4);
      // Post-apply: the node already holds the final delta.
      expect(node.delta!.toPlainText(), 'hola');
      // The captured changes were consumed.
      expect(transaction.deltaChanges, isEmpty);
    });

    test('direct updateAttributes never emits', () async {
      final state = EditorState.blank();
      final node = state.document.first!;
      final events = <DeltaChangeEvent>[];
      state.document.listenDeltaChanges(events.add);

      node.updateAttributes({'align': 'center'});
      node.updateAttributes({'delta': (Delta()..insert('x')).toJson()});

      expect(events, isEmpty);
    });

    test('pure local UpdateTextOperation emits an empty change', () async {
      final state = EditorState.blank();
      final node = state.document.first!;
      final events = <DeltaChangeEvent>[];
      state.document.listenDeltaChanges(events.add);

      final transaction = state.transaction
        ..add(
          UpdateTextOperation(
            node.path,
            Delta()..insert('replaced'),
            Delta(),
          ),
        );
      await state.apply(transaction);

      expect(events, hasLength(1));
      expect(events.single.node, same(node));
      expect(events.single.changes, isEmpty);
      expect(node.delta!.toPlainText(), 'replaced');
    });

    test(
        'UpdateOperation with a delta change emits an empty change '
        '(undo/redo path)', () async {
      final state = EditorState.blank();
      final node = state.document.first!;
      node.updateAttributes({'delta': (Delta()..insert('viejo')).toJson()});
      final events = <DeltaChangeEvent>[];
      state.document.listenDeltaChanges(events.add);

      // Simulates the inverted operation an undo applies: a full delta
      // replacement through an UpdateOperation (no compose map involved).
      final transaction = state.transaction
        ..updateNode(node, {'delta': (Delta()..insert('nuevo')).toJson()});
      await state.apply(transaction);

      expect(events, hasLength(1));
      expect(events.single.node, same(node));
      expect(events.single.changes, isEmpty);
      expect(node.delta!.toPlainText(), 'nuevo');
    });

    test(
        'InsertOperation with delta nodes emits per-node empty changes '
        '(paste path)', () async {
      final state = EditorState.blank();
      final events = <DeltaChangeEvent>[];
      state.document.listenDeltaChanges(events.add);

      final inserted = paragraphNode(delta: Delta()..insert('hola wrld'));
      final transaction = state.transaction..insertNode(const [0], inserted);
      await state.apply(transaction);

      expect(events, hasLength(1));
      expect(events.single.node.delta!.toPlainText(), 'hola wrld');
      expect(events.single.changes, isEmpty);
    });

    test('remote UpdateTextOperation emits an empty change', () async {
      final state = EditorState.blank();
      final node = state.document.first!;
      final events = <DeltaChangeEvent>[];
      state.document.listenDeltaChanges(events.add);

      final transaction = Transaction(document: state.document)
        ..add(
          UpdateTextOperation(
            node.path,
            Delta()..insert('remote text'),
            Delta(),
          ),
        );
      await state.apply(transaction, isRemote: true);

      expect(events, hasLength(1));
      expect(events.single.changes, isEmpty);
      expect(node.delta!.toPlainText(), 'remote text');
    });

    test('a listener removing itself during emission is safe', () async {
      final state = EditorState.blank();
      final node = state.document.first!;
      final events = <DeltaChangeEvent>[];
      late void Function(DeltaChangeEvent) removable;
      removable = (event) {
        events.add(event);
        state.document.removeDeltaChangesListener(removable);
      };
      state.document.listenDeltaChanges(removable);

      final transaction = state.transaction..insertText(node, 0, 'x');
      await state.apply(transaction);

      expect(events, hasLength(1));
      // Second transaction: the listener is gone.
      final transaction2 = state.transaction..insertText(node, 1, 'y');
      await state.apply(transaction2);
      expect(events, hasLength(1));
    });
  });
}
