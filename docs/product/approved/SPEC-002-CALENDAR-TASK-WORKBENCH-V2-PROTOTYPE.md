# SPEC-002 - 日历任务工作台 V2 可操作原型

- Status: SUPERSEDED FOR EXECUTION BY SPEC-003
- Owner: product discussion
- Created: 2026-08-21
- Approved by: user
- Approval date: 2026-08-21
- Source candidate: `docs/product/ideas/CALENDAR-TASK-WORKBENCH-V2.md`
- Interaction blueprint: `docs/product/ideas/CALENDAR-TASK-WORKBENCH-V2-INTERACTION-BLUEPRINT.md`
- Benchmark research: `docs/product/ideas/CALENDAR-BENCHMARK-RESEARCH.md`

> 2026-08-21 pause notice: the user explicitly rejected the current Phase 1/2
> implementation for its duplicate black title bar, inverted column emphasis,
> excessive empty space, low-contrast gray presentation, clipped date/time
> controls, and unusable countdown-add validation. This specification must not
> authorize further execution until a replacement visual/interaction direction
> is explicitly approved. Existing source and evidence remain preserved.
> The replacement direction was approved later on 2026-08-21 as
> `SPEC-003-CALENDAR-WORKBENCH-V2-1-VISUAL-RESET.md`. No further work may use
> this document alone as execution authority.

## Problem and desired outcome

首轮 Deadline 面板虽然实现了数据、筛选和通知骨架，但把用户希望的一体化“看日历 + 管理任务”工作台降级成了一个视觉与交互都过于基础的 Deadline 列表。普通待办入口不明显，日期点击与窗口拖动冲突，关闭方式不符合习惯，缺少正常 macOS App 的反馈与动效；整块深灰、厚重卡片和大量胶囊筛选也同时偏离 Desktop Sentry 现有界面与用户提供的浮引日历参考。

本规格只授权制作一个完全隔离数据的 V2 可操作原型。用户打开原型后，应立即同时看到完整月历和右侧任务区，并能以最少点击完成待办新增、倒数日新增、日期过滤、模式切换、完成和排序。视觉应明显属于 Desktop Sentry，同时达到浮引日历所体现的轻盈、清楚和完整，而不是继续修补旧 V1。

## Evidence and assumptions

- 用户明确批准 `CALENDAR-TASK-WORKBENCH-V2-INTERACTION-BLUEPRINT.md`，并明确拒绝旧 V1 的视觉语言。
- 用户确认首个 V2 原型只显示农历与传统节日，不显示二十四节气。
- 用户确认页面必须始终保持左月历、右任务区双栏，不能为了管理任务再进入二级页面或展开右栏。
- 用户确认 Apple 提醒事项暂不阻塞本地工作台，只在架构上保留未来接口。
- 用户对动效的目标是接近正常 macOS App：选中变色并有轻微弹动，打开轻微放大淡入，关闭轻微缩小淡出；不要求自行定义精确参数。
- Desktop Sentry 当前搜索面板的稳定视觉基底是系统 `.popover` 材质、系统字体、轻边框、系统蓝强调、约 13pt 圆角和低透明度选中底色。
- 用户提供的浮引参考以大公历、小农历、左大右小双栏、浅层卡片、蓝色主选中和清楚顶部控制形成完整秩序。
- 旧 V1 视觉候选保存在 `docs/product/approved/evidence/SPEC-001-visual-correction-main.png`，只作为被拒绝证据，不作为 V2 设计起点。
- 当前工作区包含首轮实现的未提交代码与证据，均须保留；本规格不授权删除、回退或覆盖历史原型。

## Options considered

### Approved option - isolated native interactive prototype

在源码构建中增加一个仅由明确预览启动参数或等价隔离入口触发的 V2 原型。原型使用内存样例，不读写真实任务、Deadline 或系统提醒事项；先验证信息架构、视觉、窗口行为、点击预算和动效，再讨论真实集成。

### Alternative - continue polishing V1

改颜色、间距和圆角的成本较低，但 V1 的问题是产品模型、入口和手势结构错误，不是表面样式。此方案已被用户明确否定。

### Alternative - immediately connect full data and notifications

可以更快得到功能完整版本，但会在视觉和交互尚未验收前扩大数据迁移、通知和回归风险，并可能再次把原型缺陷固化进正式路径。本轮不采用。

### Doing nothing

保留首轮代码但不再推进。没有新增风险，但无法获得可用于真实判断的 V2 交互证据。

## Approved scope

### 1. Prototype isolation

- 新增 V2 预览入口，例如 `--calendar-workbench-v2-preview`；具体命名可由执行主线调整并记录。
- 预览只能使用独立内存样例，不读取或写入真实 `data.json`、`deadlines.json`、用户设置、复制历史或系统提醒事项。
- 预览不得安排真实通知、请求 Apple 权限、修改登录项或触发同步。
- 正常启动 Desktop Sentry 时，现有生产行为不得因为原型而改变。

