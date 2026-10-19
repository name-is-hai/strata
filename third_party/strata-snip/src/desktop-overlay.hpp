/** Per-output Wayland views sharing one virtual-desktop selector. */
#pragma once
#include <QObject>
#include <QRect>
#include <QVector>
#include <memory>
#include <vector>

class CaptureEditor;
class QWidget;
class QScreen;
class DesktopView;

class DesktopOverlay final : public QObject {
public:
  explicit DesktopOverlay(CaptureEditor &editor);
  ~DesktopOverlay() override;
  bool show(QString &error);
  // Offscreen fixtures exercise the exact same forwarding/rendering path.
  QWidget *addView(const QRect &viewport, QScreen *screen = nullptr);
  QWidget *viewForTest(qsizetype index) const;
  bool eventFilter(QObject *watched, QEvent *event) override;
private:
  CaptureEditor &editor_;
  std::vector<std::unique_ptr<DesktopView>> views_;
  bool closing_ = false;
};
