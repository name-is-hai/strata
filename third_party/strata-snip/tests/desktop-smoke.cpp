#include "desktop-smoke.hpp"
#include "capture.hpp"
#include "desktop-overlay.hpp"
#include "editor.hpp"
#include <QApplication>
#include <QPainter>
#include <QWindow>
#include <QScreen>
#include <QtTest/QTest>

bool runDesktopSmoke(QApplication &application, QString &error) {
  CaptureData left, right, desktop;
  left.monitor = {QStringLiteral("left"), {-200, 0, 200, 200}, {200, 200}, 1, 1};
  right.monitor = {QStringLiteral("right"), {0, 0, 200, 200}, {400, 400}, 2, 2};
  left.previewSize = right.previewSize = {200, 200};
  left.source = QImage(200, 200, QImage::Format_ARGB32_Premultiplied);
  right.source = QImage(400, 400, QImage::Format_ARGB32_Premultiplied);
  left.source.fill(Qt::red); right.source.fill(Qt::blue);
  right.windows = {{{40, 100, 80, 80}, QStringLiteral("right-app"), QStringLiteral("Test"), QStringLiteral("test")}};
  if (!composeDesktop({left, right}, desktop, error)) return false;
  if (desktop.monitor.geometry != QRect(-200, 0, 400, 200) ||
      desktop.source.size() != QSize(800, 400) || desktop.monitor.scale != 2 ||
      desktop.windows.first().rect != QRect(240, 100, 80, 80) ||
      desktop.source.pixelColor(20, 20) != QColor(Qt::red) ||
      desktop.source.pixelColor(600, 20) != QColor(Qt::blue)) {
    error = QStringLiteral("Desktop composition lost scale, origin, pixels or window geometry");
    return false;
  }
  {
    CaptureEditor editor(desktop, CaptureEditor::CaptureMode::Region);
    editor.setSnipToolbarEnabled(true);
    editor.setSuppressSnapshots(true);
    DesktopOverlay overlay(editor);
    QWidget *a = overlay.addView({0, 0, 200, 200});
    QWidget *b = overlay.addView({200, 0, 200, 200});
    editor.show(); a->show(); b->show(); application.processEvents();
    QImage whole(editor.size(), QImage::Format_ARGB32_Premultiplied);
    editor.render(&whole);
    const auto rightView = b->grab().toImage();
    if (rightView.pixelColor(20,110) != whole.pixelColor(220,110)) {
      error = QStringLiteral("Output view painted the wrong slice of the desktop");
      return false;
    }
    // An implicit grab on the left delivers the end outside its 200px width.
    QTest::mousePress(a, Qt::LeftButton, Qt::NoModifier, QPoint(150, 120));
    QTest::mouseMove(a, QPoint(250, 170));
    QTest::mouseRelease(a, Qt::LeftButton, Qt::NoModifier, QPoint(250, 170));
    const QImage selected = editor.renderCurrentOutput();
    if (editor.currentSelection() != QRectF(150, 120, 100, 50) ||
        selected.size() != QSize(200, 100) ||
        selected.pixelColor(20, 20) != QColor(Qt::red) ||
        selected.pixelColor(180, 20) != QColor(Qt::blue)) {
      error = QStringLiteral("Cross-monitor implicit-grab drag or mixed-DPI export failed");
      return false;
    }
    editor.close(); application.processEvents();
    if (a->isVisible() || b->isVisible()) {
      error = QStringLiteral("Closing desktop capture left another overlay visible");
      return false;
    }
  }
  for (const auto mode : {CaptureEditor::CaptureMode::Region, CaptureEditor::CaptureMode::Window,
                          CaptureEditor::CaptureMode::Fullscreen}) {
    CaptureEditor editor(desktop, CaptureEditor::CaptureMode::Region);
    editor.setSnipToolbarEnabled(true, mode);
    editor.setSuppressSnapshots(true);
    DesktopOverlay overlay(editor);
    QWidget *b = overlay.addView({200, 0, 200, 200});
    editor.show(); b->show(); application.processEvents();
    QTest::mousePress(b, Qt::LeftButton, Qt::NoModifier, QPoint(80, 130));
    if (mode == CaptureEditor::CaptureMode::Region) {
      QTest::mouseMove(b, QPoint(140, 180));
      QTest::mouseRelease(b, Qt::LeftButton, Qt::NoModifier, QPoint(140, 180));
    }
    const QRectF expected = mode == CaptureEditor::CaptureMode::Region ? QRectF(280,130,60,50)
                          : mode == CaptureEditor::CaptureMode::Window ? QRectF(240,100,80,80)
                          : QRectF(200,0,200,200);
    if (editor.currentSelection() != expected) {
      error = QStringLiteral("Target selection on the second output used the first output");
      return false;
    }
    editor.close(); application.processEvents();
  }
  {
    CaptureEditor editor(desktop, CaptureEditor::CaptureMode::Region);
    editor.setSnipToolbarEnabled(true, CaptureEditor::CaptureMode::Fullscreen);
    editor.setSuppressSnapshots(true);
    DesktopOverlay overlay(editor);
    QWidget *b = overlay.addView({200, 0, 200, 200});
    QStringList recording;
    QObject::connect(&editor, &CaptureEditor::recordingRequested, &editor,
                     [&recording](const QStringList &args) { recording = args; });
    editor.show(); b->show(); application.processEvents();
    QTest::keyClick(b, Qt::Key_4);
    QTest::mousePress(b, Qt::LeftButton, Qt::NoModifier, QPoint(80, 150));
    if (!recording.contains(QStringLiteral("--output=right"))) {
      error = QStringLiteral("Monitor recording used the virtual desktop as an output");
      return false;
    }
  }
  {
    CaptureEditor editor(desktop, CaptureEditor::CaptureMode::Region);
    editor.setSnipToolbarEnabled(true);
    editor.setSuppressSnapshots(true);
    DesktopOverlay overlay(editor);
    QWidget *b = overlay.addView({200, 0, 200, 200});
    QStringList requested;
    QObject::connect(&editor, &CaptureEditor::singleOutputRequested, &editor,
                     [&requested](const QStringList &args) { requested = args; });
    editor.show(); b->show(); application.processEvents();
    QTest::keyClick(b, Qt::Key_S);
    if (requested.value(0) != QStringLiteral("scroll") || b->isVisible()) {
      error = QStringLiteral("Scrolling capture did not hand off from the frozen desktop");
      return false;
    }
  }
  {
    CaptureEditor editor(desktop, CaptureEditor::CaptureMode::Region);
    editor.setSnipToolbarEnabled(true);
    editor.setSuppressSnapshots(true);
    DesktopOverlay overlay(editor);
    QWidget *b = overlay.addView({200, 0, 200, 200});
    b->resize(100, 100);
    editor.show(); b->show(); application.processEvents();
    QTest::mousePress(b, Qt::LeftButton, Qt::NoModifier, QPoint(20, 60));
    QTest::mouseMove(b, QPoint(50, 90));
    QTest::mouseRelease(b, Qt::LeftButton, Qt::NoModifier, QPoint(50, 90));
    if (editor.currentSelection() != QRectF(240, 120, 60, 60)) {
      error = QStringLiteral("Per-view scale did not map into desktop coordinates");
      return false;
    }
    editor.close();
  }
  // Choosing Monitor is only a mode change; a subsequent display click captures.
  for (const bool keyboard : {false, true}) {
    CaptureEditor editor(desktop, CaptureEditor::CaptureMode::Region);
    editor.setSnipToolbarEnabled(true);
    editor.setSuppressSnapshots(true);
    DesktopOverlay overlay(editor);
    QWidget *a = overlay.addView({0, 0, 200, 200});
    QWidget *b = overlay.addView({200, 0, 200, 200});
    editor.show(); a->show(); b->show(); application.processEvents();
    QTest::mouseMove(a, QPoint(10,110));
    application.processEvents();
    if (keyboard) QTest::keyClick(a, Qt::Key_3);
    else QTest::mouseClick(a, Qt::LeftButton, Qt::NoModifier,
                          editor.snipToolbarButtonRectForTest(2).center().toPoint());
    if (editor.snipModeForTest() != CaptureEditor::CaptureMode::Fullscreen ||
        !editor.currentSelection().isEmpty()) {
      error = QStringLiteral("Monitor selection failed (%1): mode %2, selection %3x%4")
          .arg(keyboard).arg(static_cast<int>(editor.snipModeForTest()))
          .arg(editor.currentSelection().width()).arg(editor.currentSelection().height());
      return false;
    }
    QTest::mouseClick(b, Qt::LeftButton, Qt::NoModifier, QPoint(100,150));
    if (editor.currentSelection() != QRectF(200,0,200,200)) {
      error = QStringLiteral("Monitor choice did not capture the display clicked afterwards");
      return false;
    }
    editor.close();
  }
  // Gaps and displays above the origin retain their real desktop positions.
  right.monitor.geometry = {0, -100, 200, 200};
  if (!composeDesktop({left, right}, desktop, error) ||
      desktop.monitor.geometry != QRect(-200,-100,400,300) ||
      desktop.source.pixelColor(20,20) != QColor(Qt::black)) {
    error = QStringLiteral("Desktop gap/vertical origin composition failed");
    return false;
  }
  return true;
}