### 2. Fixed two-column workbench

- 左侧完整月历与右侧任务工作区始终同时存在；右栏不可收起或隐藏。
- 首次默认进入“待办”，以后原型可在内存会话内记住上一次“待办 / 倒数日”选择；不得写入真实设置。
- 右侧顶部提供“倒数日 / 待办”一级切换，只替换右栏内容，不改变月历月份和选中日期。
- 左侧是主要视觉区域，右侧保持可直接显示 3–6 条项目的宽度；建议接近参考产品约二比一的视觉权重，但允许在原型中调整以达到最佳密度。

### 3. Calendar content

- 显示公历、农历和传统节日；不显示二十四节气。
- 顶部提供上月、年月、下月和“今天”。
- 今天与选中日期可同时辨认，不能只靠同一个蓝圈表达两种状态。
- 有项目的日期显示克制点位或数量；不把完整标题塞入日期格。
- 单击日期只选择并过滤右栏，绝不移动窗口。

### 4. Todo and countdown flows

- “待办”模式顶部始终显示 `添加待办，回车确认`；一次鼠标点击聚焦，输入后 Return 新增。
- 选择日期后新增待办应预填日期；无日期待办仍可创建，并在“全部待办”范围出现。
- “倒数日”模式顶部始终显示 `添加倒数日`；单击后在右栏原位展开标题、日期以及可展开的时间 / 通知字段。
- 行首完成圆圈、标题栏内编辑、行尾更多菜单和专用排序手柄各自有清楚职责。
- 只有排序手柄能重排项目；日期、输入框、行本身和窗口背景不得误触发排序。
- 完成后提供短暂撤销入口；原型撤销只修改内存状态。

### 5. Window behavior

- 原型从菜单栏日历入口附近出现；若预览启动方式无法可靠锚定，可在当前屏幕合理居中，并记录为原型偏差。
- 禁止设置整个内容背景可拖动。若使用独立窗口，只允许从明确顶部空白区移动，并使用 macOS 熟悉的关闭路径。
- 若使用菜单栏浮层，支持再次点击入口与 `Esc` 关闭；编辑中是否允许点击外部关闭必须在原型中避免数据突然消失的困惑。
- 支持 `Command-W`；不得在两栏分隔线附近放孤立关闭叉。
- 具体选择独立窗口或可保持编辑状态的浮层，由执行主线基于真实原型推荐并记录，不得把两套窗口模型混在一起。

### 6. Motion and feedback

- 整体以正常 macOS App 的系统手感为目标，不设计独立炫技动画语言。
- 打开从入口附近轻微放大并淡入；关闭沿原路径轻微缩小并淡出。
- 按钮、日期、模式切换和完成圆圈按下时立即反馈；选中使用系统强调色平滑变色，并允许很轻的系统式弹动。
- 月份切换有方向一致的短促过渡；新增从输入位置进入列表；完成先确认状态，再平滑进入完成区域。
- 轻微弹动只用于按压、选中、插入和拖动落位。禁止夸张回弹、持续晃动、循环动画、彩纸或移动整个页面。
- 动画可被连续操作打断，不排队、不锁界面；减少动态效果开启时改为短促交叉淡化并保留颜色反馈。
- 优先使用 SwiftUI / AppKit 系统动画语义；具体参数由执行主线对照真实 macOS 系统 App 微调并记录。

### 7. Visual language

V2 必须同时满足“属于 Desktop Sentry”和“达到浮引日历的完整、轻盈层级”：

- 延续 Desktop Sentry：系统字体、单层原生玻璃、轻微顶光边框、系统蓝强调色、紧凑按压 / hover 反馈和有限语义色。
- 借鉴浮引：大公历日号、小农历文字、传统节日标签、左大右小双栏比例、清楚的顶部控制秩序、浅层任务行卡和有效留白。
- 浅色系统外观下应轻、亮、通透但可读；深色外观下使用系统材质自然适配，不能退化为一整块没有层次的死灰。
- 日期主数字应成为月历视觉主角；农历次级但可读；传统节日以克制红 / 橙标签表达，普通选择和主要操作仍使用系统蓝。
- 右栏列表行可以有轻微圆角和浅层背景，但不能每行都形成厚重不透明灰砖；只有选中、逾期或重点状态才提高对比。
- 一级“倒数日 / 待办”采用一个清楚的系统式分段控制；过滤与分类使用次级文字标签或菜单，不再堆出五个同等重量的胶囊。
- 新增入口必须融入右栏顶部秩序，不能成为孤立大蓝按钮，也不能藏在不可发现的菜单里。
- 圆角、间距、阴影和材料强度应形成一个统一层级；禁止 SwiftUI 与 AppKit 重复叠加玻璃。
- 禁止继承旧 V1 的整块深灰、厚重灰卡、橙色粗描边、满排胶囊、角落小月历和分隔线关闭叉。
- 不逐像素复制浮引，不使用其品牌、专有图标、文案、素材或代码。

