// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show createHttpClient;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http;

void main() {
  TextTheme textTheme = new Typography(platform: TargetPlatform.android)
      .black
      .merge(new TextTheme(body1: new TextStyle(fontSize: 12.0)));

  testWidgets('Simple string', (WidgetTester tester) async {
    await tester.pumpWidget(_boilerplate(const MarkdownBody(data: 'Hello')));

    final Iterable<Widget> widgets = tester.allWidgets;
    _expectWidgetTypes(
        widgets, <Type>[Directionality, MarkdownBody, Column, RichText]);
    _expectTextStrings(widgets, <String>['Hello']);
  });

  testWidgets('Header', (WidgetTester tester) async {
    await tester.pumpWidget(_boilerplate(const MarkdownBody(data: '# Header')));

    final Iterable<Widget> widgets = tester.allWidgets;
    _expectWidgetTypes(
        widgets, <Type>[Directionality, MarkdownBody, Column, RichText]);
    _expectTextStrings(widgets, <String>['Header']);
  });

  testWidgets('Empty string', (WidgetTester tester) async {
    await tester.pumpWidget(_boilerplate(const MarkdownBody(data: '')));

    final Iterable<Widget> widgets = tester.allWidgets;
    _expectWidgetTypes(widgets, <Type>[Directionality, MarkdownBody, Column]);
  });

  testWidgets('Ordered list', (WidgetTester tester) async {
    await tester.pumpWidget(_boilerplate(
      const MarkdownBody(data: '1. Item 1\n1. Item 2\n2. Item 3'),
    ));

    final Iterable<Widget> widgets = tester.allWidgets;
    _expectTextStrings(widgets, <String>[
      '1.',
      'Item 1',
      '2.',
      'Item 2',
      '3.',
      'Item 3',
    ]);
  });

  testWidgets('Unordered list', (WidgetTester tester) async {
    await tester.pumpWidget(
      _boilerplate(const MarkdownBody(data: '- Item 1\n- Item 2\n- Item 3')),
    );

    final Iterable<Widget> widgets = tester.allWidgets;
    _expectTextStrings(widgets, <String>[
      '•',
      'Item 1',
      '•',
      'Item 2',
      '•',
      'Item 3',
    ]);
  });

  testWidgets('Scrollable wrapping', (WidgetTester tester) async {
    await tester.pumpWidget(_boilerplate(const Markdown(data: '')));

    final List<Widget> widgets = tester.allWidgets.toList();
    _expectWidgetTypes(widgets.take(3), <Type>[
      Directionality,
      Markdown,
      ListView,
    ]);
    _expectWidgetTypes(widgets.reversed.take(2).toList().reversed, <Type>[
      SliverPadding,
      SliverList,
    ]);
  });

  group('Links', () {
    testWidgets('should be tappable', (WidgetTester tester) async {
      String tapResult;
      await tester.pumpWidget(_boilerplate(new Markdown(
        data: '[Link Text](href)',
        onTapLink: (value) => tapResult = value,
      )));

      final RichText textWidget =
          tester.allWidgets.firstWhere((Widget widget) => widget is RichText);
      final TextSpan span = textWidget.text;

      (span.children[0].children[0].recognizer as TapGestureRecognizer).onTap();

      expect(span.children.length, 1);
      expect(span.children[0].children.length, 1);
      expect(span.children[0].children[0].recognizer.runtimeType,
          equals(TapGestureRecognizer));
      expect(tapResult, 'href');
    });

    testWidgets('should work with nested elements', (WidgetTester tester) async {
      final List<String> tapResults = <String>[];
      await tester.pumpWidget(_boilerplate(new Markdown(
        data: '[Link `with nested code` Text](href)',
        onTapLink: (value) => tapResults.add(value),
      )));

      final RichText textWidget =
          tester.allWidgets.firstWhere((Widget widget) => widget is RichText);
      final TextSpan span = textWidget.text;

      final List<Type> gestureRecognizerTypes = <Type>[];
      span.visitTextSpan((TextSpan textSpan) {
        TapGestureRecognizer recognizer = textSpan.recognizer;
        gestureRecognizerTypes.add(recognizer.runtimeType);
        recognizer.onTap();
        return true;
      });

      expect(span.children.length, 1);
      expect(span.children[0].children.length, 3);
      expect(gestureRecognizerTypes, everyElement(TapGestureRecognizer));
      expect(tapResults.length, 3);
      expect(tapResults, everyElement('href'));
    });

    testWidgets('should work next to other links', (WidgetTester tester) async {
      final List<String> tapResults = <String>[];

      await tester.pumpWidget(_boilerplate(new Markdown(
          data: '[First Link](firstHref) and [Second Link](secondHref)',
          onTapLink: (value) => tapResults.add(value),
      )));

      final RichText textWidget =
          tester.allWidgets.firstWhere((Widget widget) => widget is RichText);
      final TextSpan span = textWidget.text;

      final List<Type> gestureRecognizerTypes = <Type>[];
      span.visitTextSpan((TextSpan textSpan) {
        TapGestureRecognizer recognizer = textSpan.recognizer;
        gestureRecognizerTypes.add(recognizer.runtimeType);
        recognizer?.onTap();
        return true;
      });


      expect(span.children.length, 3);
      expect(span.children[0].children.length, 1);
      expect(span.children[1].children, null);
      expect(span.children[2].children.length, 1);

      expect(gestureRecognizerTypes,
          orderedEquals([TapGestureRecognizer, Null, TapGestureRecognizer]));
      expect(tapResults, orderedEquals(['firstHref', 'secondHref']));
    });
  });
  
  group('Images', () {
    setUpAll(() {
      createHttpClient = createMockImageHttpClient;
    });

    testWidgets('should work with a link', (WidgetTester tester) async {
      await tester
          .pumpWidget(_boilerplate(const Markdown(data: '![alt](img#50x50)')));

      final Image image =
        tester.allWidgets.firstWhere((Widget widget) => widget is Image);
      final NetworkImage networkImage = image.image;
      expect(networkImage.url, 'img');
      expect(image.width, 50);
      expect(image.height, 50);
    });

    testWidgets('should show properly next to text', (WidgetTester tester) async {      
      await tester
          .pumpWidget(_boilerplate(const Markdown(data: 'Hello ![alt](img#50x50)')));

      final RichText richText =
        tester.allWidgets.firstWhere((Widget widget) => widget is RichText);
      TextSpan textSpan = richText.text;
      expect(textSpan.children[0].text, 'Hello ');
      expect(textSpan.style, isNotNull);
    });
  });

  testWidgets('HTML tag ignored ', (WidgetTester tester) async {
    final List<String> mdData = <String>[
      'Line 1\n<p>HTML content</p>\nLine 2',
      'Line 1\n<!-- HTML\n comment\n ignored --><\nLine 2'
    ];

    for (String mdLine in mdData) {
      await tester.pumpWidget(_boilerplate(new MarkdownBody(data: mdLine)));

      final Iterable<Widget> widgets = tester.allWidgets;
      _expectTextStrings(widgets, <String>['Line 1', 'Line 2']);
    }
  });

  testWidgets('Less than', (WidgetTester tester) async {
    final String mdLine = 'Line 1 <\n\nc < c c\n\n< Line 2';
    await tester.pumpWidget(_boilerplate(new MarkdownBody(data: mdLine)));

    final Iterable<Widget> widgets = tester.allWidgets;
    _expectTextStrings(
        widgets, <String>['Line 1 &lt;', 'c &lt; c c', '&lt; Line 2']);
  });

  testWidgets('Changing config - data', (WidgetTester tester) async {
    await tester.pumpWidget(_boilerplate(const Markdown(data: 'Data1')));
    _expectTextStrings(tester.allWidgets, <String>['Data1']);

    final String stateBefore = _dumpRenderView();
    await tester.pumpWidget(_boilerplate(const Markdown(data: 'Data1')));
    final String stateAfter = _dumpRenderView();
    expect(stateBefore, equals(stateAfter));

    await tester.pumpWidget(_boilerplate(const Markdown(data: 'Data2')));
    _expectTextStrings(tester.allWidgets, <String>['Data2']);
  });

  testWidgets('Changing config - style', (WidgetTester tester) async {
    final ThemeData theme = new ThemeData.light().copyWith(textTheme: textTheme);

    final MarkdownStyleSheet style1 = new MarkdownStyleSheet.fromTheme(theme);
    final MarkdownStyleSheet style2 =
    new MarkdownStyleSheet.largeFromTheme(theme);
    expect(style1, isNot(style2));

    await tester.pumpWidget(
      _boilerplate(new Markdown(data: '# Test', styleSheet: style1)),
    );
    final RichText text1 = tester.widget(find.byType(RichText));
    await tester.pumpWidget(
      _boilerplate(new Markdown(data: '# Test', styleSheet: style2)),
    );
    final RichText text2 = tester.widget(find.byType(RichText));

    expect(text1.text, isNot(text2.text));
  });

  testWidgets('Style equality', (WidgetTester tester) async {
    final ThemeData theme = new ThemeData.light().copyWith(textTheme: textTheme);

    final MarkdownStyleSheet style1 = new MarkdownStyleSheet.fromTheme(theme);
    final MarkdownStyleSheet style2 = new MarkdownStyleSheet.fromTheme(theme);
    expect(style1, equals(style2));
    expect(style1.hashCode, equals(style2.hashCode));
  });
}

