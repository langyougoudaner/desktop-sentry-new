# SPEC-003 - 日历任务工作台 V2.1 视觉重置

- Status: APPROVED
- Owner: product discussion
- Created: 2026-08-21
- Approved by: user
- Approval date: 2026-08-21
- Source: `docs/product/ideas/CALENDAR-WORKBENCH-V2-1-VISUAL-RESET.md`
- Supersedes for execution: `SPEC-002-CALENDAR-TASK-WORKBENCH-V2-PROTOTYPE.md`

## Outcome

停止修补被拒绝的 V2 视觉骨架。新的可操作原型使用 LunarBar 高保真月历视觉、浮引的固定双栏工作台结构以及 Desktop Sentry / macOS 的统一系统外壳。月历必须足够大，用户无需凑近即可快速查看公历、农历、传统节日、今天、悬停日期和选中日期；右侧倒数日 / 待办继续常驻，但不得挤压月历或制造巨大空白。

本规格只授权隔离原型的视觉与交互重置，不授权真实数据、通知、Apple Reminders、安装、版本升级或发布。

## Rejected implementation evidence

当前 V2 被用户明确拒绝，已确认的实现错误包括：

- 标准黑色标题栏与内容区自绘总标题重复；
- 左栏硬限制为 430–470pt，右栏至少 470pt 且无限扩张，列权重反转；
- 1040 × 700pt 窗口和 650pt 最小高度配合全高空状态，产生巨大空洞；
- 日期格约 56pt、日号约 17pt，月历在大窗口里仍然过小；
- 左下“菜单栏重点”挤压月历且偏离当前任务；
- 倒数日所有字段挤在一行，日期 / 时间控件在中文与深色外观下裁切；
- 名称为空时直接禁用添加按钮，没有“必填”说明、即时错误或焦点引导；
- 强制测试外观被当成用户预览，形成黑标题栏、灰底与白字的割裂结果。

上述结果只作为失败证据，禁止继续作为视觉起点。所有现场文件、截图、录屏和测试保留，不删除、不回退。

## Approved visual direction

### One coherent source hierarchy

1. Desktop Sentry / macOS：系统字体、系统强调色、单层原生材质、可读性、窗口行为和动效语义。
2. 浮引：左大右小固定双栏、清楚顶部秩序、倒数日 / 待办一级切换和完整工作台感。
3. LunarBar：月历日期层级、农历密度、今天状态、选中形状、事件点位、紧凑圆角和材质质感。
4. TodoPop：待办回车新增、栏内编辑、专用排序手柄和完成反馈。

禁止逐件拼贴不同产品的图标、按钮、卡片和颜色。LunarBar 的名称、图标、书签符号、截图素材和品牌标识不得复制；右栏使用与月历同一套字体、材质、圆角、间距和状态色自然延展。

### Window shell

- 去掉标准黑色标题栏和内容区重复总标题。
- 使用一层连续的系统材质；不得同时由 AppKit 容器和 SwiftUI 内容重复铺灰底或玻璃。
- 使用菜单栏锚定、无独立黑标题栏的浮层模型。支持再次点击菜单栏入口、`Esc` 与 `Command-W` 关闭。
- 默认跟随系统外观；强制浅色 / 深色仅用于独立证据采集，不能作为默认用户预览。
- 浅色使用清楚浅色系统材质与深色正文；深色使用系统深色材质与高对比正文。禁止灰底配灰白文字。
- 默认原型尺寸为约 1060 × 660pt；最小不得低于约 980 × 620pt。若屏幕可用空间不足，可等比降低留白，但日号和农历字号不得低于本规格下限。

### Fixed column balance

- 左侧月历约 650pt，占内容宽度约 60–64%；右侧任务区约 410pt，占约 36–40%。
- 左栏不得低于 600pt；右栏应足以显示 3–5 条项目和完整新增表单。
- 移除左下“菜单栏重点”卡片。菜单栏剩余天数是菜单栏自身职责，不占月历主画面。
- 右栏列表与编辑器从顶部连续排布；空状态靠近新增入口，不得居中占满整栏。

## Large calendar metrics

以下是原型验收下限，不是随意建议：

