//
//  TagManagementView.swift
//  TodoAPP
//
//  Created on 2026/02/14
//

import SwiftUI
import SwiftData

struct TagManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var errorHandler = ErrorHandler.shared
    @Query private var allTags: [Tag]
    
    @State private var showingAddTag = false
    @State private var newTagName = ""
    @State private var newTagColor = "blue"
    @State private var showingEditTag = false
    @State private var editingTag: Tag?
    @State private var editTagName = ""
    @State private var editTagColor = "gray"
    @State private var showingDeleteConfirm = false
    @State private var tagToDelete: Tag?
    
    let availableColors = ["red", "orange", "yellow", "green", "blue", "purple", "pink", "gray"]
    
    var body: some View {
        NavigationStack {
            Group {
                if allTags.isEmpty {
                    emptyStateView
                } else {
                    tagListView
                }
            }
            .navigationTitle("标签管理")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddTag = true
                    } label: {
                        Label("新建标签", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTag) {
                createTagSheet
            }
            .sheet(isPresented: $showingEditTag) {
                editTagSheet
            }
            .alert("确认删除标签", isPresented: $showingDeleteConfirm, presenting: tagToDelete) { tag in
                Button("取消", role: .cancel) {
                    tagToDelete = nil
                }
                Button("删除", role: .destructive) {
                    performDeleteTag(tag)
                }
            } message: { tag in
                let usageCount = tag.tasks?.count ?? 0
                if usageCount > 0 {
                    Text("标签「\(tag.name)」当前正被 \(usageCount) 个任务使用。删除后，这些任务将自动取消关联此标签。")
                } else {
                    Text("确定要删除标签「\(tag.name)」吗？")
                }
            }
            .alert(item: $errorHandler.currentError) { error in
                Alert(
                    title: Text(error.title),
                    message: Text(error.message),
                    dismissButton: .default(Text("确定")) {
                        errorHandler.showError = false
                    }
                )
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "tag.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("暂无标签")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("创建标签来更好地组织你的任务")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                showingAddTag = true
            } label: {
                Label("创建第一个标签", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Tag List
    private var tagListView: some View {
        List {
            ForEach(allTags.sorted { $0.name < $1.name }, id: \.id) { tag in
                TagRowView(tag: tag, onEdit: {
                    editingTag = tag
                    editTagName = tag.name
                    editTagColor = tag.color
                    showingEditTag = true
                }, onDelete: {
                    tagToDelete = tag
                    showingDeleteConfirm = true
                })
            }
        }
    }
    
    // MARK: - Create Tag Sheet
    private var createTagSheet: some View {
        NavigationStack {
            Form {
                Section("标签信息") {
                    TextField("标签名称", text: $newTagName)
                    
                    Picker("颜色", selection: $newTagColor) {
                        ForEach(availableColors, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(Tag(name: "", color: color).colorValue)
                                    .frame(width: 20, height: 20)
                                Text(color)
                            }
                            .tag(color)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.menu)
                    #endif
                    
                    // 预览
                    HStack {
                        Text("预览")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Tag(name: "", color: newTagColor).colorValue)
                                .frame(width: 16, height: 16)
                            Text(newTagName.isEmpty ? "标签名称" : newTagName)
                                .font(.callout)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Tag(name: "", color: newTagColor).colorValue.opacity(0.2))
                        .cornerRadius(12)
                    }
                }
            }
            .navigationTitle("新建标签")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showingAddTag = false
                        newTagName = ""
                        newTagColor = "blue"
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        createTag()
                    }
                    .disabled(newTagName.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Edit Tag Sheet
    private var editTagSheet: some View {
        NavigationStack {
            Form {
                Section("标签信息") {
                    TextField("标签名称", text: $editTagName)
                    
                    Picker("颜色", selection: $editTagColor) {
                        ForEach(availableColors, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(Tag(name: "", color: color).colorValue)
                                    .frame(width: 20, height: 20)
                                Text(color)
                            }
                            .tag(color)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.menu)
                    #endif
                    
                    // 预览
                    HStack {
                        Text("预览")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Tag(name: "", color: editTagColor).colorValue)
                                .frame(width: 16, height: 16)
                            Text(editTagName.isEmpty ? "标签名称" : editTagName)
                                .font(.callout)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Tag(name: "", color: editTagColor).colorValue.opacity(0.2))
                        .cornerRadius(12)
                    }
                }
                
                if let tag = editingTag {
                    Section("使用情况") {
                        HStack {
                            Text("关联任务")
                            Spacer()
                            Text("\(tag.tasks?.count ?? 0) 个")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("编辑标签")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showingEditTag = false
                        editingTag = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveEditedTag()
                    }
                    .disabled(editTagName.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Actions
    private func createTag() {
        guard !newTagName.isEmpty else { return }
        
        let tag = Tag(name: newTagName, color: newTagColor)
        modelContext.insert(tag)
        
        do {
            try modelContext.save()
            print("✅ 创建标签成功: \(newTagName)")
            showingAddTag = false
            newTagName = ""
            newTagColor = "blue"
        } catch {
            errorHandler.handle(error, context: "创建标签")
        }
    }
    
    private func saveEditedTag() {
        guard let tag = editingTag, !editTagName.isEmpty else { return }
        
        tag.name = editTagName
        tag.color = editTagColor
        
        do {
            try modelContext.save()
            print("✅ 编辑标签成功")
            showingEditTag = false
            editingTag = nil
        } catch {
            errorHandler.handle(error, context: "编辑标签")
        }
    }
    
    private func performDeleteTag(_ tag: Tag) {
        modelContext.delete(tag)
        
        do {
            try modelContext.save()
            print("✅ 删除标签成功")
        } catch {
            errorHandler.handle(error, context: "删除标签")
        }
        
        tagToDelete = nil
    }
}

// MARK: - Tag Row View
struct TagRowView: View {
    let tag: Tag
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Circle()
                .fill(tag.colorValue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tag.name)
                    .font(.body)
                
                if let taskCount = tag.tasks?.count, taskCount > 0 {
                    Text("\(taskCount) 个任务")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("未使用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                onEdit()
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            .tint(.blue)
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("编辑标签", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除标签", systemImage: "trash")
            }
        }
    }
}

#Preview {
    TagManagementView()
        .modelContainer(for: [Tag.self, Task.self], inMemory: true)
}
