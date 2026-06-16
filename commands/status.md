---
description: 打印当前分支研究状态仪表盘(只读, 零副作用)
---

# /research-loop:status

打印 `.research/DASHBOARD.md` 的完整内容, 无任何副作用.

## 前置条件

- 当前目录是 git 仓库
- `.research/DASHBOARD.md` 存在

## 执行

1. 检测 `.research/DASHBOARD.md`
2. 若不存在, 输出: "当前分支无进行中的研究. 用 /research-loop:init <idea文件> 初始化."
3. 若存在, 读取并打印全文

## 示例

```
$ /research-loop:status

# Research Dashboard

**IDEA**: 测试 VLA 是否能读懂指令细节
**Active**: 2 hypotheses | **Last**: 2026-06-15

## Active Hypotheses
- H1: VLA 对指令中的否定词不敏感 (待验)
- H1.1: 增加 instruction token 权重能提升敏感度 (待验)

## Next Steps
1. 设计 H1 的判别实验(对比 baseline vs 加否定指令的 success rate)
```
