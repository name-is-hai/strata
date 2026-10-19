#include "snip-preference.hpp"

#include <QtConcurrent/QtConcurrentRun>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QThreadPool>

namespace {
QString preferencePath() {
  QString root = qEnvironmentVariable("XDG_STATE_HOME");
  if (!QDir::isAbsolutePath(root))
    root = QDir::home().filePath(QStringLiteral(".local/state"));
  return QDir(root).filePath(QStringLiteral("strata/snip-mode"));
}

bool validMode(const QString &mode) {
  return mode == QStringLiteral("region") || mode == QStringLiteral("app") ||
         mode == QStringLiteral("monitor");
}

QThreadPool &preferencePool() {
  struct SerialPool final : QThreadPool {
    SerialPool() { setMaxThreadCount(1); }
  };
  static SerialPool pool;
  return pool;
}
} // namespace

QString loadSnipModePreference() {
  QFile file(preferencePath());
  if (!file.open(QIODevice::ReadOnly))
    return QStringLiteral("region");
  const QString mode = QString::fromUtf8(file.read(32)).trimmed();
  return validMode(mode) ? mode : QStringLiteral("region");
}

QFuture<void> rememberSnipModePreference(const QString &mode) {
  if (!validMode(mode))
    return {};
  const QString path = preferencePath();
  return QtConcurrent::run(&preferencePool(), [path, mode] {
    if (!QDir().mkpath(QFileInfo(path).absolutePath()))
      return;
    QSaveFile file(path);
    if (file.open(QIODevice::WriteOnly)) {
      if (file.write(mode.toUtf8()) != mode.toUtf8().size())
        return;
      file.commit();
    }
  });
}
