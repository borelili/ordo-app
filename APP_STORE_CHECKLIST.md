# App Store 提交前检查清单
**项目**: TodoAPP v1.2.0  
**平台**: macOS 14.0+  
**检查日期**: 2026-02-14  
**状态**: ✅ P0 已修复，可进入 Day 2  

---

## 📋 阶段 1: 必修项（P0 - 提交审核前必须完成）

### ✅ 1.1 通知权限用途说明
- [x] **添加 NSUserNotificationsUsageDescription**
  - 状态: ✅ 已完成（commit 5b6d9fb）
  - 验证命令: `xcodebuild -showBuildSettings -scheme TodoAPP | grep NSUserNotifications`
  - 预期输出: `INFOPLIST_KEY_NSUserNotificationsUsageDescription = TodoAPP needs notification...`
  - 证据: 构建成功，配置已生效

### ⏳ 1.2 配置 App Store Connect 营养标签
- [ ] **登录 App Store Connect**
  - URL: https://appstoreconnect.apple.com
  - 账号: [您的 Apple Developer 账号]
  
- [ ] **导航到 App Privacy**
  - 路径: My Apps → TodoAPP → App Privacy
  
- [ ] **回答数据收集问卷**
  ```
  Q: Does your app or third-party partners collect data from this app?
  ✅ 选择: NO
  
  结果: 后续所有问题自动跳过
  显示: "No Data Collected"
  ```
  
- [ ] **保存并验证**
  - 刷新页面，确认显示 "🔒 No Data Collected"
  - 截图保存作为证据

### ⏳ 1.3 检查应用图标
- [ ] **在 Xcode 中打开 Assets.xcassets**
  - 路径: TodoAPP → Assets.xcassets → AppIcon
  
- [ ] **确认 1024x1024 图标存在**
  - 如缺失，使用以下工具生成:
    - macOS "预览" App
    - Figma/Sketch
    - 在线工具: https://appicon.co
  
- [ ] **验证图标规范**
  - [ ] 尺寸: 1024x1024 像素
  - [ ] 格式: PNG
  - [ ] 透明度: 可选（macOS 允许）
  - [ ] 圆角: 自动添加，无需手动处理
  - [ ] 设计: 清晰、简洁、符合 macOS 风格
  
- [ ] **在 Xcode 中构建并检查**
  - 运行应用，查看 Dock 中的图标
  - 确认图标显示正常

---

## 📋 阶段 2: 建议项（P1 - 提升审核通过率）

### ⏳ 2.1 创建隐私政策页面

#### 选项 A: GitHub Pages（推荐，免费）

- [ ] **创建隐私政策文件**
  ```bash
  cd "/Users/borelili/Documents/My project/APP/TodoAPP"
  mkdir -p docs
  
  # 创建中文版
  cat > docs/privacy-policy-zh.md << 'EOF'
  # TodoAPP 隐私政策
  
  **生效日期**: 2026 年 2 月 14 日
  **版本**: 1.0
  
  ## 数据收集
  TodoAPP **不收集、不存储、不传输**任何个人数据。
  
  ## 数据存储
  所有任务、列表、标签数据均存储在您的设备本地（使用 Apple SwiftData 框架），应用开发者无法访问。
  
  ## 通知权限
  应用会请求通知权限，用于在任务到期时发送本地提醒。通知完全在设备本地生成，不经过任何服务器。
  
  ## 第三方服务
  TodoAPP **不使用任何第三方分析、广告或追踪服务**。
  
  ## 联系方式
  如有隐私相关问题，请联系：[您的邮箱]
  
  ---
  **© 2026 TodoAPP. 保留所有权利。**
  EOF
  
  # 创建英文版
  cat > docs/privacy-policy-en.md << 'EOF'
  # TodoAPP Privacy Policy
  
  **Effective Date**: February 14, 2026
  **Version**: 1.0
  
  ## Data Collection
  TodoAPP does **NOT collect, store, or transmit** any personal data.
  
  ## Data Storage
  All tasks, lists, and tags are stored locally on your device using Apple's SwiftData framework. The developer has no access to your data.
  
  ## Notification Permission
  The app requests notification permission to send local reminders when tasks are due. All notifications are generated entirely on your device and do not go through any server.
  
  ## Third-Party Services
  TodoAPP does **NOT use any third-party analytics, advertising, or tracking services**.
  
  ## Contact
  For privacy-related questions, contact: [Your Email]
  
  ---
  **© 2026 TodoAPP. All rights reserved.**
  EOF
  ```

