import SwiftUI
import Charts

struct RightPanelView: View {
    let storageData = [
        (name: "Documents", value: 35, color: DesignSystem.Colors.documents),
        (name: "Images", value: 25, color: DesignSystem.Colors.images),
        (name: "Videos", value: 20, color: DesignSystem.Colors.videos),
        (name: "Audio", value: 10, color: DesignSystem.Colors.audio),
        (name: "Other", value: 10, color: DesignSystem.Colors.textSecondary)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    Text("Storage")
                        .font(DesignSystem.Typography.formaH2)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    // Chart Card
                    VStack(spacing: DesignSystem.Spacing.generous) {
                        ZStack {
                            Chart(storageData, id: \.name) { item in
                                SectorMark(
                                    angle: .value("Size", item.value),
                                    innerRadius: .ratio(0.7),
                                    angularInset: 2
                                )
                                .cornerRadius(6)
                                .foregroundStyle(item.color)
                            }
                            .frame(height: 200)
                            
                            VStack {
                                Text("68%")
                                    .font(DesignSystem.Typography.formaHero)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Text("USED")
                                    .font(DesignSystem.Typography.formaSmall)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .tracking(1.0)
                            }
                        }
                        
                        // Legend
                        VStack(spacing: DesignSystem.Spacing.standard) {
                            ForEach(storageData.prefix(3), id: \.name) { item in
                                HStack {
                                    Circle()
                                        .fill(item.color)
                                        .frame(width: 10, height: 10)
                                    Text(item.name)
                                        .font(DesignSystem.Typography.formaBody)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                    Spacer()
                                    Text("\(item.value)%")
                                        .font(DesignSystem.Typography.formaBodyBold)
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                }
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.generous)
                    .background(DesignSystem.Colors.panelBackground)
                    .cornerRadius(DesignSystem.Layout.cornerRadiusXLarge)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusXLarge)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
                    
                    // Activity Feed
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.generous) {
                        Text("Activity")
                            .font(DesignSystem.Typography.formaH2)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        ZStack(alignment: .topLeading) {
                            // Timeline Line
                            Rectangle()
                                .fill(DesignSystem.Colors.border)
                                .frame(width: 1)
                                .padding(.leading, 20)
                                .frame(maxHeight: .infinity, alignment: .topLeading)
                            
                            VStack(spacing: DesignSystem.Spacing.generous) {
                                ActivityItemView(user: "System", action: "organized", target: "14 files from Downloads", time: "2m ago", type: .success)
                                ActivityItemView(user: "System", action: "scanned", target: "Desktop", time: "15m ago", type: .info)
                                ActivityItemView(user: "You", action: "created rule", target: "Move .pdf to Docs", time: "1h ago", type: .info)
                            }
                        }
                    }
                    
                }
                .padding(DesignSystem.Spacing.generous)
            }
        }
        .background(DesignSystem.Colors.panelBackground)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(DesignSystem.Colors.border),
            alignment: .leading
        )
    }
}

struct ActivityItemView: View {
    let user: String
    let action: String
    let target: String
    let time: String
    let type: ActivityType
    var iconDiameter: CGFloat = 24
    
    enum ActivityType {
        case success, info
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.large) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.panelBackground)
                    .frame(width: iconDiameter, height: iconDiameter)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    .overlay(
                        Circle()
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
                
                Image(systemName: type == .success ? "checkmark.circle.fill" : "bell.fill")
                    .foregroundColor(type == .success ? DesignSystem.Colors.sage : DesignSystem.Colors.steelBlue)
                    .font(.system(size: 12))
            }
            .frame(width: iconDiameter, height: iconDiameter)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.micro) {
                Text("\(user) ")
                    .font(DesignSystem.Typography.formaBodyBold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                + Text("\(action) ")
                    .font(DesignSystem.Typography.formaBody)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                + Text(target)
                    .font(DesignSystem.Typography.formaBody)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(time)
                    .font(DesignSystem.Typography.formaSmall)
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }
            
            Spacer()
        }
        .padding(.leading, 8)
    }
}
