#pragma once
#include <QWidget>

// Separate child surface: old tooltip pixels are invalidated by Qt when the
// tooltip moves, and the bubble stays above canvas and editor child controls.
class ToolbarTooltip final : public QWidget {
  Q_OBJECT
public:
  explicit ToolbarTooltip(QWidget *parent);
  void setTip(const QRectF &anchor, const QString &text);
protected:
  void paintEvent(QPaintEvent *) override;
private:
  QString text_;
};
