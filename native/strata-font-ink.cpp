// Measure glyph outlines rather than font bounding boxes that include padding.
#include <QGuiApplication>
#include <QFont>
#include <QJsonArray>
#include <QJsonDocument>
#include <QPainterPath>
#include <cstdio>
#include <iostream>
#include <iterator>

int main(int argc, char **argv) {
    qputenv("QT_QPA_PLATFORM", "offscreen");
    QGuiApplication app(argc, argv);
    const std::string input{std::istreambuf_iterator<char>(std::cin), {}};
    if (input.size() > 1024 * 1024) return 1;
    QJsonParseError error;
    const auto document = QJsonDocument::fromJson(QByteArray::fromStdString(input), &error);
    if (error.error != QJsonParseError::NoError || !document.isArray()) return 1;
    QJsonArray output;
    for (const auto &value : document.array()) {
        const auto row = value.toArray();
        if (row.size() != 3 || !row[0].isString() || !row[1].isDouble() || !row[2].isString()) return 1;
        const auto text = row[2].toString();
        const int pixels = row[1].toInt();
        if (pixels < 1 || pixels > 512 || text.size() > 128) return 1;
        QFont font(row[0].toString());
        font.setPixelSize(pixels);
        QPainterPath outline;
        outline.addText(QPointF(0, 0), font, text);
        const auto rect = outline.boundingRect();
        output.append(QJsonArray{row[0], pixels, row[2], rect.x(), rect.y(), rect.width(), rect.height()});
    }
    const auto json = QJsonDocument(output).toJson(QJsonDocument::Compact);
    return std::fwrite(json.constData(), 1, json.size(), stdout) == size_t(json.size()) ? 0 : 1;
}
