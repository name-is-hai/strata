// Hyprland IDs stay unique; Strata presents local desktop numbers per output.
function base(monitor) { return (Number(monitor.id) + 1) * 100 }
function owns(monitor, id) { return !!monitor && id > base(monitor) && id < base(monitor) + 100 }
function number(id) { return Number(id) % 100 }
function rebase(monitor, id) {
  var local = number(id)
  return monitor && local > 0 ? base(monitor) + local : 0
}
