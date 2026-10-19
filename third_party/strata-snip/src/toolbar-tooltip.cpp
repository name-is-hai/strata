#include "toolbar-tooltip.hpp"
#include "chrome-theme.hpp"
#include "overlay-chrome.hpp"
#include <QFontMetrics>
#include <QPainter>
#include <algorithm>

ToolbarTooltip::ToolbarTooltip(QWidget *parent) : QWidget(parent) {
  setObjectName(QStringLiteral("toolbar-tooltip"));
  setAttribute(Qt::WA_TransparentForMouseEvents);
  setAttribute(Qt::WA_NoSystemBackground);
  setFocusPolicy(Qt::NoFocus);
  hide();
}

void ToolbarTooltip::setTip(const QRectF &anchor, const QString &text) {
  if (text.isEmpty() || parentWidget()->width() < 32 || parentWidget()->height() < 32) {
    hide();
    return;
  }
  const QFontMetrics metrics(chromeFont(12));
  const int maximum = std::max(1, std::min(720, parentWidget()->width() - 36));
  const QRect measured = metrics.boundingRect(QRect(0, 0, maximum, 10000),
      Qt::TextWordWrap | Qt::TextWrapAnywhere | Qt::AlignLeft, text);
  const int width = std::min(parentWidget()->width() - 16, measured.width() + 24);
  const int height = std::min(parentWidget()->height() - 16, measured.height() + 16);
  const int x = std::clamp(qRound(anchor.center().x() - width / 2.0), 8,
                            std::max(8, parentWidget()->width() - width - 8));
  int y = qRound(anchor.top()) - height - 7;
  if (y < 8) y = qRound(anchor.bottom()) + 7;
  y = std::clamp(y, 8, std::max(8, parentWidget()->height() - height - 8));
  const QRect geometry(x, y, width, height);
  if (text_ != text || this->geometry() != geometry) {
    text_ = text;
    setAccessibleName(text);
    setGeometry(geometry);
    update();
  }
  show();
  raise();
}

void ToolbarTooltip::paintEvent(QPaintEvent *) {
  QPainter painter(this);
  painter.setRenderHints(QPainter::Antialiasing | QPainter::TextAntialiasing);
  const QRectF bounds = QRectF(rect()).adjusted(.5, .5, -.5, -.5);
  painter.setPen(QPen(chromeTheme().tooltipBorder, 1));
  painter.setBrush(chromeTheme().tooltipBackground);
  painter.drawRoundedRect(bounds, 7, 7);
  painter.setFont(chromeFont(12));
  painter.setPen(chromeTheme().tooltipText);
  painter.drawText(rect().adjusted(12, 8, -12, -8),
                   Qt::TextWordWrap | Qt::TextWrapAnywhere | Qt::AlignLeft | Qt::AlignVCenter, text_);
}
