import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ycp_store/l10n/generated/app_localizations.dart';
import 'package:ycp_store/src/core/field_validation.dart';
import 'package:ycp_store/src/data/models.dart';
import 'package:ycp_store/src/ui/widgets/field_help_dialog.dart';
import 'package:ycp_store/src/ui/widgets/required_fields_form.dart';

const _gameId = RequiredField(
  key: 'userid',
  labelKm: 'លេខ ID ហ្គេម',
  labelEn: 'Game ID',
  placeholder: '123456789',
  pattern: r'^[0-9]{6,12}$',
);

const _server = RequiredField(
  key: 'serverid',
  labelKm: 'Server',
  labelEn: 'Server',
  placeholder: '2001',
  pattern: r'^[0-9]{3,6}$',
);

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppL10n.supportedLocales,
  localizationsDelegates: AppL10n.localizationsDelegates,
  home: Scaffold(body: child),
);

Future<void> _pumpAt320(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320 * 3, 640 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap(SingleChildScrollView(child: child)));
  await tester.pumpAndSettle();
}

void main() {
  group('fieldProblem mirrors the server gate', () {
    test('a missing value is empty, not a format problem', () {
      expect(fieldProblem(_gameId, ''), FieldProblem.empty);
      expect(fieldProblem(_gameId, '   '), FieldProblem.empty);
    });

    test('a value that matches the pattern passes', () {
      expect(fieldProblem(_gameId, '262856740'), isNull);
      expect(fieldProblem(_gameId, '  262856740  '), isNull);
    });

    test('a value outside the pattern is a format problem', () {
      // The value that used to be accepted by create_order and then refunded.
      expect(fieldProblem(_gameId, 'abc'), FieldProblem.format);
      expect(fieldProblem(_gameId, '12345'), FieldProblem.format);
      expect(fieldProblem(_gameId, '1234567890123'), FieldProblem.format);
      expect(fieldProblem(_server, '20'), FieldProblem.format);
    });

    test(
      'a value longer than the server accepts is refused before sending',
      () {
        // Checked on the value itself, so it holds for a field with no pattern
        // too: the server caps length for exactly the same reason.
        const bare = RequiredField(
          key: 'userid',
          labelKm: 'x',
          labelEn: 'Game ID',
        );
        expect(fieldProblem(bare, '9' * 64), isNull);
        expect(fieldProblem(bare, '9' * 65), FieldProblem.format);
      },
    );

    test('a field with no pattern only needs a value', () {
      const bare = RequiredField(
        key: 'userid',
        labelKm: 'x',
        labelEn: 'Game ID',
      );
      expect(fieldProblem(bare, 'anything at all'), isNull);
      expect(fieldProblem(bare, ''), FieldProblem.empty);
    });
  });

  group('a pattern in the catalogue is data, so it can be wrong', () {
    test('an unparseable pattern is treated as no pattern', () {
      // `RegExp('([unclosed')` throws. Throwing here would take the page down
      // for every buyer of that product.
      expect(compileFieldPattern('([unclosed'), isNull);
      expect(
        fieldProblem(
          const RequiredField(
            key: 'userid',
            labelKm: 'x',
            labelEn: 'Game ID',
            pattern: '([unclosed',
          ),
          'anything',
        ),
        isNull,
      );
    });

    test('an absent or blank pattern is no pattern', () {
      expect(compileFieldPattern(null), isNull);
      expect(compileFieldPattern(''), isNull);
      expect(compileFieldPattern('   '), isNull);
    });
  });

  group('keyboard and formatter follow the pattern', () {
    test('a digits-only pattern gets a number pad', () {
      expect(fieldWantsDigits(_gameId), isTrue);
      expect(fieldWantsDigits(_server), isTrue);
      expect(
        fieldWantsDigits(
          const RequiredField(
            key: 'k',
            labelKm: 'x',
            labelEn: 'y',
            pattern: r'^[0-9]+$',
          ),
        ),
        isTrue,
      );
      expect(fieldKeyboardType(_gameId), TextInputType.number);
    });

    test('a pattern that allows letters does not get one', () {
      // A digits-only keyboard on an alphanumeric field makes a valid answer
      // impossible to type.
      const mixed = RequiredField(
        key: 'k',
        labelKm: 'x',
        labelEn: 'y',
        pattern: r'^[a-zA-Z0-9]+$',
      );
      expect(fieldWantsDigits(mixed), isFalse);
      expect(fieldKeyboardType(mixed), TextInputType.text);
      expect(
        fieldInputFormatters(mixed).whereType<FilteringTextInputFormatter>(),
        isEmpty,
      );
    });

    test('every field is length-capped, digits or not', () {
      expect(
        fieldInputFormatters(
          _gameId,
        ).whereType<LengthLimitingTextInputFormatter>(),
        isNotEmpty,
      );
      expect(
        fieldInputFormatters(
          const RequiredField(key: 'k', labelKm: 'x', labelEn: 'y'),
        ).whereType<LengthLimitingTextInputFormatter>(),
        isNotEmpty,
      );
    });
  });

  group('field help', () {
    testWidgets('the catalogue\'s own help wins, and the example is shown', (
      tester,
    ) async {
      const field = RequiredField(
        key: 'userid',
        labelKm: 'x',
        labelEn: 'Game ID',
        placeholder: '123456789',
        helpEn: 'Open Profile and tap Copy beside your name.',
      );

      await tester.pumpWidget(_wrap(const FieldHelpDialog(field: field)));
      await tester.pumpAndSettle();

      expect(
        find.text('Open Profile and tap Copy beside your name.'),
        findsOneWidget,
      );
      expect(find.text('Example'), findsOneWidget);
      expect(find.text('123456789'), findsOneWidget);
    });

    testWidgets('a known field key gets the instructions for it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const FieldHelpDialog(
            field: RequiredField(
              key: 'userid',
              labelKm: 'x',
              labelEn: 'Game ID',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('profile or avatar'), findsOneWidget);
    });

    testWidgets('the zone field gets the zone answer, not the id one', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const FieldHelpDialog(
            field: RequiredField(
              key: 'serverid',
              labelKm: 'x',
              labelEn: 'Server',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('in brackets'), findsOneWidget);
    });

    testWidgets('a field key nobody knows gets the general answer', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const FieldHelpDialog(
            field: RequiredField(
              key: 'character_name',
              labelKm: 'x',
              labelEn: 'Character',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('account or profile screen'), findsOneWidget);
    });

    testWidgets('it says what a wrong id costs, without promising a reversal', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const FieldHelpDialog(field: _gameId)));
      await tester.pumpAndSettle();

      expect(find.textContaining('cannot be reversed'), findsOneWidget);
      expect(find.textContaining('returns to your wallet'), findsOneWidget);
    });
  });

  group('RequiredFieldsForm', () {
    testWidgets(
      'an error lands on the field that caused it, not on all of them',
      (tester) async {
        final controllers = {
          'userid': TextEditingController(),
          'serverid': TextEditingController(),
        };
        addTearDown(() => controllers['userid']!.dispose());
        addTearDown(() => controllers['serverid']!.dispose());

        await _pumpAt320(
          tester,
          RequiredFieldsForm(
            fields: const [_gameId, _server],
            locale: 'en',
            controllerFor: (field) => controllers[field.key]!,
            errors: const {'userid': 'Required'},
          ),
        );

        // One message, under one field. The old checkout painted its single error
        // string under every input on the page.
        expect(find.text('Required'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('the help button opens the guide for that field', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _pumpAt320(
        tester,
        RequiredFieldsForm(
          fields: const [_gameId],
          locale: 'en',
          controllerFor: (_) => controller,
          errors: const {},
        ),
      );

      await tester.tap(find.byIcon(Icons.help_outline));
      await tester.pumpAndSettle();

      expect(find.byType(FieldHelpDialog), findsOneWidget);
      expect(find.textContaining('Game ID'), findsWidgets);
    });

    testWidgets('a number pad on the id and a text keyboard on an open field', (
      tester,
    ) async {
      final controllers = {
        'userid': TextEditingController(),
        'nickname': TextEditingController(),
      };
      addTearDown(() => controllers['userid']!.dispose());
      addTearDown(() => controllers['nickname']!.dispose());

      await _pumpAt320(
        tester,
        RequiredFieldsForm(
          fields: const [
            _gameId,
            RequiredField(
              key: 'nickname',
              labelKm: 'x',
              labelEn: 'Nickname',
              pattern: r'^[a-zA-Z0-9]+$',
            ),
          ],
          locale: 'en',
          controllerFor: (field) => controllers[field.key]!,
          errors: const {},
        ),
      );

      final boxes = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(boxes.first.keyboardType, TextInputType.number);
      expect(boxes.last.keyboardType, TextInputType.text);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long label does not overflow at 320px', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _pumpAt320(
        tester,
        RequiredFieldsForm(
          fields: const [
            RequiredField(
              key: 'userid',
              labelKm: 'x',
              labelEn: 'Your in-game player identifier',
              placeholder: '123456789',
              pattern: r'^[0-9]{6,12}$',
            ),
          ],
          locale: 'en',
          controllerFor: (_) => controller,
          errors: const {},
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('messages', () {
    testWidgets('the format message repeats the example the field gives', (
      tester,
    ) async {
      late AppL10n l10n;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              l10n = AppL10n.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
        fieldProblemMessage(l10n, _gameId, FieldProblem.format),
        contains('123456789'),
      );
      expect(
        fieldProblemMessage(l10n, _gameId, FieldProblem.empty),
        isNot(contains('123456789')),
      );

      // A field with no example cannot quote one.
      expect(
        fieldProblemMessage(
          l10n,
          const RequiredField(key: 'k', labelKm: 'x', labelEn: 'y'),
          FieldProblem.format,
        ),
        isNot(contains('(')),
      );
    });
  });
}