## Non-goals

- 真实任务或 Deadline 数据读写、迁移和兼容性改造。
- 真实本地通知、通知权限和声音验证。
- Apple Calendar / Reminders 访问、权限、同步或冲突处理。
- 二十四节气、法定放假 / 调休数据、在线节日更新。
- 钉到桌面、WidgetKit 小组件、iCloud 或跨设备同步。
- 安装到 `/Applications`、修改登录项、升级版本号、发布或创建远程仓库。
- 删除、回退、覆盖或清理首轮代码、测试、截图与历史规格。

## Affected modules and invariants

执行主线可根据当前结构选择最小原型边界，预计涉及：

- 新的 V2 SwiftUI 原型视图和仅内存的预览模型；
- `AppCoordinator` 或等价启动路由，仅识别明确预览参数；
- `PanelFactory` 仅在需要表达经过选择的单一窗口模型时做小范围扩展；
- `build.sh`：任何新增且参与源码构建的 Swift 文件必须加入显式 `SOURCES=(...)`。

必须保持：

- 正常启动不进入 V2 预览，不改变左键复制、右键菜单、搜索、提示词、Skill 和现有任务行为。
- 预览数据与真实存储完全隔离；退出后不残留用户数据或通知。
- 首轮所有未提交代码和证据原样保留，不删除、不重写历史。
- 不引入新的第三方 UI / 动画依赖；优先使用系统 SwiftUI / AppKit 能力。

## Acceptance criteria

### Interaction

- 工作台打开后月历和任务区同时完整可见，不需要展开或进入第二层页面。
- 用户无需说明即可找到待办快速输入和倒数日新增入口。
- 普通待办新增只需一次鼠标点击、输入和 Return；模式切换与日期选择各只需一次点击。
- 单击日期不会移动窗口；只有顶部明确区域能移动窗口；只有任务手柄能排序。
- 日期选择、全部返回、模式切换、待办新增 / 编辑 / 完成 / 撤销、倒数日原位新增均能在隔离样例上连续操作。
- `Esc`、`Command-W` 和可见关闭路径符合最终选定的单一窗口模型。

### Visual

- 用户现场看到的 V2 不再呈现为旧 V1 的深灰厚重面板；整体与 Desktop Sentry 搜索面板属于同一产品家族。
- 月历的公历、农历、传统节日、今天、选中日期和项目点位形成清楚层级。
- 右栏在 3–6 条真实样例下信息密度完整，不出现大片空白或厚重灰砖堆叠。
- 浅色、深色、增强对比度和减少透明度下内容可读；材料只有一个责任层。
- 人工并排对照现有 SearchPanel 视觉和浮引参考时，能分别指出继承了哪些 Desktop Sentry 元素、借鉴了哪些浮引层级，而不是泛称“像”。

### Motion

- 打开、关闭、选中、月份切换、新增、完成和排序落位均有接近正常 macOS App 的即时反馈。
- 打开 / 关闭具有轻微缩放与淡入淡出；选中具有系统色过渡与轻微弹动；不存在突兀跳变或夸张动画。
- 快速连续操作不会等待上一段动画结束；减少动态效果模式有可理解的替代反馈。

### Isolation and regression

- 运行预览前后，真实任务、Deadline、设置、复制历史和通知请求均无变化。
- 正常源码构建启动不显示预览样例，现有核心路径通过定向回归检查。
- 未安装到 `/Applications`，未修改版本、登录项或远程仓库。

## Implementation phases

### Phase 1 - Visual shell and window model

- 创建内存样例、固定双栏、月历层级、右栏双模式和候选窗口模型。
- 先只完成结构与视觉，不接真实存储和通知。

Checkpoint: 提供一张浅色主界面、一张深色主界面和简短连续录屏；执行主线先自查旧 V1 禁止项，但不得声称用户已视觉验收。

### Phase 2 - Complete interactive flows and motion

- 接入日期联动、快速新增、栏内编辑、完成 / 撤销、倒数日原位编辑、专用手柄排序和系统式动效。
- 验证手势隔离与减少动态效果。

Checkpoint: 提供可操作源码预览和覆盖主要流程的连续录屏；用户实际判断入口、手感和美感。

### Phase 3 - Prototype validation

- 运行构建、签名、隔离性检查和现有核心定向回归。
- 记录窗口模型选择、视觉偏差、动画调整和用户反馈。

