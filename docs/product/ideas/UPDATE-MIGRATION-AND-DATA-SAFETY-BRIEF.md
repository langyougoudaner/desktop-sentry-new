# Desktop Sentry 更新、迁移与数据安全简报

- Status: CONFIRMED SAFETY BASELINE — AWAITING REMAINING PRODUCT POINTS
- Owner: product discussion
- Created: 2026-08-22
- Scope: version upgrade, installation switch, historical data compatibility, rollback
- Execution: not authorized by this brief

## User outcome

用户希望 Desktop Sentry 完成第二版后能够更新现有安装，同时保留第一版已经积累的个人数据。如果新版无法可靠读取并验证这些数据，第一版不得退出或被替换。

已经明确：

- 旧普通待办不导入新的日历待办；未来日历待办由用户重新创建。
- 不导入日历不等于删除旧待办。旧任务仍须保留在原始数据或完整备份中，确保可回退第一版。
- 除旧待办以外的用户数据必须延续，包括提示词、固定 / 快捷提示词状态、Skill 索引与扫描目录、Skill 收藏和分类、设置以及其他本地状态。
- 升级必须先完成数据识别、备份、迁移演练和验证，再退出第一版并切换新版。
- 新版启动或迁移验证失败时，自动恢复旧应用与旧数据，而不是让用户面对空白新版。
- 用户再次确认：不得丢失原数据；不得退出第一版后因新版打不开而让全部内容暂时不可用。这两条是部署硬闸门，不是尽力目标。

## Current read-only baseline — 2026-08-22

- `/Applications/DesktopSentry.app` 仍为 `1.1.0 build 11`，本轮没有覆盖、退出或替换。
- 当前日历 V2.1 是隔离源码预览，初始化时跳过真实存储，因此不显示历史数据；这不是正式迁移结果。
- 主数据路径：`~/Library/Application Support/DesktopSentry/data.json`。
- 当前只读计数：2 个旧任务、20 条提示词、234 个 Skill、5 个 Skill 扫描目录、1 个收藏 Skill、1 个快捷菜单提示词、1 个常驻提示词、10 条复制历史。
- 数据目录约 160 KB；已安装应用约 2.4 MB。
- 数据目录还存在两份 `data.corrupt.*.json` 恢复文件，必须保留，不得清理或覆盖。

这些计数只是 2026-08-22 的现场快照；正式升级应在切换前重新获取，不得把此处数字硬编码成迁移条件。

## Critical risk in the current loader

当前 `StorageManager` 在 `data.json` 解码失败时会：

1. 把原文件移动成 `data.corrupt.<timestamp>.json`；
2. 立即在主路径写入默认数据；
3. 让应用继续以默认内容启动。

这虽然保留了一个恢复副本，却会让用户看到“数据全没了”的新版。正式升级前必须改变这一语义：迁移或解码失败应中止版本切换、保留原文件、说明失败并继续运行 / 恢复第一版，不能自动把默认数据当作成功升级。

## Two meanings of automatic update

### Recommended now — controlled local upgrade

面向这台 Mac 的第二版升级流程：

1. 构建并验证源码产物，但不碰已安装第一版。
2. 复制备份 `/Applications/DesktopSentry.app` 与整个 `~/Library/Application Support/DesktopSentry/`。
3. 只在备份数据副本上运行 V1 → V2 迁移演练。
4. 验证提示词、Skill、目录、收藏 / 分类、设置、固定状态和复制历史的数量、标识与关键关系。
5. 演练完全通过后，才请求用户针对本次安装目标的部署批准。
6. 退出第一版，原子替换应用包，启动第二版。
7. 重新验证真实数据与核心操作。
8. 任一步失败，恢复旧应用和旧数据，并重新启动第一版。

这能满足当前“写完后安全升级”的需求，不需要先建立公开下载服务器。

### Separate future capability — in-app online updater

应用自己联网检查、下载并安装新版本，还需要：

- 可信更新源 / 托管地址；
- 更新清单和版本策略；
- 下载包签名与校验；
- Developer ID、Hardened Runtime 和 notarization，或另一套经过审计的私有签名模型；
- 失败回退、跳过版本、延迟更新和网络隐私说明；
- 发布密钥保护和密钥轮换方案。

当前项目没有 GitHub remote，构建是 ad-hoc 签名，也没有网络服务。因此不能把“联网自动更新”伪装成已经可安全交付的小功能。

## Proposed V1 → V2 data contract

### Must migrate and verify

- 提示词：标题、内容、缩写、分组、顺序、常驻状态。
- 快捷提示词：选中项及顺序。
- Skill：索引项、来源、收藏、分类和自定义扫描目录。
- Skill 升级行为：先继承旧元数据，再重新扫描并按稳定身份合并；重新扫描不得无声清空收藏或分类。
- 设置：菜单栏文字长度、声音、开机启动偏好、复制后切换、标题显示选项等。
- 复制历史：默认随其他本地数据迁移；仍只保存在本机。
- 任何未来独立数据文件：使用明确 `schemaVersion` 和兼容迁移器。

### Old todos

- 不导入新日历任务库，不自动补日期。
- 升级时不得把旧 `tasks` 写成空数组后覆盖唯一原件。
- 第一版备份和 V1 数据快照中完整保留旧任务；第二版可暂时把它们视为 legacy 数据而不展示。

### New calendar data

- 新日历待办 / 倒数日使用独立、版本化存储，不把唯一副本塞回会被旧版重写的主 `data.json`。
- 文件缺失表示“尚未创建”，不表示迁移失败。

## Migration safety rules

- 每次迁移都是幂等的：重复运行不会复制、丢失或重排数据。
- 先在副本上 dry-run，验证成功后再切换。
- 迁移前后记录结构化计数与关系检查，不在日志、截图或仓库公开提示词内容和本地 Skill 路径。
- 写入采用新文件 + 原子切换；旧文件和备份在用户确认新版稳定前保留。
- 遇到未知的更高 schema 版本时拒绝降级写入，不能用旧程序覆盖新数据。
- 应用包升级与数据迁移是同一事务的两个阶段；任何阶段失败都回到第一版可用状态。

## Acceptance criteria

- 在完全不退出第一版的情况下，用真实数据副本完成迁移演练。
- 旧普通待办没有进入新日历，但仍存在于可恢复的 V1 数据中。
- 20 条提示词、Skill 元数据与扫描目录、收藏 / 分类、固定和快捷状态、设置及复制历史在升级副本上逐项验证；正式执行时以当时最新计数为准。
- 新版启动后随机抽查提示词可复制、固定提示词正确、Skill 可搜索、收藏和分类未丢失。
- 新版或迁移失败时，旧应用和旧数据能够自动恢复，第一版重新可用。
- 未经单独部署批准，不退出或覆盖 `/Applications/DesktopSentry.app`，不修改登录项。

## Pending discussion

- 用户所说的“自动更新”最终是：当前 Mac 上由执行流程自动安全部署，还是应用未来自行联网更新；建议先完成前者，后者作为单独发布能力。
- 等待用户继续提供剩余两到三个产品修改点，再判断是否与版本迁移合并成一个正式规格。
