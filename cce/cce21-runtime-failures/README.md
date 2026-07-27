# CCE 21.0.2: MFC links but 21 tests fail at runtime on Frontier (MI250X)

**Status: OBSERVED, ATTRIBUTION PENDING. Do not cite these as CCE 21 defects yet — the
CCE 19.0.0 control run has not completed, and Frontier's GPU CI lane is already
`continue-on-error` because it has been failing for other reasons.**

## Context

With the AGPR device-LTO crash worked around (see [`../lld-agpr-mfma-assert`](../lld-agpr-mfma-assert)),
CCE 21.0.2 became the first CCE newer than 19.0.0 to *link* MFC. It links under both
offload backends, with and without MPI. The binaries then fail 21 tests at runtime.

| lane | 10% sample | multi-rank (8 tests) |
|---|---|---|
| `--gpu mp` (OpenMP target offload) | rc=143 | 6/8 — fails `AFBACA70`, `0090B316` |
| `--gpu acc` (OpenACC) | rc=13 | 6/8 — fails `AFBACA70`, `0090B316` |

Both backends fail the **same** two multi-rank tests. OpenMP-offload and OpenACC share very
little directive-lowering, so identical failures point at shared device codegen or at a
pre-existing MFC/Frontier problem — not at a backend-specific bug.

## Failure clusters

### 1. IBM — 10 tests, hard crashes (most serious)

```
18B832DD  3D -> 2 Fluid(s) -> Viscous -> IBM -> Cuboid          segfault 139
32DD0363  3D -> 1 Fluid(s) -> Viscous -> IBM -> Cuboid -> slip  failed to execute
5173E637  3D -> 1 Fluid(s) -> IBM -> Cylinder -> slip
A1B2B963  3D -> 1 Fluid(s) -> Viscous -> IBM -> Sphere -> slip
AFBACA70  3D -> 2 MPI Ranks -> IBM Sphere
B0CE19C5  2D -> 1 Fluid(s) -> Viscous -> IBM -> model_eqns=3
BFAA7587  3D -> 2 Fluid(s) -> Viscous -> IBM -> Cylinder -> slip
D1C97CD1  3D -> 1 Fluid(s) -> IBM -> Cylinder                   segfault 139
6076815B  3D -> Example -> rotating_sphere
AA49A8BC  3D -> Example -> mibm_sphere_head_on_collision
```

These are `Segmentation fault (core dumped)`, exit 139 — not tolerance drift.

### 2. QBMM — 3 tests, runtime diagnostic

```
0501B3DA  1D -> Viscosity -> Bubbles -> QBMM -> bubble_model=3 -> cfl_adap_dt=T
6784C02E  1D -> Viscosity -> Bubbles -> QBMM
83291843  2D -> Viscosity -> Bubbles -> QBMM -> bubble_model=3
```

All three emit:

```
OpenMP Execution Error: src/simulation/m_qbmm.fpp:984 -
  unsupported access to Fortran host-associated variable in GPU internal procedure
```

Investigation so far (line numbers are `.fpp`, via fypp `--line-numbering`):

- `m_qbmm.fpp:984` is `call s_hyqmom(myrho, up, M1)` inside `s_chyqmom`.
- Both `s_chyqmom` (949) and `s_hyqmom` (1008) are **internal procedures** contained in
  `s_mom_inv` (`contains` at 928), each marked `GPU_ROUTINE(..., cray_inline=True)`.
- Ruled out as the host-associated entity: `sgm_eps` (`m_constants.fpp:12`), `nmom`
  (`simulation/m_global_parameters.fpp:241`) and `nnode` (`m_constants.fpp:39`) are all
  **`parameter`s** — compile-time constants, not data requiring device residency.
- Every array at line 984 (`myrho`, `up`, `M1`, ...) is declared local to `s_chyqmom`.

