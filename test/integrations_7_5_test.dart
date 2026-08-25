import 'package:flutter_test/flutter_test.dart';

import 'package:riogram/core/bot/web_app_bridge_handler.dart';
import 'package:riogram/core/chat/latex_parser.dart';

void main() {
  group('WebAppBridgeHandler', () {
    test('parses sendData and main button updates', () {
      const state = WebAppUiState();

      final sendData = WebAppBridgeHandler.parseMessage(
        '{"event":"sendData","data":"hello"}',
        currentState: state,
      );
      expect(sendData, isA<WebAppSendDataEvent>());
      expect((sendData as WebAppSendDataEvent).data, 'hello');

      final ui = WebAppBridgeHandler.parseMessage(
        '{"event":"mainButtonSetParams","text":"Pay","is_visible":true}',
        currentState: state,
      );
      expect(ui, isA<WebAppUiChangedEvent>());
      final changed = ui as WebAppUiChangedEvent;
      expect(changed.state.mainButtonText, 'Pay');
      expect(changed.state.mainButtonVisible, isTrue);
    });
  });

  group('LatexParser', () {
    test('parses inline and block formulas', () {
      final segments = LatexParser.parse(r'Inline $a^2+b^2=c^2$ and block $$\int_0^1 x dx$$');
      expect(segments, hasLength(4));
      expect(segments[0], isA<LatexTextSegment>());
      expect((segments[0] as LatexTextSegment).text, 'Inline ');
      expect(segments[1], isA<LatexFormulaSegment>());
      expect((segments[1] as LatexFormulaSegment).isBlock, isFalse);
      expect((segments[1] as LatexFormulaSegment).expression, r'a^2+b^2=c^2');
      expect(segments[2], isA<LatexTextSegment>());
      expect((segments[2] as LatexTextSegment).text, ' and block ');
      expect(segments[3], isA<LatexFormulaSegment>());
      expect((segments[3] as LatexFormulaSegment).isBlock, isTrue);
      expect((segments[3] as LatexFormulaSegment).expression, r'\int_0^1 x dx');
    });

    test('containsLatex detects delimiters', () {
      expect(LatexParser.containsLatex(r'\(\alpha\)'), isTrue);
      expect(LatexParser.containsLatex('plain text'), isFalse);
    });
  });
}
