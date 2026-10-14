import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/core/utils/formatters.dart';

void main() {
  test('chapterLabel adds the number only when the title lacks one', () {
    expect(chapterLabel(3, '沒有旗的船'), '第3章 沒有旗的船');
    expect(chapterLabel(3, '第三章 沒有旗的船'), '第三章 沒有旗的船');
    expect(chapterLabel(12, '第12章 歸來'), '第12章 歸來');
    expect(chapterLabel(1, '第一回 起'), '第一回 起');
    expect(chapterLabel(5, ''), '第5章');
    // A title merely starting with 第 is not a chapter number.
    expect(chapterLabel(2, '第一次見面'), '第2章 第一次見面');
  });
}
