.pragma library

// A resizable PNG remains a bitmap. Never stretch its pixels beyond native
// resolution on the output; SVG themes can use the full locator enlargement.
function magnification(imagePath, imageWidth, baseSize, outputScale, requested) {
    var limit = 8.0
    if (!imagePath.toLowerCase().endsWith(".svg") && imageWidth > 0 && baseSize > 0)
        limit = Math.max(1.0, Math.min(limit, imageWidth / (baseSize * Math.max(1.0, outputScale))))
    return Math.min(requested, limit)
}
