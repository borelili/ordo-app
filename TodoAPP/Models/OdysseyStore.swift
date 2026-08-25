// OdysseyStore.swift
// TickTick — 奥德赛计划数据层 v4
//
// 4-layer 架构： Path → Goal → Project → Task(UUID 引用)
// 持久化：UserDefaults JSON，key = odyssey_paths_v4
//
// v1/v2/v3 数据 key 不同，自动废弃；
// 迁移逻辑：init 时自动补齐 A/B/C 三条默认路径。

import SwiftUI
import Combine

// MARK: - 枚举

enum PathKind: String, Codable, CaseIterable {
    case core  = "核心路径"
    case draft = "探索草稿"
}

enum GoalTimeHorizon: String, Codable, CaseIterable {
    case threeMonths = "3 个月"
    case halfYear    = "半年"
    case oneYear     = "1 年"
    case threeYears  = "3 年"
    case custom      = "自定义"
}

// MARK: - OdysseyProject（项目，含任务 UUID 引用）

struct OdysseyProject: Identifiable, Codable, Equatable, Hashable {
    var id:            UUID   = UUID()
    var name:          String = ""
    var summary:       String = ""
    var linkedTaskIDs: [UUID] = []     // 引用 SwiftData Task.id
    var isCompleted:   Bool   = false
    var createdAt:     Date   = Date()
}

// MARK: - OdysseyGoal（目标，含 Project 列表）

struct OdysseyGoal: Identifiable, Codable, Equatable, Hashable {
    var id:              UUID             = UUID()
    var title:           String           = ""
    var summary:         String           = ""
    var timeHorizon:     GoalTimeHorizon  = .oneYear
    var successCriteria: String           = ""
    var projects:        [OdysseyProject] = []
    var linkedTaskIDs:   [UUID]           = []  // 目标层直接关联任务（无归属项目）
    var isCompleted:     Bool             = false
    var createdAt:       Date             = Date()

    var totalLinkedTaskCount: Int {
        linkedTaskIDs.count + projects.reduce(0) { $0 + $1.linkedTaskIDs.count }
    }
}

// MARK: - OdysseyPath（路径，含 Goal 列表）

struct OdysseyPath: Identifiable, Codable, Equatable, Hashable {
    var id:              UUID          = UUID()
    var label:           String        = "A"   // 单字母标识，A/B/C 为系统保留
    var title:           String        = ""
    var summary:         String        = ""
    var visionText:      String        = ""
    var kind:            PathKind      = .core
    var attractionScore: Int           = 3     // 1~5
    var difficultyScore: Int           = 3     // 1~5
    var isFocused:       Bool          = false
    var isArchived:      Bool          = false
    var isDefault:       Bool          = false // true = A/B/C 不可删除
    var goals:           [OdysseyGoal] = []
    var linkedTaskIDs:   [UUID]        = []    // 路径层直接关联任务（无归属目标/项目）
    var createdAt:       Date          = Date()

    var totalProjectCount:    Int { goals.reduce(0) { $0 + $1.projects.count } }
    var totalLinkedTaskCount: Int {
        linkedTaskIDs.count + goals.reduce(0) { $0 + $1.totalLinkedTaskCount }
    }
}

// MARK: - 导航统计类型（供总览页使用）

enum OdysseyOverviewTab: String, Hashable {
    case paths, goals, projects, tasks
}

// MARK: - OdysseyContext（任务反向查询结果）

struct OdysseyContext {
    let pathTitle:   String
    let goalTitle:   String   // 空字符串 = 仅路径层关联
    let projectName: String   // 空字符串 = 无项目层关联

    /// 组装展示文本，自动跳过空层级（例：仅有 path 时只显示路径名）
    var displayText: String {
        var parts: [String] = [pathTitle]
        if !goalTitle.isEmpty   { parts.append(goalTitle) }
        if !projectName.isEmpty { parts.append(projectName) }
        return parts.joined(separator: "  →  ")
    }
}

// MARK: - OdysseyDetailedContext（带 ID，用于跳转导航）

struct OdysseyDetailedContext {
    let pathID:      UUID
    let pathTitle:   String
    let goalID:      UUID?
    let goalTitle:   String   // 空字符串 = 仅路径层关联
    let projectID:   UUID?
    let projectName: String   // 空字符串 = 无项目层关联
}

// MARK: - OdysseyStore

@MainActor
final class OdysseyStore: ObservableObject {

    @Published var paths: [OdysseyPath] {
        didSet { save() }
    }

