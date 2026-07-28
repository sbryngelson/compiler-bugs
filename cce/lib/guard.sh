# shellcheck shell=bash
#
# Shared environment guard for the cce/ reproducers.  Source it; do not execute it.
#
#   . "$(dirname "$0")/../lib/guard.sh"
#   guard_ftn 21.0.2
#   guard_accel
#
# Why this exists
# ---------------
# Every reproducer here can silently produce a FALSE NEGATIVE.  The usual cause is
# the module recipe: on Frontier
#
#   module load cpe/26.03 cce/21.0.2 rocm/7.2.0 craype-accel-amd-gfx90a
#
# *appears* to work and does not.  `ftn` keeps dispatching the system default CCE
# (18.0.1) with no accelerator target, so `-hacc` / `-homp` are ignored, the
# reproducer is built as HOST code, and it prints PASS -- indistinguishable from a
# fixed compiler.  Loading order matters: `module reset`, then cpe, then an
# explicit `module swap cce`.
#
# These functions VERIFY; they never load modules.  A wrong environment is a hard
# error with the fix printed, never a silently different measurement.

guard_fatal() {
    printf '\n\033[1;31mFATAL:\033[0m %s\n' "$1" >&2
    shift
    for line in "$@"; do printf '       %s\n' "$line" >&2; done
    printf '\n' >&2
    exit 1
}

guard_note() { printf '  \033[1;32mok\033[0m  %s\n' "$1"; }

# guard_ftn <version> -- require `ftn` to actually dispatch that CCE.
guard_ftn() {
    local want=$1 got
    command -v ftn >/dev/null 2>&1 || guard_fatal \
        "ftn is not on PATH." \
        "This needs a Cray PE environment (a Frontier login or compute node)."
    got=$(ftn --version 2>&1 | grep -oE 'Version [0-9.]+' | head -1 | cut -d' ' -f2)
    [ -n "$got" ] || guard_fatal "could not parse 'ftn --version'." "Got: $(ftn --version 2>&1 | head -1)"
    if [ "$got" != "$want" ]; then
        guard_fatal "ftn dispatches CCE $got, but this reproducer needs $want." \
            "A bare 'module load cce/$want' reports success and changes nothing." \
            "Use:" \
            "    module reset" \
            "    module load cpe/$(guard_cpe_for "$want") rocm/$(guard_rocm_for "$want") craype-accel-amd-gfx90a" \
            "    module swap cce cce/$want"
    fi
    guard_note "ftn is CCE $got"
}

# guard_accel -- require the gfx90a offload target to be active.
# Without it, ftn ignores -hacc/-homp (ftn-1350) and silently builds host code.
guard_accel() {
    local banner
    banner=$(ftn --version 2>&1)
    if ! grep -q 'amdgcn-gfx90a' <<<"$banner"; then
        guard_fatal "no accelerator target -- ftn would ignore -hacc / -homp." \
            "'ftn --version' reports: $(grep -i 'Target is' <<<"$banner" || echo '(no Target line at all)')" \
            "Offload directives would be silently dropped with ftn-1350 and the" \
            "reproducer would build as HOST code and print PASS." \
            "Fix:  module load craype-accel-amd-gfx90a"
    fi
    [ -n "${CRAY_ACCEL_TARGET:-}" ] || guard_fatal \
        "CRAY_ACCEL_TARGET is unset even though the ftn banner names gfx90a." \
        "Load craype-accel-amd-gfx90a rather than setting flags by hand."
    guard_note "accel target is $CRAY_ACCEL_TARGET"
}

# guard_llc <version> -- require that CCE's own llc/lld exist.
# Sets GUARD_BIN to the toolchain bin dir (a global, not stdout, so that the
# progress note and the path cannot be captured together by mistake).
GUARD_BIN=
guard_llc() {
    local want=$1 dir="/opt/cray/pe/cce/$1/cce-clang/x86_64/bin"
    [ -x "$dir/llc" ] || guard_fatal \
        "CCE $want's llc is not installed at $dir/llc." \
        "Installed CCEs: $(ls -d /opt/cray/pe/cce/*/ 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"
    guard_note "CCE $want llc, $("$dir/llc" --version | grep -oE 'based on LLVM version [0-9.]+' | head -1)"
    GUARD_BIN=$dir
}

# guard_device_image <binary> -- prove the binary really contains GPU code.
#
# The strongest check available: even if every environment heuristic were fooled,
# a host-only build has no embedded AMDGPU ELF.  Such a build runs happily and
# prints PASS, so this is what stands between a false negative and a real result.
guard_device_image() {
    local bin=$1 helper
    helper="$(dirname "${BASH_SOURCE[0]}")/extract-device-image.py"
    [ -f "$bin" ] || guard_fatal "no such binary: $bin"
    if ! python3 "$helper" "$bin" /dev/null >/dev/null 2>&1; then
        guard_fatal "$(basename "$bin") contains NO AMDGPU device image -- it is a HOST-ONLY build." \
            "It will run, and it will print PASS, and that PASS means nothing." \
            "The offload directives were dropped at compile time; re-check the module" \
            "environment (see the header of cce/lib/guard.sh)."
    fi
    guard_note "$(basename "$bin") carries a device image"
}

# guard_cpe_for / guard_rocm_for -- the matching module versions per CCE.
guard_cpe_for() {
    case $1 in
        19.0.0) echo 25.03 ;; 20.0.0|20.0.2) echo 25.09 ;;
        21.0.0|21.0.2) echo 26.03 ;; *) echo '<matching-cpe>' ;;
    esac
}
guard_rocm_for() {
    case $1 in
        19.0.0) echo 6.3.1 ;; 20.0.0|20.0.2) echo 6.4.2 ;;
        21.0.0|21.0.2) echo 7.2.0 ;; *) echo '<compatible-rocm>' ;;
    esac
}

# guard_verdict <expected> <actual> <label> -- record and compare one outcome.
# Sets GUARD_RC=1 on mismatch so a script can exit nonzero at the end.
GUARD_RC=0
guard_verdict() {
    local want=$1 got=$2 label=$3
    if [ "$want" = "$got" ]; then
        printf '  \033[1;32m%-16s\033[0m %s (got: %s)\n' "AS DOCUMENTED" "$label" "$got"
    else
        printf '  \033[1;31m%-16s\033[0m %s (expected: %s, got: %s)\n' "MISMATCH" "$label" "$want" "$got"
        GUARD_RC=1
    fi
}
