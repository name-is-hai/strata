#pragma once
class QApplication;
class QString;
bool runDesktopSmoke(QApplication &application, QString &error);

bool runDesktopLiveSmoke(QApplication &application, QString &error);
