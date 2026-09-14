/// Русская локализация Material, Cupertino и базовых виджетов — и только она.
///
/// Стандартные делегаты `GlobalMaterialLocalizations.delegate` и соседние
/// выбирают перевод по коду языка в большом switch и при первой загрузке
/// регистрируют форматы дат всех восьмидесяти с лишним языков из одной
/// общей таблицы. Компилятор не может знать, что приложению нужен только
/// русский, и оставляет в main.dart.js все переводы и все таблицы дат.
///
/// Здесь класс русского перевода создаётся напрямую, а форматы дат
/// регистрируются только для русского. Остальные языки перестают быть
/// достижимыми из кода и выбрасываются при сборке.
library;

import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show CupertinoLocalizationRu, MaterialLocalizationRu, WidgetsLocalizationRu;
import 'package:intl/date_symbol_data_custom.dart' as intl_custom;
import 'package:intl/date_symbols.dart' as intl;
import 'package:intl/intl.dart' as intl;

const String _ru = 'ru';

/// Делегаты для MaterialApp.localizationsDelegates.
const List<LocalizationsDelegate<Object>> ruLocalizationsDelegates = [
  _RuMaterialLocalizationsDelegate(),
  _RuCupertinoLocalizationsDelegate(),
  _RuWidgetsLocalizationsDelegate(),
];

bool _isRu(Locale locale) => locale.languageCode == _ru;

class _RuMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _RuMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isRu(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    _registerRussianDates();
    // Те же форматы, что выбирает GlobalMaterialLocalizations.delegate.
    return SynchronousFuture(
      MaterialLocalizationRu(
        fullYearFormat: intl.DateFormat.y(_ru),
        compactDateFormat: intl.DateFormat.yMd(_ru),
        shortDateFormat: intl.DateFormat.yMMMd(_ru),
        mediumDateFormat: intl.DateFormat.MMMEd(_ru),
        longDateFormat: intl.DateFormat.yMMMMEEEEd(_ru),
        yearMonthFormat: intl.DateFormat.yMMMM(_ru),
        shortMonthDayFormat: intl.DateFormat.MMMd(_ru),
        decimalFormat: intl.NumberFormat.decimalPattern(_ru),
        twoDigitZeroPaddedFormat: intl.NumberFormat('00', _ru),
      ),
    );
  }

  @override
  bool shouldReload(_RuMaterialLocalizationsDelegate old) => false;
}

class _RuCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _RuCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isRu(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    _registerRussianDates();
    return SynchronousFuture(
      CupertinoLocalizationRu(
        fullYearFormat: intl.DateFormat.y(_ru),
        dayFormat: intl.DateFormat.d(_ru),
        weekdayFormat: intl.DateFormat.E(_ru),
        mediumDateFormat: intl.DateFormat.MMMEd(_ru),
        singleDigitHourFormat: intl.DateFormat('HH', _ru),
        singleDigitMinuteFormat: intl.DateFormat.m(_ru),
        doubleDigitMinuteFormat: intl.DateFormat('mm', _ru),
        singleDigitSecondFormat: intl.DateFormat.s(_ru),
        decimalFormat: intl.NumberFormat.decimalPattern(_ru),
      ),
    );
  }

  @override
  bool shouldReload(_RuCupertinoLocalizationsDelegate old) => false;
}

class _RuWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const _RuWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isRu(locale);

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      SynchronousFuture(const WidgetsLocalizationRu());

  @override
  bool shouldReload(_RuWidgetsLocalizationsDelegate old) => false;
}

bool _datesRegistered = false;

void _registerRussianDates() {
  if (_datesRegistered) return;
  intl_custom.initializeDateFormattingCustom(
    locale: _ru,
    symbols: _ruDateSymbols,
    patterns: _ruDatePatterns,
  );
  _datesRegistered = true;
}

// Таблицы ниже перенесены из flutter_localizations
// (lib/src/l10n/generated_date_localizations.dart, запись 'ru') без правок.

