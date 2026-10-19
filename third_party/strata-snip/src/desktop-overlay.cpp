#include "desktop-overlay.hpp"
#include "editor.hpp"
#include <LayerShellQt/Window>
#include <QApplication>
#include <QEnterEvent>
#include <QKeyEvent>
#include <QMouseEvent>
#include <QPainter>
#include <QPaintEvent>
#include <QScreen>
#include <QTransform>
#include <QWheelEvent>
#include <QWindow>

class DesktopView final : public QWidget {
public:
  DesktopView(CaptureEditor &editor, QRect viewport)
      : editor_(editor), viewport_(viewport) {
    setWindowFlags(Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint);
    setAttribute(Qt::WA_OpaquePaintEvent);
    setMouseTracking(true);
    setFocusPolicy(Qt::StrongFocus);
    resize(viewport.size());
  }
  const QRect &viewport() const { return viewport_; }
  void updateCanvas(const QRegion &damage) {
    const QRegion local = damage.intersected(viewport_).translated(-viewport_.topLeft());
    if (!local.isEmpty())
      update(QTransform::fromScale(width() / qreal(viewport_.width()),
                                   height() / qreal(viewport_.height())).map(local));
  }
protected:
  void paintEvent(QPaintEvent *event) override {
    QPainter painter(this);
    // Qt maps the source region's top-left to the target offset. Each view
    // therefore paints only its own slice, including a cross-output selection.
    const QRegion localDamage = QTransform::fromScale(viewport_.width() / qreal(width()),
        viewport_.height() / qreal(height())).map(event->region()).intersected(QRect(QPoint(), viewport_.size()));
    painter.scale(width() / qreal(viewport_.width()), height() / qreal(viewport_.height()));
    editor_.render(&painter, localDamage.boundingRect().topLeft(),
                   localDamage.translated(viewport_.topLeft()));
    setCursor(editor_.cursor());
  }
  void enterEvent(QEnterEvent *event) override {
    editor_.setDesktopViewport(viewport_);
    const QPointF position = canvasPosition(event->position());
    QEnterEvent forwarded(position, position, event->globalPosition());
    QApplication::sendEvent(&editor_, &forwarded);
    setCursor(editor_.cursor());
  }
  void mouseMoveEvent(QMouseEvent *event) override { forwardMouse(event); }
  void mousePressEvent(QMouseEvent *event) override { forwardMouse(event); }
  void mouseReleaseEvent(QMouseEvent *event) override { forwardMouse(event); }
  void mouseDoubleClickEvent(QMouseEvent *event) override { forwardMouse(event); }
  void keyPressEvent(QKeyEvent *event) override { forwardKey(event); }
  void keyReleaseEvent(QKeyEvent *event) override { forwardKey(event); }
  void wheelEvent(QWheelEvent *event) override {
    const QPointF position = canvasPosition(event->position());
    QWheelEvent forwarded(position, event->globalPosition(), event->pixelDelta(),
                          event->angleDelta(), event->buttons(), event->modifiers(),
                          event->phase(), event->inverted(), event->source(), event->pointingDevice());
    QApplication::sendEvent(&editor_, &forwarded);
  }
  void closeEvent(QCloseEvent *event) override {
    QKeyEvent escape(QEvent::KeyPress, Qt::Key_Escape, Qt::NoModifier);
    QApplication::sendEvent(&editor_, &escape);
    QWidget::closeEvent(event);
  }
private:
  QPointF canvasPosition(const QPointF &position) const {
    return viewport_.topLeft() + QPointF(position.x() * viewport_.width() / width(),
                                         position.y() * viewport_.height() / height());
  }
  void forwardMouse(QMouseEvent *event) {
    const QPointF position = canvasPosition(event->position());
    // An implicit Wayland grab reports motion outside the originating surface,
    // preserving one continuous drag across outputs, including negative origins.
    if (event->buttons() == Qt::NoButton || event->type() == QEvent::MouseButtonPress)
      editor_.setDesktopViewport(viewport_);
    QWidget *target = editor_.childAt(position.toPoint());
    if (!target) target = &editor_;
    const QPointF local = position - target->mapTo(&editor_, QPoint());
    QMouseEvent forwarded(event->type(), local, position, event->globalPosition(),
                          event->button(), event->buttons(), event->modifiers(),
                          event->pointingDevice());
    forwarded.setTimestamp(event->timestamp());
    QApplication::sendEvent(target, &forwarded);
    setCursor(editor_.cursor());
  }
  void forwardKey(QKeyEvent *event) {
    QWidget *target = editor_.focusWidget();
    QApplication::sendEvent(target ? target : &editor_, event);
  }
  CaptureEditor &editor_;
  QRect viewport_;
};