- 月历网格应占左栏主要可见面积；包含六周的月份也不能被压缩成角落小控件。
- 单个日期命中区域目标约 78–84pt 宽、72–82pt 高；任何日期的可点击区域不得小于 64 × 64pt。
- 公历日号使用系统字体约 28–32pt、常规或半粗；不得回到 17pt。
- 农历与传统节日使用约 13–14pt，并保持清晰行高；不得依赖极小字体缩放才能装下。
- 星期标题约 13–14pt；月份标题、左右切换和“今天”形成一个紧凑控制组。
- 不再额外显示占空间的“日历”大标题；日期数字是左栏第一视觉层级。
- 六周网格、顶部控制、必要留白必须在默认高度内完整可见，不通过滚动查看月历。

## Date interaction state machine

用户提供的三个局部截图定义以下状态；任何实现必须逐项可见且互不混淆。

| 状态 | 可观察外观 | 行为优先级 |
|---|---|---|
| 普通日期 | 无卡片底，深色主日号，小号农历 | 最低 |
| 悬停预选 | 出现浅灰 / 低强调色圆角矩形，边框和轻底色均克制；移出后消失 | 高于普通 |
| 点击选中 | 圆角矩形的强调色明显加深，约 2pt 系统蓝边框与可读蓝色文字 / 选中底色 | 高于悬停 |
| 今天但未选中 | 以蓝色圆形描边包围日号与农历，文字使用系统蓝；不使用选中矩形 | 高于普通 |
| 今天被选中 | 圆形平滑转为选中圆角矩形；左上出现一个实心系统蓝点，继续表达“今天” | 最高 |

补充规则：

- 圆角矩形建议约 12–14pt 圆角，形状不得过扁、过小或挤压文字。
- 今天悬停但尚未点击时，保留圆形今天身份，只增加轻微底色 / 按压反馈，不叠加第二个矩形边框，避免双框。
- 已选日期悬停时保持选中样式，不退回浅灰预选。
- 键盘焦点使用系统 focus ring 或等价外描边，不与今天实心点混淆。
- 传统节日颜色不得因为悬停或选中而变得不可读；选中背景上必须采用适配后的高对比文本色。

## Date motion

- 鼠标进入普通日期时，预选框在约 90–120ms 内淡入并轻微从 0.98 放大到 1；移出沿相反路径淡出。
- 按下瞬间立即出现轻微压缩反馈，目标约 0.98；不得等到鼠标松开才响应。
- 点击后的浅灰预选到蓝色选中使用短促、可中断的系统式变化，目标约 180–240ms；颜色、边框和形状同步，不排队。
- 点击今天时，圆形到圆角矩形通过连续圆角插值完成；实心点与选中框同一时刻淡入并轻微缩放到位。
- 普通鼠标点击不需要夸张回弹；默认采用接近临界阻尼的系统弹簧。只有按压回位允许极轻微弹性。
- 快速连续悬停与点击必须从当前屏幕状态继续，不能闪烁、跳回初始值或等待上一段动画结束。
- 开启“减少动态效果”时，取消缩放与形状飞行动画，改为约 100–140ms 颜色 / 透明度交叉淡化；今天实心点和所有状态信息仍须保留。

## Calendar behavior

- 显示公历、农历和传统节日；不显示二十四节气。
- 今天与选中日期可同时辨认；今天被选中时依靠实心点保留今天身份。
- 有项目的日期只显示克制、统一的点位或数量；不使用多色彩珠和无关书签图标。
- 单击日期只更新选中和右栏过滤，不得移动窗口。
- 月份切换保持方向一致的短过渡；不得缩小整个日历或突然闪白。

## Right task column

- 顶部保留一个系统式“倒数日 / 待办”分段控制；新增入口紧随其下。
- 待办默认模式与回车快速新增保持不变。
- 任务行使用浅层背景和清楚间距，不使用厚灰砖。
- 选中日期没有项目时，在新增入口下方显示一行短说明和“为 M 月 d 日添加”操作；同时提供一次点击返回全部。
- 空状态不得占满右栏高度，也不得让右下角看起来像未完成页面。

## Countdown composer correction

- 改为右栏内纵向小表单，至少分为“名称”和“日期 / 提醒”两行。
- 名称明确标为“名称（必填）”，展开后自动聚焦。
- 添加按钮保持可点击；名称为空时点击或 Return，在名称下方即时显示“请输入倒数日名称”，并保留已选日期和时间。
- 日期、时间控件必须为中文本地化留足宽度，不得裁切，不得出现与整体外观割裂的黑色小块。
- 提醒关闭时隐藏时间；开启后显示“提醒时间”标签和完整时间控件。
- 成功新增后立即出现新行并给出短促反馈；失败不得清空任何字段。

