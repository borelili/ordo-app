# 🚀 P0 修复快速验收清单
**2 分钟冒烟测试 - 通知权限提示功能**

## ✅ 前置准备

```bash
# 1. 重置通知权限（macOS）
tccutil reset Notifications com.yourcompany.TodoAPP

# 2. 重新编译
cd /Users/borelili/Documents/My\ project/APP/TodoAPP
xcodebuild -scheme TodoAPP -destination 'platform=macOS' build

# 3. 启动应用
open Build/Products/Debug/TodoAPP.app
```

---

## 🧪 2 分钟验收测试

### Test 1: 首次启动 - 权限请求 (30秒)

```
[ ] 1.1 应用启动
[ ] 1.2 系统弹出权限请求对话框
[ ] 1.3 点击 "不允许"
[ ] 1.4 前往系统设置 → 通知 → 确认 TodoAPP 权限为关闭
```

---

### Test 2: 创建任务 - 权限提示 (45秒)

```
[ ] 2.1 点击 "+" 创建任务
[ ] 2.2 输入标题 "测试任务"
[ ] 2.3 打开 "设置提醒" 开关
[ ] 2.4 选择未来时间
[ ] 2.5 点击 "保存"
[ ] 2.6 ✅ 立即弹出 "需要通知权限" Alert
[ ] 2.7 ✅ Alert 有两个按钮："去设置开启" 和 "取消"
[ ] 2.8 点击 "去设置开启"
[ ] 2.9 ✅ 自动跳转到系统设置 → 通知
```

---

### Test 3: 编辑任务 - 权限提示 (45秒)

```
[ ] 3.1 返回应用（权限仍未开启）
[ ] 3.2 点击任务进入详情
[ ] 3.3 点击 "编辑"
[ ] 3.4 打开 "设置提醒" 开关
[ ] 3.5 ✅ 立即弹出 "需要通知权限" Alert
[ ] 3.6 点击 "取消"
[ ] 3.7 ✅ 提醒开关自动关闭
```

---

## ✅ 验收标准

**P0 阻断问题已修复 = 以下 3 个条件全部满足：**

1. ✅ 权限被拒绝时，**必须**弹出明确提示（不允许 silent fail）
2. ✅ 提示中**必须**包含 "去设置开启" 按钮（可跳转）
3. ✅ 点击按钮后**必须**打开系统设置页面（iOS/macOS 都能正确跳转）

---

## 🔍 验收结果

**测试日期**: __________  
**测试人员**: __________  
**测试平台**: macOS __ / iOS __  

**结果**: ✅ PASS / ❌ FAIL

**备注**: __________

---

## 🚨 如果失败

1. 检查 `NotificationPermissionHelper.swift` 是否正确添加到项目
2. 检查 Build Phases → Compile Sources 是否包含该文件
3. 清理缓存：`rm -rf ~/Library/Developer/Xcode/DerivedData/TodoAPP*`
4. Clean Build Folder: Xcode → Product → Clean Build Folder
5. 重新编译

---

**验收通过签字**: __________
