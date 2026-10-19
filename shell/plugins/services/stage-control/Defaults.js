// Defaults.js - Strata Stage's settings: their defaults, and what each may be.
//
// Code rather than JSON files, so Strata Stage reads no files at run time. Settings
// are stored on the Strata Stage entry in shell.json, holding
// only what differs from DEFAULTS; Settings.merge() validates them against
// SCHEMA before anything uses them.

var DEFAULTS = {
  gestureFingers: 4,
  appExposeGesture: true,
  threeFingerLeft: "nextApp",
  threeFingerRight: "previousApp",
  threeFingerUp: "overview",
  threeFingerDown: "showDesktop",
  shortcuts: true,
  stageKey: "SUPER + A",
  appWindowsKey: "SUPER + ALT + A",
  macShortcuts: false,
  groupByApp: false,
  windowTitles: "hover",
  appIcons: true,
  spacesBar: "auto",
  renumberDesktops: true,
  closeButtons: true,
  middleClickClose: true,
  showMinimized: true,
  background: "blur",
  dim: 25,
  glass: "solid",
  highlight: "accent",
  reduceMotion: false,
  speed: 100
}

var SCHEMA = {
  types: {
    gestureFingers: "int",
    appExposeGesture: "bool",
    threeFingerLeft: "string",
    threeFingerRight: "string",
    threeFingerUp: "string",
    threeFingerDown: "string",
    shortcuts: "bool",
    stageKey: "shortcut",
    appWindowsKey: "shortcut",
    macShortcuts: "bool",
    groupByApp: "bool",
    windowTitles: "string",
    appIcons: "bool",
    spacesBar: "string",
    renumberDesktops: "bool",
    closeButtons: "bool",
    middleClickClose: "bool",
    showMinimized: "bool",
    background: "string",
    dim: "int",
    glass: "string",
    highlight: "string",
    reduceMotion: "bool",
    speed: "int"
  },
  choices: {
    gestureFingers: [0, 4],
    threeFingerLeft: ["off", "nextApp", "previousApp", "overview", "showDesktop", "stage", "appWindows"],
    threeFingerRight: ["off", "nextApp", "previousApp", "overview", "showDesktop", "stage", "appWindows"],
    threeFingerUp: ["off", "nextApp", "previousApp", "overview", "showDesktop", "stage", "appWindows"],
    threeFingerDown: ["off", "nextApp", "previousApp", "overview", "showDesktop", "stage", "appWindows"],
    windowTitles: ["hover", "always", "never"],
    spacesBar: ["auto", "expanded"],
    background: ["blur", "dim"],
    glass: ["liquid", "frosted", "solid"],
    highlight: ["accent", "blue", "purple", "pink", "red", "orange", "yellow", "green", "graphite"]
  },
  ranges: {
    dim: [0, 80],
    speed: [50, 200]
  }
}