    // v4 key — 与旧版 key 不同，旧数据自动废弃
    private static let key = "odyssey_paths_v4"

    // MARK: - Init + 迁移

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([OdysseyPath].self, from: data) {
            paths = decoded
        } else {
            // 尝试升级 v3 数据
            if let old = UserDefaults.standard.data(forKey: "odyssey_paths_v3"),
               var decoded = try? JSONDecoder().decode([OdysseyPath].self, from: old) {
                // v3 路径不含 isDefault，给已有路径设置
                for i in decoded.indices { decoded[i].isDefault = false }
                paths = decoded
            } else {
                paths = []
            }
        }
        ensureDefaultPaths()
        // 确保始终有聚焦路径
        ensureFocus()
    }

    // MARK: - 全局统计

    var focusedPath:       OdysseyPath? { paths.first { $0.isFocused && !$0.isArchived } }
    var activePaths:       [OdysseyPath] { paths.filter { !$0.isArchived } }
    var archivedPaths:     [OdysseyPath] { paths.filter { $0.isArchived } }
    var totalGoalCount:    Int { activePaths.reduce(0) { $0 + $1.goals.count } }
    var totalProjectCount: Int { paths.reduce(0) { $0 + $1.totalProjectCount } }
    /// 该计数仅用于无法传入真实任务集时的占位，实际显示时请用 liveTaskCount(existingIDs:)
    var totalTaskCount:    Int { paths.reduce(0) { $0 + $1.totalLinkedTaskCount } }

    /// 基于真实存在的任务 ID 集合计算关联任务数，过滤已删除的脏 UUID
    func liveTaskCount(existingIDs: Set<UUID>) -> Int {
        var total = 0

        for path in paths {
            total += path.linkedTaskIDs.filter { existingIDs.contains($0) }.count

            for goal in path.goals {
                total += goal.linkedTaskIDs.filter { existingIDs.contains($0) }.count

                for project in goal.projects {
                    total += project.linkedTaskIDs.filter { existingIDs.contains($0) }.count
                }
            }
        }

        return total
    }

    /// 清理所有层级中已不存在的 linkedTaskIDs（任务删除后调用）
    func cleanDeletedTaskIDs(existingIDs: Set<UUID>) {
        for pi in paths.indices {
            paths[pi].linkedTaskIDs.removeAll { !existingIDs.contains($0) }
            for gi in paths[pi].goals.indices {
                paths[pi].goals[gi].linkedTaskIDs.removeAll { !existingIDs.contains($0) }
                for proj in paths[pi].goals[gi].projects.indices {
                    paths[pi].goals[gi].projects[proj].linkedTaskIDs.removeAll { !existingIDs.contains($0) }
                }
            }
        }
        // 直接触发 save，不走 didSet（避免重复触发）
        save()
    }

    // 所有目标（跨路径，未归档路径）
    var allGoals: [(pathID: UUID, goal: OdysseyGoal)] {
        activePaths.flatMap { p in p.goals.map { (p.id, $0) } }
    }

    // 所有项目（跨路径、跨目标）
    var allProjects: [(pathID: UUID, goalID: UUID, project: OdysseyProject)] {
        activePaths.flatMap { p in
            p.goals.flatMap { g in
                g.projects.map { (p.id, g.id, $0) }
            }
        }
    }

    // MARK: - 默认路径保障

    /// 确保 A / B / C 三条默认路径始终存在
    func ensureDefaultPaths() {
        let templates: [(label: String, title: String, summary: String)] = [
            ("A", "当前主线", "持续深耕现有方向，稳步迭代成长。"),
            ("B", "平行方案", "如果走另一条路，可能性会如何打开？"),
            ("C", "大胆构想", "如果没有任何限制，你最想成为谁？"),
        ]
        for tmpl in templates {
            if !paths.contains(where: { $0.label == tmpl.label && $0.isDefault }) {
                var np = OdysseyPath(
                    label:     tmpl.label,
                    title:     tmpl.title,
                    summary:   tmpl.summary,
                    kind:      .core,
                    isDefault: true
                )
                // A 路径默认聚焦（仅首次创建时无其他路径）
                if tmpl.label == "A" && !paths.contains(where: { $0.isFocused }) {
                    np.isFocused = true
                }
                paths.append(np)   // 触发 didSet → save()
            }
        }
    }

    /// 是否允许删除该路径（默认路径不可删除）
    func canDelete(pathID: UUID) -> Bool {
        guard let p = paths.first(where: { $0.id == pathID }) else { return false }
        return !p.isDefault
    }

    // MARK: - Path CRUD

    func addPath(_ path: OdysseyPath) {
        paths.append(path)
    }

    func updatePath(_ path: OdysseyPath) {
        mutate(pathID: path.id) { $0 = path }
    }

    /// 删除路径（默认路径无法删除）
    func deletePath(id: UUID) {
        guard canDelete(pathID: id) else { return }
        paths.removeAll { $0.id == id }
        ensureFocus()
    }

    func archivePath(id: UUID) {
        mutate(pathID: id) { $0.isArchived = true; $0.isFocused = false }
        ensureFocus()
    }

    func unarchivePath(id: UUID) {
        mutate(pathID: id) { $0.isArchived = false }
    }

    func setFocus(pathID: UUID) {
        paths = paths.map {
            var p = $0
            p.isFocused = (p.id == pathID && !p.isArchived)
            return p
        }
    }

    // MARK: - Goal CRUD

    func addGoal(_ goal: OdysseyGoal, to pathID: UUID) {
        mutate(pathID: pathID) { $0.goals.append(goal) }
    }

    func updateGoal(_ goal: OdysseyGoal, in pathID: UUID) {
        mutate(pathID: pathID) { path in
            if let idx = path.goals.firstIndex(where: { $0.id == goal.id }) {
                path.goals[idx] = goal
            }
        }
    }

    func deleteGoal(id: UUID, from pathID: UUID) {
        mutate(pathID: pathID) { $0.goals.removeAll { $0.id == id } }
    }

    // MARK: - Project CRUD

    func addProject(_ project: OdysseyProject, to goalID: UUID, in pathID: UUID) {
        mutate(pathID: pathID) { path in
            if let gi = path.goals.firstIndex(where: { $0.id == goalID }) {
                path.goals[gi].projects.append(project)
            }
        }
    }

    func updateProject(_ project: OdysseyProject, in goalID: UUID, pathID: UUID) {
        mutate(pathID: pathID) { path in
            if let gi = path.goals.firstIndex(where: { $0.id == goalID }),
               let pi = path.goals[gi].projects.firstIndex(where: { $0.id == project.id }) {
                path.goals[gi].projects[pi] = project
            }
        }
    }

    func deleteProject(id: UUID, from goalID: UUID, in pathID: UUID) {
        mutate(pathID: pathID) { path in
            if let gi = path.goals.firstIndex(where: { $0.id == goalID }) {
                path.goals[gi].projects.removeAll { $0.id == id }
            }
        }
    }

    // MARK: - Task Linkage

    /// 从所有层级（路径/目标/项目）中移除指定任务 ID（任务被删除时调用）
    func removeTaskIDFromAllLayers(_ taskID: UUID) {
        for pi in paths.indices {
            paths[pi].linkedTaskIDs.removeAll { $0 == taskID }
            for gi in paths[pi].goals.indices {
                paths[pi].goals[gi].linkedTaskIDs.removeAll { $0 == taskID }
                for proj in paths[pi].goals[gi].projects.indices {
                    paths[pi].goals[gi].projects[proj].linkedTaskIDs.removeAll { $0 == taskID }
                }
            }
        }
        save()
    }

    // 项目层：绑定 pathID + goalID + projectID
    func linkTask(id taskID: UUID, to projectID: UUID, goalID: UUID, pathID: UUID) {
        mutate(pathID: pathID) { path in
            if let gi = path.goals.firstIndex(where: { $0.id == goalID }),
               let pi = path.goals[gi].projects.firstIndex(where: { $0.id == projectID }),
               !path.goals[gi].projects[pi].linkedTaskIDs.contains(taskID) {
                path.goals[gi].projects[pi].linkedTaskIDs.append(taskID)
            }
        }
    }

    func unlinkTask(id taskID: UUID, from projectID: UUID, goalID: UUID, pathID: UUID) {
        mutate(pathID: pathID) { path in
            if let gi = path.goals.firstIndex(where: { $0.id == goalID }),
               let pi = path.goals[gi].projects.firstIndex(where: { $0.id == projectID }) {
                path.goals[gi].projects[pi].linkedTaskIDs.removeAll { $0 == taskID }
            }
        }
    }

    // 目标层：绑定 pathID + goalID
    func linkTaskToGoal(id taskID: UUID, goalID: UUID, pathID: UUID) {
        mutate(pathID: pathID) { path in
            if let gi = path.goals.firstIndex(where: { $0.id == goalID }),
               !path.goals[gi].linkedTaskIDs.contains(taskID) {
                path.goals[gi].linkedTaskIDs.append(taskID)
            }
        }
    }

    func unlinkTaskFromGoal(id taskID: UUID, goalID: UUID, pathID: UUID) {
        mutate(pathID: pathID) { path in
            if let gi = path.goals.firstIndex(where: { $0.id == goalID }) {
                path.goals[gi].linkedTaskIDs.removeAll { $0 == taskID }
            }
        }
    }

    // 路径层：仅绑定 pathID
    func linkTaskToPath(id taskID: UUID, pathID: UUID) {
        mutate(pathID: pathID) { path in
            if !path.linkedTaskIDs.contains(taskID) {
                path.linkedTaskIDs.append(taskID)
            }
        }
    }

    func unlinkTaskFromPath(id taskID: UUID, pathID: UUID) {
        mutate(pathID: pathID) { path in
            path.linkedTaskIDs.removeAll { $0 == taskID }
        }
    }

    /// 反向查询：给定 Task.id，返回归属的路径/目标/项目名称（三层均可查）
    func context(for taskID: UUID) -> OdysseyContext? {
        for path in paths {
            // 1. 项目层（最精确）
            for goal in path.goals {
                for project in goal.projects {
                    if project.linkedTaskIDs.contains(taskID) {
                        return OdysseyContext(
                            pathTitle:   path.title,
                            goalTitle:   goal.title,
                            projectName: project.name
                        )
                    }
                }
            }
            // 2. 目标层
            for goal in path.goals {
                if goal.linkedTaskIDs.contains(taskID) {
                    return OdysseyContext(
                        pathTitle:   path.title,
                        goalTitle:   goal.title,
                        projectName: ""
                    )
                }
            }
            // 3. 路径层
            if path.linkedTaskIDs.contains(taskID) {
                return OdysseyContext(
                    pathTitle:   path.title,
                    goalTitle:   "",
                    projectName: ""
                )
            }
        }
        return nil
    }

    /// 反向查询（带 ID 版本）：给定 Task.id，返回归属的路径/目标/项目 ID+名称，用于导航跳转
    func detailedContext(for taskID: UUID) -> OdysseyDetailedContext? {
        for path in paths {
            for goal in path.goals {
                for project in goal.projects {
                    if project.linkedTaskIDs.contains(taskID) {
                        return OdysseyDetailedContext(
                            pathID: path.id, pathTitle: path.title,
                            goalID: goal.id, goalTitle: goal.title,
                            projectID: project.id, projectName: project.name
                        )
                    }
                }
            }
            for goal in path.goals {
                if goal.linkedTaskIDs.contains(taskID) {
                    return OdysseyDetailedContext(
                        pathID: path.id, pathTitle: path.title,
                        goalID: goal.id, goalTitle: goal.title,
                        projectID: nil, projectName: ""
                    )
                }
            }
            if path.linkedTaskIDs.contains(taskID) {
                return OdysseyDetailedContext(
                    pathID: path.id, pathTitle: path.title,
                    goalID: nil, goalTitle: "",
                    projectID: nil, projectName: ""
                )
            }
        }
        return nil
    }

    // MARK: - 内部工具

    private func mutate(pathID: UUID, _ body: (inout OdysseyPath) -> Void) {
        if let idx = paths.firstIndex(where: { $0.id == pathID }) {
            var p = paths[idx]; body(&p); paths[idx] = p
        }
    }

    private func ensureFocus() {
        guard !paths.contains(where: { $0.isFocused && !$0.isArchived }) else { return }
        // 优先设置 A 路径为聚焦
        if let aPath = paths.first(where: { $0.label == "A" && !$0.isArchived }) {
            mutate(pathID: aPath.id) { $0.isFocused = true }
        } else if let first = paths.first(where: { !$0.isArchived }) {
            mutate(pathID: first.id) { $0.isFocused = true }
        }
    }

    // MARK: - 持久化

    private func save() {
        if let data = try? JSONEncoder().encode(paths) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

// NOTE: 旧 odyssey_paths_v1/v2/v3 数据自动废弃，v3→v4 migration 在 init 中处理。

// MARK: - Environment Key（可空注入，避免无 OdysseyStore 时崩溃）

import SwiftUI

private struct OdysseyStoreKey: EnvironmentKey {
    static let defaultValue: OdysseyStore? = nil
}

extension EnvironmentValues {
    var odysseyStore: OdysseyStore? {
        get { self[OdysseyStoreKey.self] }
        set { self[OdysseyStoreKey.self] = newValue }
    }
}