- [ ] **提交到 Git 并推送**
  ```bash
  git add docs/
  git commit -m "docs: 添加隐私政策 (中英文)"
  git push origin main
  ```

- [ ] **启用 GitHub Pages**
  - 打开 GitHub 仓库
  - Settings → Pages
  - Source: Deploy from a branch
  - Branch: main → /docs
  - 点击 Save
  - 等待 2-3 分钟

- [ ] **获取隐私政策 URL**
  - 中文: `https://[your-username].github.io/[repo-name]/privacy-policy-zh`
  - 英文: `https://[your-username].github.io/[repo-name]/privacy-policy-en`
  - 测试访问，确认可正常打开

#### 选项 B: Notion（更简单）

- [ ] **创建 Notion 页面**
  - 打开 Notion，创建新页面
  - 粘贴 `APP_STORE_PRIVACY_AUDIT.md` 中的隐私政策文本
  
- [ ] **发布为公开页面**
  - 点击右上角 "Share"
  - 开启 "Share to web"
  - 复制公开链接
  
- [ ] **测试访问**
  - 在隐身窗口打开链接
  - 确认无需登录即可访问

### ⏳ 2.2 在 App Store Connect 添加隐私政策链接

- [ ] **填写隐私政策 URL**
  - 路径: App Store Connect → My Apps → TodoAPP → App Information
  - 字段: Privacy Policy URL
  - 填写: 上述隐私政策页面 URL（中文或英文）
  
- [ ] **保存并验证**
  - 点击 "Save"
  - 点击链接测试是否可正常打开
  - 截图保存

---

## 📋 阶段 3: App Store 元数据准备（Day 2 任务）

### ⏳ 3.1 准备应用截图（macOS）

- [ ] **截图尺寸要求**
  ```
  macOS 应用截图:
  - 最小: 1280 x 800 像素
  - 推荐: 2560 x 1600 像素（Retina）
  - 数量: 3-10 张（建议 5 张）
  ```

- [ ] **截图内容规划**
  1. 主界面（三栏布局，展示列表 + 任务 + 详情）
  2. 创建任务（显示提醒、标签、子任务功能）
  3. 智能列表（今天、即将到来、已逾期）
  4. 批量操作（展示选择多个任务）
  5. 深色模式（可选，展示主题适配）

- [ ] **截图工具选择**
  - macOS 自带: ⌘ + Shift + 4（空格键选择窗口）
  - 第三方: CleanShot X、Xnapper（添加背景/阴影）

- [ ] **截图优化**
  - [ ] 填充演示数据（避免空界面）
  - [ ] 调整窗口大小（展示完整功能）
  - [ ] 去除个人信息
  - [ ] 统一配色方案

- [ ] **上传到 App Store Connect**
  - 路径: My Apps → TodoAPP → macOS App → App Store → Screenshots
  - 拖拽 5 张截图
  - 排序（第一张最重要）

### ⏳ 3.2 编写 App 描述

- [ ] **创建 App 描述草稿**
  ```markdown
  # TodoAPP - 优雅的任务管理工具
  
  🎯 核心功能
  • 任务管理 - 创建、编辑、完成、删除
  • 智能列表 - 今天、即将到来、已逾期自动分类
  • 标签系统 - 彩色标签，轻松分类
  • 子任务 - 大任务拆解，逐步完成
  • 提醒通知 - 准时提醒，不错过任何事项
  • 批量操作 - 高效处理多个任务
  • 拖拽排序 - 自由调整任务顺序
  
  ✨ 设计亮点
  • 现代化 UI - 卡片设计，视觉舒适
  • 键盘快捷键 - ⌘N 新建，⌘B 批量操作
  • 深色模式 - 自动适配系统主题
  • 无广告，无订阅 - 一次购买，永久使用
  
  🔒 隐私保护
  • 100% 本地存储，数据不离开您的设备
  • 无账号注册，无数据上传
  • 无第三方追踪
  
  最低系统要求: macOS 14.0 (Sonoma)
  ```

