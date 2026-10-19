/** @fileoverview Shared overlay chrome: pinned fonts, the mode badge, hotkey
 *  guide, and status pill. */
#pragma once

#include <QColor>
#include <QPair>
#include <QRect>
#include <QRectF>
#include <QString>
#include <QVector>

class QFont;
class QPainter;

/// The typeface for overlay chrome text (toolbar labels, hotkey legend,
/// tooltips): the system monospace alias selected by Strata's font setup.
[[nodiscard]] QFont chromeFont(int pixelSize, bool bold = false);
/// The application-wide default font, installed by main() before any widget
/// exists, follows the system monospace alias.
[[nodiscard]] QFont chromeDefaultFont();
/// Monospace counterpart for numeric readouts: fontconfig's `monospace`
/// alias, which is what the fixed-font lookup resolved to under every theme
/// as configured by Strata.
[[nodiscard]] QFont chromeMonoFont(int pixelSize, bool bold = false);

/// The badge naming what the overlay is doing, centered at the top, with the ×
/// that leaves it. Returns the whole badge; `closeRect` is the × alone, for
/// hit-testing the click that closes.
QRectF drawModeBadge(QPainter &painter, const QRect &bounds,
                     const QString &label, const QColor &accent,
                     QRectF *closeRect = nullptr);

/// A single, backgroundless column of `key  action` pairs along the bottom
/// left, growing upward, in low-opacity text. Hotkeys are a reference, not
/// UI: there is no card, no border, and no attempt to dodge the pointer or
/// dodge anything else — draw it early (right after the overlay's initial
/// dim fill, before the image, toolbar, or any popup) and
/// normal paint order does the rest, since whatever is drawn afterward
/// simply covers it wherever the two overlap.
void drawHotkeyLegend(QPainter &painter, const QRect &bounds,
                      const QVector<QPair<QString, QString>> &entries);

/// The size the key guide takes in its wide anchored form (a windowed
/// editor's toolbar band) when it may be at most `maxWidth` wide: rows are
/// added until the card fits.
[[nodiscard]] QSize hotkeyLegendAnchoredSize(
    const QVector<QPair<QString, QString>> &entries, qreal maxWidth);

/// A wide key card a few rows tall, centered over `anchorAbove`: a compact
/// window has no clear margin for the overlay's backgroundless column, so
/// the windowed layout reserves this card room instead.
void drawAnchoredHotkeyLegend(QPainter &painter, const QRect &bounds,
                              const QVector<QPair<QString, QString>> &entries,
                              const QRectF &anchorAbove);

/// The instruction line along the bottom.
void drawStatusPill(QPainter &painter, const QRect &bounds,
                    const QString &text);