final intl.DateSymbols _ruDateSymbols = intl.DateSymbols(
  NAME: _ru,
  ERAS: const ['до н. э.', 'н. э.'],
  ERANAMES: const ['до Рождества Христова', 'от Рождества Христова'],
  NARROWMONTHS: const [
    'Я',
    'Ф',
    'М',
    'А',
    'М',
    'И',
    'И',
    'А',
    'С',
    'О',
    'Н',
    'Д',
  ],
  STANDALONENARROWMONTHS: const [
    'Я', 'Ф', 'М', 'А', 'М', 'И', 'И', 'А', 'С', 'О', 'Н', 'Д', //
  ],
  MONTHS: const [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня', //
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ],
  STANDALONEMONTHS: const [
    'январь', 'февраль', 'март', 'апрель', 'май', 'июнь', //
    'июль', 'август', 'сентябрь', 'октябрь', 'ноябрь', 'декабрь',
  ],
  SHORTMONTHS: const [
    'янв.', 'февр.', 'мар.', 'апр.', 'мая', 'июн.', //
    'июл.', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.',
  ],
  STANDALONESHORTMONTHS: const [
    'янв.', 'февр.', 'март', 'апр.', 'май', 'июнь', //
    'июль', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.',
  ],
  WEEKDAYS: const [
    'воскресенье', 'понедельник', 'вторник', 'среда', //
    'четверг', 'пятница', 'суббота',
  ],
  STANDALONEWEEKDAYS: const [
    'воскресенье', 'понедельник', 'вторник', 'среда', //
    'четверг', 'пятница', 'суббота',
  ],
  SHORTWEEKDAYS: const ['вс', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб'],
  STANDALONESHORTWEEKDAYS: const ['вс', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб'],
  NARROWWEEKDAYS: const ['В', 'П', 'В', 'С', 'Ч', 'П', 'С'],
  STANDALONENARROWWEEKDAYS: const ['В', 'П', 'В', 'С', 'Ч', 'П', 'С'],
  SHORTQUARTERS: const ['1-й кв.', '2-й кв.', '3-й кв.', '4-й кв.'],
  QUARTERS: const ['1-й квартал', '2-й квартал', '3-й квартал', '4-й квартал'],
  AMPMS: const ['AM', 'PM'],
  DATEFORMATS: const [
    "EEEE, d MMMM y 'г'.",
    "d MMMM y 'г'.",
    "d MMM y 'г'.",
    'dd.MM.y',
  ],
  TIMEFORMATS: const ['HH:mm:ss zzzz', 'HH:mm:ss z', 'HH:mm:ss', 'HH:mm'],
  FIRSTDAYOFWEEK: 0,
  WEEKENDRANGE: const [5, 6],
  FIRSTWEEKCUTOFFDAY: 3,
  DATETIMEFORMATS: const ['{1}, {0}', '{1}, {0}', '{1}, {0}', '{1}, {0}'],
);

const Map<String, String> _ruDatePatterns = {
  'd': 'd',
  'E': 'ccc',
  'EEEE': 'cccc',
  'LLL': 'LLL',
  'LLLL': 'LLLL',
  'M': 'L',
  'Md': 'dd.MM',
  'MEd': 'EEE, dd.MM',
  'MMM': 'LLL',
  'MMMd': 'd MMM',
  'MMMEd': 'ccc, d MMM',
  'MMMM': 'LLLL',
  'MMMMd': 'd MMMM',
  'MMMMEEEEd': 'cccc, d MMMM',
  'QQQ': 'QQQ',
  'QQQQ': 'QQQQ',
  'y': 'y',
  'yM': 'MM.y',
  'yMd': 'dd.MM.y',
  'yMEd': "ccc, dd.MM.y 'г'.",
  'yMMM': "LLL y 'г'.",
  'yMMMd': "d MMM y 'г'.",
  'yMMMEd': "EEE, d MMM y 'г'.",
  'yMMMM': "LLLL y 'г'.",
  'yMMMMd': "d MMMM y 'г'.",
  'yMMMMEEEEd': "EEEE, d MMMM y 'г'.",
  'yQQQ': "QQQ y 'г'.",
  'yQQQQ': "QQQQ y 'г'.",
  'H': 'HH',
  'Hm': 'HH:mm',
  'Hms': 'HH:mm:ss',
  'j': 'HH',
  'jm': 'HH:mm',
  'jms': 'HH:mm:ss',
  'jmv': 'HH:mm v',
  'jmz': 'HH:mm z',
  'jz': 'HH z',
  'm': 'm',
  'ms': 'mm:ss',
  's': 's',
  'v': 'v',
  'z': 'z',
  'zzzz': 'zzzz',
  'ZZZZ': 'ZZZZ',
};