Checkpoint: 用户明确接受原型后才可讨论真实数据与通知集成；本规格不会自动授权正式接入。

## Rollback

- V2 入口仅在明确预览模式触发；关闭或不传预览参数即可回到正常应用路径。
- 首轮 V1 代码与证据保留，不删除也不覆盖；V2 新文件保持独立边界，便于停用。
- 原型只使用内存数据，因此停止预览不需要迁移或删除用户数据。
- 若原型失败，记录原因并停止入口；任何删除原型文件仍需用户针对精确目标另行批准。

## Verification evidence

执行主线在此记录：

- Git 工作区接管和首轮改动保护；
- 精确预览启动命令；
- 真实数据文件与通知请求未变化的证据；
- 浅色 / 深色截图与连续交互录屏路径；
- 点击预算、窗口拖动、任务排序和关闭行为检查；
- 减少动态效果、减少透明度和增强对比度检查；
- `bash build.sh` 与 `codesign --verify --deep --strict build/DesktopSentry.app` 结果；
- 正常路径定向回归与用户视觉验收结论。

### 2026-08-21 execution evidence

- 接管时工作区为 `main`；已保留既有 V1 未提交源码、测试、截图证据和产品讨论文档，未执行删除、回退、覆盖、安装或版本变更。
- 视觉参考优先级按 `docs/product/ideas/CALENDAR-BENCHMARK-RESEARCH.md` 的 2026-08-21 补充执行：Desktop Sentry / macOS 行为统一材质与窗口，浮引负责双栏构图，LunarBar 仅负责月历细节，TodoPop 仅负责任务微交互。
- 预览启动命令：`open build/DesktopSentry.app --args --calendar-workbench-v2-preview`。
- 浅色外观证据：`docs/product/approved/evidence/SPEC-002-phase1-light.png`；深色外观证据：`docs/product/approved/evidence/SPEC-002-phase1-dark.png`。
- 连续交互录屏：`docs/product/approved/evidence/SPEC-002-phase1-preview.mov`（8 秒，包含模式区域与日期选择操作）。
- 更新构建连续录屏：`docs/product/approved/evidence/SPEC-002-phase1-preview-updated.mov`（6 秒；旧录屏按删除保护保留）。
- `bash build.sh`：passed；`codesign --verify --deep --strict build/DesktopSentry.app`：passed。
- V1 Deadline 定向冒烟：`swiftc ... Tests/DeadlineSmoke/main.swift && .../smoke`：passed（model / storage / store / notification-id）。V2 模型与视图独立 `swiftc -typecheck`：passed。
- V2 内存模型冒烟：`swiftc -parse-as-library ... Sources/Models/CalendarWorkbenchV2Model.swift Tests/CalendarWorkbenchV2Smoke/main.swift && .../smoke`：passed（默认待办、日期预填、倒数日新增、完成/撤销、栏内改名、显示全部）。
- 运行现场确认：V2 窗口由本地源码构建启动，使用内存样例；样例包含今天、未来、逾期、已完成、通知开启和重点项。未读取或写入真实任务、Deadline、设置、复制历史，未请求通知权限。
- 隔离实现复核：`StorageManager.shared` 与 `DeadlineStorage.shared` 改为 lazy，V2 预览不会初始化真实 Application Support 存储目录。

## Deviations

任何影响固定双栏、点击预算、农历 / 节日范围、窗口模型、视觉家族、动效语义、隔离性或未来 Apple 适配边界的偏差，必须先记录并取得用户批准。尺寸、比例、间距、圆角、阴影和系统动画参数可在原型内调整，但必须满足可观察验收标准并记录最终选择。

### 2026-08-21 execution notes

- 窗口模型选择正常 macOS 标题窗口：保留三颗系统交通灯与 `Command-W`，不在分隔线或内容区放关闭叉；整个内容背景不可拖动，拖动职责留给标题栏。
- V2 预览通过 `--calendar-workbench-v2-preview` 自动打开，另提供仅作用于预览窗口的 `--calendar-workbench-v2-light` / `--calendar-workbench-v2-dark` 外观开关，未改变系统外观或用户设置。
- 玻璃材质只有 `PanelFactory.makeGlassContainer` 一个责任源；V2 SwiftUI 内容不再叠加第二层 Material。列表行使用低透明度系统色层，不延续 V1 的整块深灰 / 厚重灰砖 / 橙色粗描边。
- 预览采用 `CalendarWorkbenchV2Model` 内存样例，保留农历与传统节日标签，不接二十四节气、Apple Reminders、真实通知或持久化。
- Phase 1 现场截图仍属于执行证据，不代表用户视觉验收；用户可继续要求视觉或交互修正后再进入真实数据讨论。