void _expectWidgetTypes(Iterable<Widget> widgets, List<Type> expected) {
  final List<Type> actual = widgets.map((Widget w) => w.runtimeType).toList();
  expect(actual, expected);
}

void _expectTextStrings(Iterable<Widget> widgets, List<String> strings) {
  int currentString = 0;
  for (Widget widget in widgets) {
    if (widget is RichText) {
      final TextSpan span = widget.text;
      final String text = _extractTextFromTextSpan(span);
      expect(text, equals(strings[currentString]));
      currentString += 1;
    }
  }
}

String _extractTextFromTextSpan(TextSpan span) {
  String text = span.text ?? '';
  if (span.children != null) {
    for (TextSpan child in span.children) {
      text += _extractTextFromTextSpan(child);
    }
  }
  return text;
}

String _dumpRenderView() {
  return WidgetsBinding.instance.renderViewElement.toStringDeep().replaceAll(
      new RegExp(r'SliverChildListDelegate#\d+', multiLine: true),
      'SliverChildListDelegate');
}

/// Wraps a widget with a left-to-right [Directionality] for tests.
Widget _boilerplate(Widget child) {
  return new Directionality(
    textDirection: TextDirection.ltr,
    child: child,
  );
}

// Returns a mock HTTP client that responds with an image to all requests.
ValueGetter<http.Client> createMockImageHttpClient = () {
  return new http.MockClient((http.BaseRequest request) {
    return new Future<http.Response>.value(
        new http.Response.bytes(_transparentImage, 200, request: request));
  });
};

const List<int> _transparentImage = const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
];