- [ ] **润色并调整字数**
  - App Store 限制: 4000 字符
  - 当前字数: ~550 字符
  - 可添加: 使用场景、用户评价（如有）

- [ ] **英文版本**
  ```markdown
  # TodoAPP - Elegant Task Management
  
  🎯 Core Features
  • Task Management - Create, edit, complete, delete
  • Smart Lists - Today, Upcoming, Overdue auto-categorization
  • Tag System - Colorful tags for easy classification
  • Subtasks - Break down large tasks step by step
  • Reminders - Timely notifications for due tasks
  • Batch Operations - Efficiently handle multiple tasks
  • Drag & Drop - Freely adjust task order
  
  ✨ Design Highlights
  • Modern UI - Card design, visually comfortable
  • Keyboard Shortcuts - ⌘N for new, ⌘B for batch
  • Dark Mode - Auto-adapts to system theme
  • No Ads, No Subscription - One-time purchase, lifetime use
  
  🔒 Privacy Protection
  • 100% Local Storage - Data never leaves your device
  • No Account Registration - No data upload
  • No Third-Party Tracking
  
  Minimum Requirements: macOS 14.0 (Sonoma)
  ```

- [ ] **填写到 App Store Connect**
  - 路径: My Apps → TodoAPP → macOS App → App Information
  - 字段: Description
  - 粘贴中英文描述

### ⏳ 3.3 填写应用元数据

- [ ] **基本信息**
  - App Name: TodoAPP
  - Subtitle (可选): 简洁、优雅的任务管理
  - Category: 生产力 (Productivity)
  - Secondary Category (可选): 效率工具 (Utilities)

- [ ] **定价**
  - [ ] 免费（推荐，快速获取用户）
  - [ ] 付费（$0.99 - $4.99）
  - [ ] 订阅（不推荐，与"无订阅"承诺冲突）

- [ ] **年龄分级**
  - 预期: 4+（无不适内容）
  - 填写问卷，如实回答

- [ ] **关键词（Keywords）**
  ```
  todo, task, reminder, productivity, gtd, list, 
  checklist, organizer, planner, local
  ```
  - 最多 100 字符（含逗号）
  - 避免与 App 名称重复
  - 强调"local"（本地存储）

- [ ] **支持 URL**
  - 可使用 GitHub Issues 页面
  - 或创建简单的支持页面

- [ ] **营销 URL（可选）**
  - 项目主页或 GitHub README

---

## 📋 阶段 4: 构建与提交（Day 3 任务）

### ⏳ 4.1 Archive 构建

- [ ] **在 Xcode 中 Archive**
  ```
  1. 选择 scheme: TodoAPP
  2. 选择 destination: Any Mac
  3. Product → Archive
  4. 等待构建完成（2-5 分钟）
  ```

- [ ] **验证 Archive**
  - Xcode → Window → Organizer
  - 选择最新的 Archive
  - 点击 "Validate App"
  - 解决任何警告或错误

- [ ] **上传到 App Store Connect**
  - 在 Organizer 中点击 "Distribute App"
  - 选择 "App Store Connect"
  - 上传（5-10 分钟）
  - 确认上传成功

### ⏳ 4.2 在 App Store Connect 提交审核

- [ ] **选择构建版本**
  - My Apps → TodoAPP → macOS App
  - 选择刚上传的 Build
  
- [ ] **审核信息**
  - [ ] 勾选 "Export Compliance" 相关选项（无加密 = 选 No）
  - [ ] 填写"审核备注"（可选，但建议强调"完全离线"）
    ```
    TodoAPP 是一个完全离线的任务管理应用：
    - 100% 本地存储（使用 SwiftData）
    - 无网络请求
    - 无第三方 SDK
    - 无数据收集
    
    通知权限仅用于本地提醒，不发送到服务器。
    ```
  
- [ ] **提交审核**
  - 点击 "Submit for Review"
  - 确认所有信息正确
  - 等待审核（通常 1-3 天）

---

## 📋 阶段 5: 审核追踪（提交后）

### ⏳ 5.1 监控审核状态

- [ ] **检查审核状态**
  - App Store Connect → My Apps → TodoAPP
  - 状态变化:
    - "Waiting for Review" → 等待中
    - "In Review" → 审核中
    - "Pending Developer Release" → 审核通过，等待发布
    - "Ready for Sale" → 已上架
    - "Rejected" → 被拒（需修复后重新提交）