DesktopOverlay::DesktopOverlay(CaptureEditor &editor)
    : QObject(nullptr), editor_(editor) {
  editor_.setAttribute(Qt::WA_DontShowOnScreen);
  editor_.resize(editor_.desktopGeometry().size());
  if (!editor_.desktopOutputs().isEmpty())
    editor_.setDesktopViewport(editor_.desktopOutputs().first().geometry.translated(-editor_.desktopGeometry().topLeft()));
  editor_.installEventFilter(this);
  connect(&editor_, &CaptureEditor::repaintRequested, this, [this](const QRegion &damage) {
    for (const auto &view : views_) view->updateCanvas(damage);
  });
}
DesktopOverlay::~DesktopOverlay() {
  closing_ = true;
  editor_.removeEventFilter(this);
}
QWidget *DesktopOverlay::addView(const QRect &viewport, QScreen *screen) {
  auto view = std::make_unique<DesktopView>(editor_, viewport);
  if (screen) {
    view->winId();
    // Bind Qt's scale/geometry to the same output as the layer-shell surface.
    view->windowHandle()->setScreen(screen);
    auto *layer = LayerShellQt::Window::get(view->windowHandle());
    if (!layer) return nullptr;
    layer->setScope(QStringLiteral("strata-snip"));
    layer->setScreen(screen);
    layer->setLayer(LayerShellQt::Window::LayerOverlay);
    LayerShellQt::Window::Anchors anchors;
    anchors.setFlag(LayerShellQt::Window::AnchorTop);
    anchors.setFlag(LayerShellQt::Window::AnchorBottom);
    anchors.setFlag(LayerShellQt::Window::AnchorLeft);
    anchors.setFlag(LayerShellQt::Window::AnchorRight);
    layer->setAnchors(anchors);
    layer->setExclusiveZone(-1);
    layer->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityExclusive);
    layer->setActivateOnShow(true);
    connect(screen, &QObject::destroyed, this, [this] { editor_.close(); });
  }
  auto *result = view.get();
  views_.push_back(std::move(view));
  return result;
}
QWidget *DesktopOverlay::viewForTest(qsizetype index) const {
  return index >= 0 && static_cast<std::size_t>(index) < views_.size()
      ? views_[index].get() : nullptr;
}
bool DesktopOverlay::show(QString &error) {
  for (const auto &output : editor_.desktopOutputs()) {
    QScreen *screen = nullptr;
    for (auto *candidate : QGuiApplication::screens())
      if (candidate->name() == output.name) { screen = candidate; break; }
    if (!screen || !addView(output.geometry.translated(-editor_.desktopGeometry().topLeft()), screen)) {
      error = QStringLiteral("A display disappeared while preparing the screenshot");
      return false;
    }
  }
  editor_.show();
  for (const auto &view : views_) view->show();
  return true;
}
bool DesktopOverlay::eventFilter(QObject *watched, QEvent *event) {
  if (watched == &editor_ && !closing_) {
    if (event->type() == QEvent::Hide) {
      closing_ = true;
      for (const auto &view : views_) view->hide();
      QCoreApplication::quit();
    }
  }
  return QObject::eventFilter(watched, event);
}
