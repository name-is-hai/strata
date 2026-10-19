var MIN_TEMPERATURE = 1000
var MAX_TEMPERATURE = 6500
var IDENTITY_TEMPERATURE = 6000

function clampTemperature(value, fallback) {
  var temperature = Number(value)
  if (!isFinite(temperature)) temperature = Number(fallback)
  if (!isFinite(temperature)) temperature = 4000
  return Math.max(MIN_TEMPERATURE, Math.min(MAX_TEMPERATURE, Math.round(temperature / 100) * 100))
}

function hasCoordinates(latitude, longitude) {
  var lat = Number(latitude)
  var lon = Number(longitude)
  return isFinite(lat) && isFinite(lon) && Math.abs(lat) <= 90 && Math.abs(lon) <= 180
}

function dayOfYear(date) {
  var start = new Date(date.getFullYear(), 0, 0)
  return Math.floor((date - start) / 86400000)
}

// NOAA's sunrise/sunset approximation. It runs locally and needs no location
// service or network request; callers supply latitude and longitude.
function utcSunEventHours(latitude, longitude, date, sunrise) {
  var lat = Number(latitude) * Math.PI / 180
  var day = dayOfYear(date)
  var longitudeHour = Number(longitude) / 15
  var approximate = day + ((sunrise ? 6 : 18) - longitudeHour) / 24
  var meanAnomaly = 0.9856 * approximate - 3.289
  var trueLongitude = meanAnomaly + 1.916 * Math.sin(meanAnomaly * Math.PI / 180)
    + 0.020 * Math.sin(2 * meanAnomaly * Math.PI / 180) + 282.634
  trueLongitude = (trueLongitude % 360 + 360) % 360
  var rightAscension = Math.atan(0.91764 * Math.tan(trueLongitude * Math.PI / 180)) * 180 / Math.PI
  rightAscension = (rightAscension % 360 + 360) % 360
  rightAscension += Math.floor(trueLongitude / 90) * 90 - Math.floor(rightAscension / 90) * 90
  rightAscension /= 15
  var sinDeclination = 0.39782 * Math.sin(trueLongitude * Math.PI / 180)
  var cosDeclination = Math.cos(Math.asin(sinDeclination))
  var cosHourAngle = (Math.cos(90.833 * Math.PI / 180) - sinDeclination * Math.sin(lat))
    / (cosDeclination * Math.cos(lat))
  if (cosHourAngle > 1 || cosHourAngle < -1) return null
  var hourAngle = (sunrise ? 360 - Math.acos(cosHourAngle) * 180 / Math.PI
    : Math.acos(cosHourAngle) * 180 / Math.PI) / 15
  return hourAngle + rightAscension - 0.06571 * approximate - 6.622 - longitudeHour
}

function wrapMinutes(value) {
  return (Math.round(value) % 1440 + 1440) % 1440
}

function localSunMinutes(utcHours, date) {
  if (utcHours === null || utcHours === undefined) return null
  var utc = Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()) + utcHours * 3600000
  var local = new Date(utc)
  return local.getHours() * 60 + local.getMinutes()
}

function sunTimes(latitude, longitude, date) {
  if (!hasCoordinates(latitude, longitude)) return { sunrise: null, sunset: null }
  var day = date || new Date()
  return {
    sunrise: localSunMinutes(utcSunEventHours(latitude, longitude, day, true), day),
    sunset: localSunMinutes(utcSunEventHours(latitude, longitude, day, false), day)
  }
}

function interpolate(from, to, progress) {
  var amount = Math.max(0, Math.min(1, progress))
  return clampTemperature(from + (to - from) * amount)
}

function scheduledTemperature(options) {
  var day = clampTemperature(options.dayTemperature, 6500)
  var night = clampTemperature(options.nightTemperature, 3400)
  var now = wrapMinutes(options.nowMinutes)
  var sunrise = options.sunriseMinutes
  var sunset = options.sunsetMinutes
  var transition = Math.max(0, Math.min(180, Number(options.transitionMinutes) || 0))
  if (sunrise === null || sunset === null || sunrise === undefined || sunset === undefined) return day

  sunrise = wrapMinutes(sunrise)
  sunset = wrapMinutes(sunset)
  var sunriseEnd = wrapMinutes(sunrise + transition)
  var sunsetEnd = wrapMinutes(sunset + transition)
  var inRange = function(start, end, value) {
    return start <= end ? value >= start && value < end : value >= start || value < end
  }
  if (transition > 0 && inRange(sunrise, sunriseEnd, now))
    return interpolate(night, day, ((now - sunrise + 1440) % 1440) / transition)
  if (transition > 0 && inRange(sunset, sunsetEnd, now))
    return interpolate(day, night, ((now - sunset + 1440) % 1440) / transition)
  var daytime = sunrise < sunset ? now >= sunriseEnd && now < sunset : now >= sunriseEnd || now < sunset
  return daytime ? day : night
}

function formatMinutes(value) {
  if (value === null || value === undefined) return "Unavailable"
  var minutes = wrapMinutes(value)
  var hours = String(Math.floor(minutes / 60))
  var remainder = String(minutes % 60)
  return (hours.length < 2 ? "0" : "") + hours + ":" + (remainder.length < 2 ? "0" : "") + remainder
}

if (typeof module !== "undefined") {
  module.exports = {
    MIN_TEMPERATURE: MIN_TEMPERATURE,
    MAX_TEMPERATURE: MAX_TEMPERATURE,
    IDENTITY_TEMPERATURE: IDENTITY_TEMPERATURE,
    clampTemperature: clampTemperature,
    hasCoordinates: hasCoordinates,
    sunTimes: sunTimes,
    scheduledTemperature: scheduledTemperature,
    formatMinutes: formatMinutes
  }
}