bool runDesktopLiveSmoke(QApplication &application, QString &error) {
  CaptureData desktop;
  if (!captureDesktop(desktop, error)) return false;
  if (desktop.outputs.size() < 2) {
    error = QStringLiteral("Live desktop test needs two active displays");
    return false;
  }
  const auto outputs = desktop.outputs;
  const QRect geometry = desktop.monitor.geometry;
  const qreal scale = desktop.monitor.scale;
  CaptureEditor editor(desktop, CaptureEditor::CaptureMode::Region);
  editor.setSnipToolbarEnabled(true);
  editor.setSuppressSnapshots(true);
  DesktopOverlay overlay(editor);
  if (!overlay.show(error)) return false;
  QTest::qWait(300);
  for (qsizetype i = 0; i < outputs.size(); ++i) {
    auto *view = overlay.viewForTest(i);
    if (view) qInfo() << "Live output" << outputs[i].name << outputs[i].geometry
                     << "view" << view->size() << "Qt" << view->windowHandle()->screen()->geometry();
    if (!view || !view->windowHandle()->isExposed()) {
      error = QStringLiteral("Live layer did not expose on %1").arg(outputs[i].name);
      return false;
    }
  }
  QWidget *origin = overlay.viewForTest(0);
  const QPoint a = outputs[0].geometry.center();
  const QPoint b = outputs[1].geometry.center() + QPoint(0, outputs[1].geometry.height()/5);
  const auto viewPoint = [&](const QPoint &global) {
    const QPoint local = global - outputs[0].geometry.topLeft();
    return QPoint(qRound(local.x() * origin->width() / qreal(outputs[0].geometry.width())),
                  qRound(local.y() * origin->height() / qreal(outputs[0].geometry.height())));
  };
  const QPoint localA = viewPoint(a);
  const QPoint localB = viewPoint(b);
  QTest::mousePress(origin, Qt::LeftButton, Qt::NoModifier, localA);
  QTest::mouseMove(origin, localB, 20);
  QTest::mouseRelease(origin, Qt::LeftButton, Qt::NoModifier, localB);
  application.processEvents();
  const QRectF expected = QRectF(QPointF(a - geometry.topLeft()), QPointF(b - geometry.topLeft())).normalized();
  const QImage output = editor.renderCurrentOutput();
  const QRectF selected = editor.currentSelection();
  if (qAbs(selected.x()-expected.x()) > 1 || qAbs(selected.y()-expected.y()) > 1 ||
      qAbs(selected.width()-expected.width()) > 2 || qAbs(selected.height()-expected.height()) > 2 ||
      output.size() != QSize(qRound(selected.width()*scale), qRound(selected.height()*scale))) {
    error = QStringLiteral("Live drag: expected %1,%2 %3x%4, got %5,%6 %7x%8; image %9x%10 at scale %11; origin view %12x%13")
        .arg(expected.x()).arg(expected.y()).arg(expected.width()).arg(expected.height())
        .arg(editor.currentSelection().x()).arg(editor.currentSelection().y())
        .arg(editor.currentSelection().width()).arg(editor.currentSelection().height())
        .arg(output.width()).arg(output.height()).arg(scale)
        .arg(origin->width()).arg(origin->height());
    return false;
  }
  editor.close();
  application.processEvents();
  for (qsizetype i = 0; i < outputs.size(); ++i)
    if (overlay.viewForTest(i)->isVisible()) {
      error = QStringLiteral("Live capture left an output overlay behind");
      return false;
    }
  qInfo("PASS: native Wayland layers exposed on all outputs; cross-display drag, mixed scale export and dismissal passed");
  return true;
}
