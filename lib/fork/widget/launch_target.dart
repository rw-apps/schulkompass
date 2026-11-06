/// Ziele eines Tipps im Startbildschirm-Widget bzw. auf eine
/// Benachrichtigung – eigene Datei, damit notify_launch.dart (auch im
/// Hintergrundlauf) sie ohne widget_launch.dart (home_widget, Familie)
/// kennt (Prüfung 06.11.26: sonst Kreisimport).
library;

/// Schema der Adresse (SchoolWidget.kt, notify_launch.dart).
const widgetLaunchScheme = 'schulportal-widget';

/// Wohin ein Tipp im Widget bzw. auf eine Benachrichtigung führt.
/// [calendar]: Kalender „Termine“ (Vorabend-Meldung, notices.dart);
/// [storage]: Dateispeicher (neue Datei der Schule). Nur Benachrichtigungen
/// nutzen die beiden; das Widget kennt sie nicht.
enum WidgetTarget { today, exams, homework, meal, calendar, storage }