## Phase gate

### Phase 1 — calendar visual shell only

执行主线本次恢复后只允许完成：

- 单层无黑标题栏窗口；
- 1060 × 660pt 左右的固定双栏比例；
- 大月历指标；
- 普通、悬停、选中、今天、今天选中五种日期状态；
- 对应悬停、点击和圆形到圆角矩形动效；
- 右栏只需提供足以判断比例和统一视觉语言的静态 / 内存样例。

Phase 1 必须停止并交付：

1. 默认浅色完整界面截图；
2. 默认深色完整界面截图；
3. 普通日期悬停预选截图；
4. 非今天日期选中截图；
5. 今天未选中与今天选中并排截图；
6. 一段连续展示悬停、点击非今天、点击今天、快速切换的录屏；
7. 与 LunarBar 截图并排的尺寸、字号、形状和材质说明。

用户未明确接受 Phase 1 视觉前，不得进入倒数日表单修复或其他交互实现。

### Phase 2 — right column and countdown flow

仅在用户批准 Phase 1 后，才允许修复右栏密度、空状态、倒数日纵向表单、必填错误、成功新增和待办微交互。

### Phase 3 — prototype validation

仅在用户批准 Phase 2 后，才运行完整原型构建、签名、隔离性和核心路径回归。生产安装仍需单独授权。

## Non-goals and safety

- 不读写真实任务、Deadline、设置、复制历史或 Apple 数据。
- 不安排真实通知，不请求 Apple 权限。
- 不安装到 `/Applications`，不修改版本、登录项或远程仓库。
- 不删除、回退、覆盖当前 V1 / V2 源码、测试、截图和录屏。
- 不直接并入 LunarBar 代码；未来如需复用其 MIT 代码，必须单独核对具体文件和许可证保留要求。

## Verification evidence

执行主线记录：

- 接管时 Git 状态与既有改动保护；
- Phase 1 精确启动命令和证据路径；
- 日期五状态、尺寸、字号、悬停、快速切换、减少动态效果检查；
- 用户 Phase 1 视觉结论；
- 后续阶段只有在前一阶段用户批准后才补充对应证据。

构建通过、执行线自评和静态代码检查都不能代替用户的视觉验收。

### Phase 1 execution record — 2026-08-21

#### Takeover and preservation

- Execution branch remained `main`; baseline tag `v1.1.0-build11-baseline` remained present.
- Version remained `1.1.0` build `11`.
- The pre-existing dirty worktree was preserved. Existing V1/V2 changes and untracked source, tests, product notes, screenshots and recordings were neither deleted, reverted, cleaned nor overwritten.
- Phase 1 was added as an isolated V2.1 preview route. The rejected V2 view/model and all earlier evidence remain in place.

#### Implemented Phase 1 scope

- Added an in-memory-only `CalendarWorkbenchV21PreviewModel` and an independent `CalendarWorkbenchV21View`; neither uses real task, Deadline, settings, clipboard or Apple data.
- Added the explicit preview route `--calendar-workbench-v2-1-preview`, with evidence-only `--calendar-workbench-v2-1-light`, `--calendar-workbench-v2-1-dark`, `--calendar-workbench-v2-1-today-selected` and `--calendar-workbench-v2-1-next-selected` states. Normal launch routing is unchanged.
- Preview startup returns before storage loads, notification scheduling and login-item work. The isolated route also skips global hot-key registration and termination saves.
- Window content is logically `1060 × 660pt`; columns are fixed at `650pt / 1pt divider / 409pt`. The left column never falls below the specification's `600pt` limit in the default preview.
- Calendar cells and hit regions are `82 × 78pt`; day numbers are `30pt`, lunar/festival labels `14pt`, and weekday labels `13pt`.
- One AppKit visual-effect container owns the material. The SwiftUI view adds only its border and content; it does not add a second material layer.
- The five visible date states are implemented separately: normal, 110ms hover preview, selected 2pt system-blue rounded rectangle, today-unselected 72pt circle, and today-selected 82 × 76pt rounded rectangle with a 9pt solid top-left today dot.
- Normal selection uses an interruptible 210ms near-critical system spring; press feedback is immediate `0.98`; rapid changes continue from the current rendered state.
- Reduced Motion uses a 120ms opacity/color crossfade between fixed circle/rectangle layers. It removes press/hover shape scaling, and the today dot fades without a scale transition. The current machine setting was read-only checked as `reduce-motion=off`, so the normal-motion path is the recorded runtime path; the alternate branch was compile-validated without changing the user's system setting.
- The right column contains only static/in-memory sample content sufficient to judge the column ratio and shared visual language. No Phase 2 composer or form correction was implemented.

