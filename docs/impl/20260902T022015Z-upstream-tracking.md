# fx-win 上游持续跟踪实施记录

执行：

```text
git fetch upstream --prune
git rev-list --count HEAD..upstream/main
git log --first-parent HEAD..upstream/main
git merge-tree --write-tree --name-only --no-messages HEAD upstream/main
```

实际结果：

```text
upstream/main = dd7179f3
HEAD..upstream/main = 302 commits
merge preview conflicts = 5 paths
```

当前 `fx-win` 的 `origin/main` 仍为 `004afb6`，工作树干净。上游更新尚未进入
本地产品分支。
