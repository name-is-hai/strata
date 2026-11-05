function promptLooksFingerprint(text) {
  var s = String(text || "").toLowerCase()
  return s.indexOf("finger") !== -1 || s.indexOf("fprint") !== -1 || s.indexOf("swipe") !== -1
}

function visibleSupplementary(text) {
  var s = String(text || "").trim()
  return /no devices available|no fingerprints enrolled|has no fingers enrolled/i.test(s) ? "" : s
}

function authorizationLabel(message) {
  var text = String(message || "")
  var match = text.match(/^Authentication is (?:needed|required) to run [`']([^`']+)[`'] as /i)
  return match ? "Authorize running '" + match[1] + "'" : text
}

if (typeof module !== "undefined") {
  module.exports = {
    promptLooksFingerprint: promptLooksFingerprint,
    visibleSupplementary: visibleSupplementary,
    authorizationLabel: authorizationLabel
  }
}