#### Runtime commands and checks

Build used for the runnable source preview:

```bash
bash build.sh
```

Result: passed; produced `build/DesktopSentry.app`. `build.sh` performs its existing ad-hoc signing as part of bundle generation. No separate Phase 3 signing verification, full regression, installation or launch-item change was performed.

Light preview launch:

```bash
open -n build/DesktopSentry.app --args --calendar-workbench-v2-1-preview --calendar-workbench-v2-1-light
```

Dark preview launch replaced the final flag with `--calendar-workbench-v2-1-dark`.

- CoreGraphics reported the visible source preview at exactly `1060 × 660pt`.
- A real click on 8月22日 left the window bounds unchanged before and after: `X=8, Y=359, Width=1060, Height=660`. Date clicks did not move the window.
- The MOV was verified as a non-empty Apple QuickTime file (`2,614,116` bytes), and a Quick Look thumbnail confirmed visible application content rather than a black/empty recording.
- Only the source preview processes were stopped between evidence runs. `/Applications/DesktopSentry.app` was not overwritten, relaunched or stopped.

#### Phase 1 visual evidence

- [Light full interface](evidence/SPEC-003-phase1-light-full.png)
- [Dark full interface](evidence/SPEC-003-phase1-dark-full.png)
- [Ordinary-date hover preview](evidence/SPEC-003-phase1-hover.png)
- [Non-today selected date](evidence/SPEC-003-phase1-selected-non-today.png)
- [Today unselected](evidence/SPEC-003-phase1-today-unselected.png)
- [Today selected](evidence/SPEC-003-phase1-today-selected.png)
- [Continuous hover, non-today selection, today selection and rapid switching](evidence/SPEC-003-phase1-interactions.mov)

The PNG files include Retina scaling and the native window shadow; their pixel dimensions therefore exceed the logical `1060 × 660pt` window bounds.

#### LunarBar side-by-side mapping

The user-provided LunarBar state references were inspected directly at the three original temporary paths recorded in the execution request. They were used only as visual comparison evidence and were not copied into product assets.

| Comparison | LunarBar reference observation | Desktop Sentry Phase 1 result |
|---|---|---|
| Calendar scale | Large day number dominates; lunar text remains readable; the grid is the primary surface | `82 × 78pt` cells, `30pt` day, `14pt` lunar, six full weeks inside the `650pt` left column |
| Shape states | Today uses a circle; hover uses a restrained gray rounded rectangle; selection uses a stronger blue rounded rectangle | Same state grammar, implemented with system-blue Desktop Sentry styling rather than copied assets |
| Today selected | Rounded selected rectangle plus a solid top-left today dot | `82 × 76pt`, 14pt radius, 2pt blue stroke, 9pt solid top-left dot |
| Event position | Small, subordinate event marks below the date content | One restrained system-blue point or count; no multicolor dot matrix or bookmark symbol |
| Material | Compact, continuous native-looking surface | One continuous AppKit system material, light top border, system font/color; right column extends the same language |

#### Recorded correction and phase stop

- The first V2.1 shell used a nonactivating utility style and the automatic evidence route did not order a visible window. It was corrected to an activating anchored `NSPanel` with a hidden transparent titlebar and hidden traffic lights. This preserves the requested no-black-titlebar appearance and familiar macOS key-window behavior; no divider close control was added.
- No product-direction deviation from the fixed two-column proportions, large-calendar metrics, five-state grammar, motion semantics or isolation boundary was made.
- Phase 1 implementation and evidence are complete from the execution line's perspective, but **not user-accepted**. Work stops here. Phase 2 and Phase 3 remain blocked on the user's explicit visual acceptance.