What remains is the **sibling internal-procedure call itself**: `s_chyqmom` reaches
`s_hyqmom` by host association, and `cray_inline=True` inlines it at exactly line 984,
which is why the diagnostic points there. If confirmed, the MFC-side fix is to lift both
routines to module scope — a portability improvement independent of which compiler ships.
**Unverified.**

### 3. Tolerance — 5 tests, at least one near-zero

```
0090B316  MPI Consistency -> 3D -> Viscous
2A6136EF  1D -> 2 Fluid(s) -> Viscous -> weno_Re_flux -> weno_avg
CD6DC908  2D -> 1 Fluid(s) -> Viscous
5304E59F  2D -> Example -> poiseuille_thickening_nn
986BC1A2  2D -> Example -> richtmyer_meshkov
```

`0090B316` compares two numbers that are both essentially zero:

```
Candidate: 2.802e-11   Golden: 5.538e-11
Error:     abs 2.74E-11, rel 4.94E-01
Tolerance: abs 1.00E-12, rel 1.00E-12
```

A 49% *relative* error on values of order 1e-11, in a double-precision field of O(1), is
roundoff. Floating-point reassociation differences between compilers reproduce this
exactly. Treat as suspect-benign pending the control.

### 4. Lagrange bubbles — 2 tests; chemistry — 1

```
7854BA64  2D -> Lagrange Bubbles -> One-way Coupling -> Inertial Bubbles
80CC6F73  3D -> Lagrange Bubbles -> Two-way Coupling -> ... fd_order=1   (tolerance)
0A62F0A6  nD -> Example -> perfect_reactor                               (failed to execute)
```

The Lagrange tests are the only failing tests that touch a kernel modified by the AGPR
workaround (`m_bubbles_EL.fpp:633`). Note the EL edit is very likely a **no-op**: that
kernel already compiles at `amdgpu-flat-work-group-size="1,1024"` naturally, so
`thread_limit(1024)` requests what it already had. Confirm before blaming the workaround.

## Why attribution is not yet possible

`.github/workflows/test.yml:333` makes every Frontier lane `continue-on-error`, with the
comment that *"cpe/25.03 introduced an IPA SIGSEGV in CCE 19.0.0"*. In MFC
[#1679](https://github.com/MFlowCode/MFC/pull/1679) all 11 multi-rank tests NaN'd on
Frontier GPU. So the Frontier GPU lane is a known-bad baseline, and an unknown fraction of
the 21 failures above may predate CCE 21 entirely.

The control that settles it: **identical source tree, only `toolchain/modules` reverted to
`cpe/25.03 cce/19.0.0 rocm/6.3.1`**, running the same 10% sample, the same 8 multi-rank
tests, plus targeted repeats of `CD6DC908`, `18B832DD`, `D1C97CD1`. Script in
`artifacts/job_base.sh`. Not yet completed at time of writing.

## Reproducing

```bash
git clone https://github.com/MFlowCode/MFC && cd MFC
# toolchain/modules, Frontier line: cpe/26.03 cce/21.0.2 rocm/7.2.0
# and drop rocprofiler-compute from f-gpu (it silently reverts PrgEnv to cce/18.0.1)
# apply the AGPR workaround so it links (see ../lld-agpr-mfma-assert)
source ./mfc.sh load -c f -m g
./mfc.sh test --dry-run -a -j 8 --gpu mp --mpi     # or --gpu acc
./mfc.sh test --no-build -a -j 8 -% 10 --gpu mp --mpi -- -c frontier
```

`artifacts/cce21_mp_failures.txt` and `artifacts/cce21_acc_failures.txt` hold the raw
failure output from both lanes.

## Environment trap worth knowing

MFC serializes every `uv pip install` on a machine through one global lock,
`/tmp/mfc-uv-install-<user>.lock`. A wedged install blocks **all** concurrent MFC builds for
that user, across unrelated worktrees. Separately, Frontier compute nodes have **no route to
PyPI**, so the venv must be primed on a login node first; setting a fresh `UV_CACHE_DIR` for
a batch job guarantees failure there. Both cost significant time during this investigation.
