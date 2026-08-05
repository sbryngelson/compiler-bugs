# NOTE (not an upstream bug) — AFAR 23.2.1 cannot compile user-defined reductions

**Status:** informational, for MFC. Do not file upstream: upstream flang handles both forms
correctly, so this is AFAR version lag (AFAR is LLVM 23, upstream is 24).

`!$omp declare reduction` fails on AFAR 23.2.1 in both scopes, and works upstream:

| where the UDR is declared | AFAR 23.2.1 | upstream flang |
|---|---|---|
| in a module, used in a program | `error: Invalid reduction identifier in REDUCTION clause.` | PASS |
| in the same scope as its use | `error: 'omp.declare_reduction' op expects initializer region to yield a value of the reduction type` | PASS |

Reproducer: `redhunt/src2/udr_n64.f90` (module form) and the same-scope variant.

Practical consequence: MFC cannot use `declare reduction` on the AFAR toolchain today. Either avoid
UDRs there, or express the reduction with built-in operators.

Worth re-testing when a newer AFAR drop lands, since the fix is presumably already upstream.