- [ ] **响应审核人员反馈**
  - 及时查看邮件和 App Store Connect 通知
  - 如有问题，24 小时内回复

### ⏳ 5.2 准备应对常见拒绝原因

如果被拒，参考 `APP_STORE_PRIVACY_AUDIT.md` 中的"紧急联系"部分：

| 拒绝原因 | 代码 | 解决方案 |
|----------|------|----------|
| 缺少权限说明 | 5.1.1 | ✅ 已修复 |
| 隐私政策缺失 | 5.1.1 (ii) | 按 2.2 添加 |
| 应用图标问题 | 2.3.3 | 按 1.3 更新 |
| 功能描述不明 | 2.3.7 | 按 3.2 更新描述 |

---

## 📊 进度追踪

### 完成度统计

```
阶段 1 (P0 必修项):
  ✅ 1.1 通知权限说明 - 已完成
  ⏳ 1.2 营养标签配置 - 待完成（15 分钟）
  ⏳ 1.3 应用图标检查 - 待完成（10 分钟）
  进度: 33% (1/3)

阶段 2 (P1 建议项):
  ⏳ 2.1 隐私政策页面 - 待完成（30 分钟）
  ⏳ 2.2 隐私政策链接 - 待完成（5 分钟）
  进度: 0% (0/2)

阶段 3 (Day 2 任务):
  ⏳ 3.1 应用截图 - 待完成（45 分钟）
  ⏳ 3.2 应用描述 - 待完成（20 分钟）
  ⏳ 3.3 应用元数据 - 待完成（15 分钟）
  进度: 0% (0/3)

阶段 4 (Day 3 任务):
  ⏳ 4.1 Archive 构建 - 待完成（30 分钟）
  ⏳ 4.2 提交审核 - 待完成（15 分钟）
  进度: 0% (0/2)

总进度: 10% (1/10)
```

### 预计完成时间

| 阶段 | 预计耗时 | 最晚完成日期 |
|------|----------|--------------|
| 阶段 1 | 25 分钟 | 2026-02-14 晚 |
| 阶段 2 | 35 分钟 | 2026-02-15 中午 |
| 阶段 3 | 80 分钟 | 2026-02-16 下午 |
| 阶段 4 | 45 分钟 | 2026-02-17 上午 |
| **合计** | **3 小时** | **2026-02-17** |

---

## ✅ 快速验证命令

### 检查通知权限配置
```bash
cd "/Users/borelili/Documents/My project/APP/TodoAPP"
xcodebuild -showBuildSettings -scheme TodoAPP | grep NSUserNotifications
```
**预期**: 显示完整的权限用途说明

### 检查部署目标
```bash
xcodebuild -showBuildSettings -scheme TodoAPP | grep DEPLOYMENT_TARGET
```
**预期**: MACOSX_DEPLOYMENT_TARGET = 14.0

### 检查支持平台
```bash
xcodebuild -showBuildSettings -scheme TodoAPP | grep SUPPORTED_PLATFORMS
```
**预期**: SUPPORTED_PLATFORMS = macosx

### 快速构建测试
```bash
xcodebuild -scheme TodoAPP -destination 'platform=macOS' clean build
```
**预期**: ** BUILD SUCCEEDED **

---

## 📞 遇到问题？

### 常见问题排查

**Q1: Xcode Archive 失败？**
- 检查证书配置（Automatic Signing 应可用）
- 清理构建缓存：Product → Clean Build Folder (⌘ + Shift + K)
- 重启 Xcode

**Q2: 营养标签配置后不显示？**
- 等待 15 分钟（App Store Connect 缓存）
- 清除浏览器缓存后重新登录
- 确认已保存更改

**Q3: 隐私政策链接无法访问？**
- GitHub Pages 需 2-3 分钟生效
- 检查仓库是否为 Public
- 确认 `/docs` 文件夹存在

**Q4: App Store 审核时间过长？**
- 正常审核时间：1-3 天
- 高峰期（节假日）：3-7 天
- 如超过 7 天，联系 Apple Support

---

**创建日期**: 2026-02-14  
**最后更新**: 2026-02-14  
**当前阶段**: 阶段 1 (33% 完成)  
**下一步**: 完成阶段 1 剩余 2 项任务（预计 25 分钟）
