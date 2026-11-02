import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart' show dioMeansOffline;

// Fehlerberichte 02.11.26: Netzfehler hinter DioExceptionType.unknown kamen
// als UnknownException an (Anmeldung im Ruhemodus des Handys).
void main() {
  final req = RequestOptions(path: 'https://start.example/');
  DioException e(DioExceptionType t, [Object? err]) =>
      DioException(requestOptions: req, type: t, error: err);

  test('Zeitüberschreitung und Verbindungsfehler: offline', () {
    for (final t in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.connectionError,
    ]) {
      expect(dioMeansOffline(e(t)), isTrue, reason: '$t');
    }
  });

  test('unknown mit Netzfehler: offline', () {
    expect(
      dioMeansOffline(
        e(
          DioExceptionType.unknown,
          const SocketException('Failed host lookup'),
        ),
      ),
      isTrue,
    );
    expect(
      dioMeansOffline(
        e(DioExceptionType.unknown, const HttpException('Connection closed')),
      ),
      isTrue,
    );
    expect(
      dioMeansOffline(
        e(DioExceptionType.unknown, const HandshakeException('x')),
      ),
      isTrue,
    );
  });

  test('anderes bleibt unbekannt', () {
    expect(
      dioMeansOffline(e(DioExceptionType.unknown, StateError('x'))),
      isFalse,
    );
    expect(dioMeansOffline(e(DioExceptionType.badResponse)), isFalse);
    expect(dioMeansOffline(e(DioExceptionType.cancel)), isFalse);
  });
}
