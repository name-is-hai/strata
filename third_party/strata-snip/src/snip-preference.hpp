#pragma once

#include <QFuture>
#include <QString>

/** Last mode selected in the Strata Snip capture toolbar. */
[[nodiscard]] QString loadSnipModePreference();
/** Persists region, app, or monitor on a serial worker. */
[[nodiscard]] QFuture<void> rememberSnipModePreference(const QString &mode);
