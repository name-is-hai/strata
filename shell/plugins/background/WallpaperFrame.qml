import QtQuick
import qs.Commons
import "Placement.js" as Placement

Item {
  id: frame
  property string path: ""
  property size decodeSize: Qt.size(0, 0)
  property var nativeSize: null
  property var placement: ({})
  // Preview dimensions differ from the display; Center must retain its scale.
  property real displayScale: 1
  readonly property int status: image.status
  readonly property bool ready: image.status === Image.Ready && !(nativeSize && nativeSize.pending === true)
  readonly property real imageWidth: nativeSize && nativeSize.width > 0 ? nativeSize.width : image.implicitWidth
  readonly property real imageHeight: nativeSize && nativeSize.height > 0 ? nativeSize.height : image.implicitHeight
  readonly property var geometry: Placement.geometry(width / displayScale, height / displayScale,
    imageWidth, imageHeight, placement)
  clip: true

  Image {
    id: image
    source: frame.path && !Util.isVideoPath(frame.path) && frame.decodeSize.width > 0 ? Util.fileUrl(frame.path) : ""
    sourceSize.width: Math.ceil(frame.decodeSize.width * Placement.normalize(frame.placement).zoom)
    sourceSize.height: Math.ceil(frame.decodeSize.height * Placement.normalize(frame.placement).zoom)
    fillMode: Image.Stretch
    visible: frame.ready
    x: frame.geometry.x * frame.displayScale
    y: frame.geometry.y * frame.displayScale
    width: frame.geometry.width * frame.displayScale
    height: frame.geometry.height * frame.displayScale
    asynchronous: true
    retainWhileLoading: true
    cache: false
    smooth: true
    mipmap: true
  }
}
