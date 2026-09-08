import 'package:flutter_test/flutter_test.dart';
import 'package:service_desk/core/validators.dart' as v;

/// Проверки полей вынесены в отдельный файл именно затем, чтобы их можно
/// было проверить без запуска интерфейса.
void main() {
  test('обязательность заполнения ловит пустую строку и пустой список', () {
    expect(v.notEmpty(null), isNotNull);
    expect(v.notEmpty(''), isNotNull);
    expect(v.notEmpty('   '), isNotNull);
    expect(v.notEmpty(<int>[]), isNotNull);
    expect(v.notEmpty('Тема'), isNull);
    expect(v.notEmpty([1]), isNull);
  });

  test('ограничение длины считает по обрезанной строке', () {
    expect(v.length('abc', min: 5), isNotNull);
    expect(v.length('abcde', min: 5), isNull);
    expect(v.length('a' * 11, max: 10), isNotNull);
    // Пустое значение пропускается: за него отвечает notEmpty.
    expect(v.length('', min: 5), isNull);
  });

  test('диапазон числа', () {
    expect(v.range(0, min: 1, max: 3), isNotNull);
    expect(v.range(4, min: 1, max: 3), isNotNull);
    expect(v.range(2, min: 1, max: 3), isNull);
    expect(v.range(null, min: 1, max: 3), isNull);
  });

  test('положительное число', () {
    expect(v.positive('0'), isNotNull);
    expect(v.positive('-4'), isNotNull);
    expect(v.positive('нет'), isNotNull);
    expect(v.positive('24'), isNull);
  });

  test('адрес почты', () {
    expect(v.email('abramov'), isNotNull);
    expect(v.email('abramov@'), isNotNull);
    expect(v.email('abramov@sd'), isNotNull);
    expect(v.email('abramov@sd.local'), isNull);
  });

  test('телефон', () {
    expect(v.phone('телефон'), isNotNull);
    expect(v.phone('12345'), isNotNull);
    expect(v.phone('+7 495 000-10-01'), isNull);
  });

  test('доменный логин', () {
    expect(v.login('Ivanov'), isNotNull);
    expect(v.login('ab'), isNotNull);
    expect(v.login('ivanov.ii'), isNull);
  });

  test('код отдела', () {
    expect(v.code('itsup'), isNotNull);
    expect(v.code('I'), isNotNull);
    expect(v.code('ITSUP'), isNull);
  });

  test('номер заявки', () {
    expect(v.ticketNumber('12'), isNotNull);
    expect(v.ticketNumber('SD-12'), isNotNull);
    expect(v.ticketNumber('SD-000012'), isNull);
  });

  test('ФИО', () {
    expect(v.fullName('иванов иван'), isNotNull);
    expect(v.fullName('Иванов'), isNotNull);
    expect(v.fullName('Иванов Иван'), isNull);
    expect(v.fullName('Иванов Иван Иванович'), isNull);
  });

  test('all возвращает первую сработавшую проверку', () {
    final validate = v.all<String>([
      (value) => v.notEmpty(value, 'Поле пустое'),
      (value) => v.length(value, min: 5),
      v.email,
    ]);

    expect(validate(''), 'Поле пустое');
    expect(validate('abc'), 'Не короче 5 символов');
    expect(validate('abcdef'), isNotNull);
    expect(validate('abramov@sd.local'), isNull);
  });
}
