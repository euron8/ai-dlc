#!/usr/bin/env bash
# wfd-start-of.sh -- a process's start time: the half of a pid's identity that a recycled pid
# does not share.
#
# Usage:  . wfd-start-of.sh           defines wfd_start_of, runs nothing
#         wfd-start-of.sh <pid>       prints <pid>'s start time
# Output: `ps -o lstart=` under LC_ALL=C; when `ps` prints nothing (a sandbox refuses the setuid
#         /bin/ps), the stock perl reads the same kernel field on macOS and prints it with
#         localtime, which is the same text. Whitespace-normalised to single spaces with no
#         leading or trailing blank. EMPTY when the pid does not exist or neither source can
#         read it (no ps output, and no perl or not darwin).
#
# ONE DEFINITION, TWO READERS. wait-for-deliverable.sh writes this value into a beat's argv
# record (`.wait-beats/.beat-argv-<pid>`, line `start=`) and compares it for its chained-beat
# guard; core/hooks/ai-dlc-hookwake.sh compares the record's value against a fresh read of the
# same pid. The two must produce the same bytes for the same live process, so both source THIS
# file -- each from its own directory, which install.sh fills from core/scripts/ as
# scripts/ai-dlc/ in a consumer, never by counting `..` hops.
#
# LC_ALL=C because `lstart` is locale-formatted: two callers under different locales would
# render one start time two ways and read a live beat as a recycled pid. It also makes `ps` and
# the perl fallback agree: a value written through one source must read equal through the other.
#
# THE SECOND SOURCE (BL-686). `/bin/ps` is setuid root and `sandbox-exec` refuses to exec it, so
# under a sandboxed harness `ps` prints nothing. perl then reads kinfo_proc p_starttime via sysctl
# KERN_PROC_PID and prints it with localtime -- `ps -o lstart=` word for word under LC_ALL=C in
# the same zone. macOS only ($^O); elsewhere, or for a dead pid, it prints nothing. perl is
# optional: without it the answer is empty and wait-for-deliverable.sh says so on stderr.
#
# wait-for-deliverable.sh carries a fallback copy of this whole definition for a lone copy of
# itself with no sibling; core/fixtures/wait-beat-liveness binds the two `^wfd_start_of() {` ..
# `^}` ranges byte-identical.

wfd_start_of() {  # $1 = pid -> its start time, whitespace-normalised; empty when it cannot be read
  ss_="$(LC_ALL=C ps -o lstart= -p "$1" 2>/dev/null)" || ss_=""
  [ -n "$ss_" ] || ss_="$(perl -e 'exit 1 unless $^O eq "darwin" && $ARGV[0] =~ /^[1-9][0-9]*$/; my $m = pack("i4", 1, 14, 1, $ARGV[0]); my $b = "\0" x 1024; my $l = pack("Q", 1024); syscall(202, $m, 4, $b, $l, 0, 0) == 0 or exit 1; my ($s) = unpack("q", $b); exit 1 unless unpack("Q", $l) > 0 && $s > 0; print scalar localtime $s' "$1" 2>/dev/null)" || ss_=""
  printf '%s' "$ss_" | tr -s ' \t' ' ' | sed 's/^ //; s/ $//'
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  [ $# -eq 1 ] || { echo "usage: wfd-start-of.sh <pid>" >&2; exit 64; }
  wfd_start_of "$1"
fi
