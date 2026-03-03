//
//  TPStyleSelectPopView.swift
//  SwiftUIiOS14Demo
//
//  Created by fengcaifan on 2025/2/26.
//

import SwiftUI

enum TPStyleSelectType {
    case validity // 有效期
    case goodsType // 物品类型
    case goodsLevel // 物品等级
    case rarity // 稀有程度
    
    var title: String {
        switch self {
        case .validity:
            return "有效期"
        case .goodsType:
            return "物品类型"
        case .goodsLevel:
            return "物品等级"
        case .rarity:
            return "稀有程度"
        }
    }
    
    var defaultItems:[any TPStyleSelectItemTypeProtocol] {
        switch self {
        case .validity:
            return TPStyleSelectValidityType.allCasesAsProtocol
        case .goodsType:
            return TPStyleSelectGoodsType.allCasesAsProtocol
        case .goodsLevel:
            return TPStyleSelectSRLevel.allCasesAsProtocol
        case .rarity:
            return TPStyleSelectRarityType.allCasesAsProtocol
        }
    }
}

protocol TPStyleSelectItemTypeProtocol: CaseIterable, Swift.Identifiable {
    var name: String { get }
    var id: String { get }
}

extension TPStyleSelectItemTypeProtocol {
    var id: String { return "\(Self.self)_\(name)" } // 组合类型 + 选项名，保证唯一性
    
    static var allCasesAsProtocol: [any TPStyleSelectItemTypeProtocol] {
        return Array(self.allCases) as [any TPStyleSelectItemTypeProtocol]
    }
}

enum TPStyleSelectValidityType: String, TPStyleSelectItemTypeProtocol {
    case permanent = "永久" // 永久
    case nonPermanent  = "非永久"//
    
    var name: String { return self.rawValue }
}

enum TPStyleSelectGoodsType: String, CaseIterable, TPStyleSelectItemTypeProtocol {
    case dynamic = "动态"
    case stati = "静态"
    
    var name: String { return self.rawValue }
}

enum TPStyleSelectSRLevel: String, CaseIterable, TPStyleSelectItemTypeProtocol {
    case srn = "N"
    case srr = "R"
    case sr = "SR"
    case ssr = "SSR"
    
    var name: String { return self.rawValue }
}

enum TPStyleSelectRarityType: String, TPStyleSelectItemTypeProtocol {
    case limited = "限量"
    case unLimited = "非限量"
    
    var name: String { return self.rawValue }
}

class TPStyleFilterViewModel: ObservableObject {
    /// 外部传入的筛选类型
    let filterTypes: [TPStyleSelectType]
    
    /// 选中的类型。
    @Published var selectedOptions: [TPStyleSelectType: (any TPStyleSelectItemTypeProtocol)?] = [:]
    
    /// 初始化时传入筛选类型
    init(filterTypes: [TPStyleSelectType]) {
        self.filterTypes = filterTypes
    }
    
    /// 选中/取消选中
    func selectItem(type: TPStyleSelectType, item: any TPStyleSelectItemTypeProtocol) {
        if let selectedItem = selectedOptions[type] as? any TPStyleSelectItemTypeProtocol,
           selectedItem.id == item.id {
            selectedOptions[type] = nil // 取消选中
            debugPrint("fcf 取消选中item:\(item.name)")
        } else {
            selectedOptions[type] = item // 选中新项
            debugPrint("fcf 选中item:\(item.name)")
        }
    }
    
    /// 判断是否选中
    func isSelected(type: TPStyleSelectType, item: (any TPStyleSelectItemTypeProtocol)?) -> Bool {
        guard let item = item else { return false }
        // 如果 selectedOptions[type] 是 nil 则返回 false，避免使用强制转换
        if let selectedItem = selectedOptions[type], selectedItem?.id == item.id {
            return true
        }
        return false
    }
    
    /// 获取当前选中的所有选项
    func getSelectedFilters() -> [TPStyleSelectType: any TPStyleSelectItemTypeProtocol] {
        return selectedOptions.compactMapValues { $0 }
    }
}

