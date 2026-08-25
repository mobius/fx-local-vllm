# GitHub publication architecture

```text
fx-win (GitHub: mobius/fx-local-vllm)
  ├─ Windows fx source and build
  ├─ fx adapter and gateway fixtures
  └─ produces zig-out/bin/fx.exe

microharness (separate Git repository)
  └─ GFXR replay, Mali guidance, experiments, and evaluation docs
```

The fx-win GitHub version is the provider-side repository; microharness consumes its Windows binary through an explicit path.
