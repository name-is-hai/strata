#!/bin/bash
# jq transforms JSON. Perl supplies descriptor-bound IO and atomic replacement
# because Bash redirections cannot express O_NOFOLLOW or O_NONBLOCK.
set -eu
exec timeout --kill-after=1s 5s perl - "$0" "$@" <<'PERL'
use strict;
use warnings;
use Fcntl qw(O_RDONLY O_WRONLY O_CREAT O_EXCL O_NOFOLLOW O_NONBLOCK O_DIRECTORY LOCK_EX);
use IO::Handle;

my ($script, $action, $name, $value, $background) = @ARGV;
$action //= 'read';
my $cap = 131072;
my ($temporary, $directory);
my $validate = q{
  def name: type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
    and (test("[^A-Za-z0-9._-]") | not) and (contains("..") | not);
  def background: type == "string" and utf8bytelength <= 600
    and (startswith("theme:") or startswith("extra:"))
    and (.[6:] != "" and .[6:] != "." and .[6:] != "..")
    and (contains("/") | not) and (contains("\u0000") | not);
  def valid: type == "object" and (keys == ["favorites","hidden","version"]) and .version == 1
    and (.favorites | type == "array" and length <= 512 and all(.[]; name))
    and (.hidden | type == "object" and length <= 512
      and all(to_entries[]; (.key | name) and (.value | type == "array" and length <= 200 and all(.[]; background))));
  if valid then . else error("Invalid preferences") end
};
my $change = q{
  if $action != "read" then
    if ($name | name) and ($value == "true" or $value == "false") then .
    else error("Invalid preference arguments") end |
    if $action == "favorite" then
      .favorites |= (if $value == "true" then if index($name) == null then . + [$name] else . end else map(select(. != $name)) end)
    else
      if ($background | background) then . else error("Invalid background identity") end |
      .hidden[$name] = ((.hidden[$name] // []) |
        if $value == "true" then if index($background) == null then . + [$background] else . end else map(select(. != $background)) end) |
      .hidden |= with_entries(select(.value | length > 0))
    end
  else . end |
  if valid then . else error("Preferences limit exceeded") end
};

eval {
  die "Unknown action\n" unless $action =~ /\A(?:read|favorite|hidden)\z/;
  umask 0077;
  open(my $lock, '<', $script) or die "Lock: $!\n";
  flock($lock, LOCK_EX) or die "Lock: $!\n";
  my $state = $ENV{XDG_STATE_HOME} || "$ENV{HOME}/.local/state";
  my $path = "$state/strata/swatch";
  if (!-e $path && !-l $path && $action eq 'read') {
    print "{\"version\":1,\"favorites\":[],\"hidden\":{}}\n";
    exit 0;
  }
  system('mkdir', '-p', '--', $path) == 0 or die "Create state directory failed\n";
  sysopen($directory, $path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW) or die "State directory: $!\n";
  # Resolve all file operations through this opened directory, even if the
  # original pathname is renamed or replaced during the operation.
  my $base = '/proc/self/fd/' . fileno($directory);
  my $raw = '{"version":1,"favorites":[],"hidden":{}}';
  if (sysopen(my $input, "$base/preferences.json", O_RDONLY | O_NONBLOCK | O_NOFOLLOW)) {
    my @st = stat($input);
    die "Refused preferences file\n" unless -f $input && $st[7] <= $cap;
    $raw = '';
    while (length($raw) <= $cap) {
      my $n = sysread($input, $raw, 65536, length($raw));
      die "Read: $!\n" unless defined $n;
      last if $n == 0;
    }
    die "Preferences too large\n" if length($raw) > $cap;
    close($input);
  } else { die "Refused preferences file: $!\n" unless $!{ENOENT}; }

  pipe(my $read_input, my $write_input) or die "Pipe: $!\n";
  pipe(my $read_output, my $write_output) or die "Pipe: $!\n";
  my $pid = fork();
  die "Fork: $!\n" unless defined $pid;
  if ($pid == 0) {
    open(STDIN, '<&', $read_input) or die "Input: $!\n";
    open(STDOUT, '>&', $write_output) or die "Output: $!\n";
    close($write_input); close($read_output); close($read_input); close($write_output);
    exec('jq', '-scea', '--arg', 'action', $action, '--arg', 'name', $name // '',
      '--arg', 'value', $value // '', '--arg', 'background', $background // '',
      'if length == 1 then .[0] else error("Expected one JSON value") end | ' . $validate . ' | ' . $change);
    die "jq: $!\n";
  }
  close($read_input); close($write_output);
  print {$write_input} $raw or die "Write pipe: $!\n";
  close($write_input);
  my $result = '';
  while (length($result) <= $cap) {
    my $n = sysread($read_output, $result, 65536, length($result));
    die "Read pipe: $!\n" unless defined $n;
    last if $n == 0;
  }
  if (length($result) > $cap) { kill 9, $pid; waitpid($pid, 0); die "Preferences too large\n"; }
  close($read_output);
  waitpid($pid, 0);
  die "Invalid preferences\n" unless $? == 0 && length($result);
  if ($action ne 'read') {
    $temporary = "$base/.preferences-$$-" . int(rand(2**32));
    sysopen(my $output, $temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600) or die "Create: $!\n";
    print {$output} $result or die "Write: $!\n";
    $output->sync or die "Sync: $!\n";
    close($output) or die "Close: $!\n";
    rename($temporary, "$base/preferences.json") or die "Replace: $!\n";
    undef $temporary;
    $directory->sync or die "Sync directory: $!\n";
  }
  print $result;
  1;
} or do {
  my $error = $@ || 'Unknown failure';
  unlink($temporary) if defined $temporary;
  print STDERR "swatch preferences: $error";
  exit 1;
};
PERL