struct TPStyleSelectPopView: View {
    @ObservedObject var viewModel: TPStyleFilterViewModel
    var body: some View {
        LazyVStack(spacing: 0.0) {
            closeButton {
                debugPrint("点击了关闭按钮")
            }
            Spacer()
                .frame(height: 8.tp.fitScreen)
            selectContainerView()
            Spacer()
                .frame(height: 30.tp.fitScreen)
            bottomView {
                debugPrint("点击了重置按钮")
            } clickedSure: {
                debugPrint("点击了確認按钮")
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    private func closeButton(clickedClose: @escaping (() -> Void)) -> some View {
        HStack {
            Spacer()
            Button {
                clickedClose()
            } label: {
                Image(uiImage: .add)
                    .frame(width: 24.tp.fitScreen,
                           height: 24.tp.fitScreen)
            }
        }
    }
    
    private func selectContainerView() -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading,
                   spacing: 20.tp.fitScreen) {
                ForEach(viewModel.filterTypes, id: \.self) { type in
//                    let item = viewModel.selectedOptions[type] ?? nil
//                    let isSelected: Bool = viewModel.isSelected(type: type, item: item)
                    TPStyleSelectPopItemsView(type: type, viewModel: viewModel) { item in
                        viewModel.selectItem(type: type, item: item)
                    }
                }
            }
        }
    }
    
    private func bottomView(clickedReset: @escaping (() -> Void),
                            clickedSure: @escaping (() -> Void)) -> some View {
        LazyHStack(spacing: 16.tp.fitScreen) {
            Button {
                clickedReset()
            } label: {
                Text("重置")
                    .boldFont(18)
                    .foregroundColor(.g030)
                    .frame(width: 182.tp.fitScreen, height: 48.tp.fitScreen)
                    .background(UIColor.g006.color)
                    .cornerRadius(24.tp.fitScreen)
            }
            Button {
                clickedSure()
            } label: {
                Text("確認")
                    .boldFont(18)
                    .foregroundColor(.y10FED)
                    .frame(width: 182.tp.fitScreen, height: 48.tp.fitScreen)
                    .background(UIColor.g000.color)
                    .cornerRadius(24.tp.fitScreen)
            }
        }
    }
}

struct TPStyleSelectPopItemsView: View {
    var type: TPStyleSelectType  // 接收筛选类型
    var viewModel: TPStyleFilterViewModel // 直接传入 ViewModel
    var selectAction: (any TPStyleSelectItemTypeProtocol) -> Void  // 传递选择回调
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12.tp.fitScreen) {
            Text(type.title)
                .font(12)
                .foregroundColor(.g000)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16.tp.fitScreen) {
                    ForEach(type.defaultItems, id: \.id) { item in
                        TPStyleSelectPopItemView(
                            type: item,
                            isSelected: viewModel.isSelected(type: type, item: item) // ✅ 关键修正
                        )
                            .onTapGesture {
                                selectAction(item)  // 调用回调
                            }
                    }
                }
            }
        }
    }
}

struct TPStyleSelectPopItemView: View {
    var type: any TPStyleSelectItemTypeProtocol
    let isSelected: Bool
    var body: some View {
        Text(type.name)
            .font(12)
            .foregroundColor(.g070)
            .padding(EdgeInsets(top: 6.tp.fitScreen, leading: 24.tp.fitScreen, bottom: 6.tp.fitScreen, trailing: 24.tp.fitScreen))
            .backgroundColor(isSelected ? UIColor.yFEDAA3: UIColor.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 14.tp.fitScreen)
                    .inset(by: 1.0)
                    .stroke(isSelected ? UIColor.yFEDAA3.color: UIColor.g030.color)
            )
            .cornerRadius(14.tp.fitScreen)
    }
}

#Preview {
    TPStyleSelectPopView(viewModel: TPStyleFilterViewModel(filterTypes: [.validity,.goodsType,.goodsLevel]))
}
