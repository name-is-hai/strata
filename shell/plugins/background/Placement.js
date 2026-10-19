function normalize(value) {
  value = value || {}
  function number(raw, fallback, low, high) {
    return typeof raw === "number" && isFinite(raw) ? Math.max(low, Math.min(high, raw)) : fallback
  }
  return {
    mode: ["fill", "fit", "stretch", "center"].indexOf(value.mode) >= 0 ? value.mode : "fill",
    x: number(value.x, 0.5, 0, 1), y: number(value.y, 0.5, 0, 1),
    zoom: number(value.zoom, 1, 1, 3)
  }
}

function geometry(width, height, imageWidth, imageHeight, placement) {
  var p = normalize(placement)
  if (!(width > 0 && height > 0 && imageWidth > 0 && imageHeight > 0))
    return { width: width, height: height, x: 0, y: 0 }
  var scale = p.mode === "center" ? 1 : p.mode === "fit"
    ? Math.min(width / imageWidth, height / imageHeight)
    : Math.max(width / imageWidth, height / imageHeight)
  var w = (p.mode === "stretch" ? width : imageWidth * scale) * p.zoom
  var h = (p.mode === "stretch" ? height : imageHeight * scale) * p.zoom
  return { width: w, height: h, x: (width - w) * p.x, y: (height - h) * p.y }
}

function dragged(start, dx, dy, viewportWidth, viewportHeight, imageWidth, imageHeight) {
  var p = normalize(start)
  var g = geometry(viewportWidth, viewportHeight, imageWidth, imageHeight, p)
  if (Math.abs(viewportWidth - g.width) > 0.1) p.x += dx / (viewportWidth - g.width)
  if (Math.abs(viewportHeight - g.height) > 0.1) p.y += dy / (viewportHeight - g.height)
  return normalize(p)
}
