// Adapt Strata's existing archive to Foamy's presentation without duplicating it.
function entry(row) {
  return {
    key: String(row.key || ""), app: String(row.app || row.source || "Notification"),
    summary: String(row.summary || ""), body: String(row.bodyLine || row.body || ""),
    rawBody: String(row.rawBody || row.body || ""), timestamp: Number(row.ts || 0) * 1000,
    urgency: Number(row.urgency || 0), appIcon: String(row.stored_image || row.appIcon || ""),
    preview: /^data:image\/png;base64,/.test(String(row.sender_image || "")) ? row.sender_image : "", source: String(row.source || ""), original: row
  }
}
function entries(rows, removed) {
  var byKey = Object.create(null)
  rows.forEach(function(row) {
    if (row && row.key && !removed[row.key] && !byKey[row.key]) byKey[row.key] = entry(row)
  })
  return Object.keys(byKey).map(function(key) { return byKey[key] })
    .sort(function(a,b) { return b.timestamp - a.timestamp })
}
if (typeof module !== "undefined") module.exports = {entry:entry,entries:entries}
