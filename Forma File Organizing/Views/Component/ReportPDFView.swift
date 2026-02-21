import SwiftUI

struct ReportPDFView: View {
    let report: AnalyticsReport
    let pageSize = CGSize(width: 612, height: 792) // US Letter @ 72 DPI
    
    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.generous) {
            // Header
            VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                Text("Forma Analytics Report")
                    .font(.system(size: 24, weight: .bold)) // Using system fonts for PDF reliability
                    .foregroundColor(.formaSteelBlue)
                
                Text("\(report.period.description) • Generated \(DateFormatter.short.string(from: report.generatedAt))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.formaSecondaryLabel)
            }
            .padding(.bottom, FormaSpacing.large)
            
            // Sections
            ForEach(report.sections, id: \.title) { section in
                VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                    Text(section.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.formaObsidian)
                    
                    Text(section.body)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.formaLabel)
                    
                    // Metrics Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: FormaSpacing.standard) {
                        ForEach(Array(section.metrics.keys.sorted()), id: \.self) { key in
                            if let value = section.metrics[key] {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(key)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.formaSecondaryLabel)
                                    Text(value)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.formaSteelBlue)
                                }
                            }
                        }
                    }
                    .padding(.top, FormaSpacing.tight)
                }
                .padding()
                .background(Color.formaControlBackground)
                .formaCornerRadius(FormaRadius.card)
            }
            
            // Recommendations
            if !report.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    Text("Recommendations")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.formaWarmOrange)
                    
                    ForEach(report.recommendations.sorted(by: { $0.priority < $1.priority })) { rec in
                        HStack(alignment: .top, spacing: FormaSpacing.standard) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.formaWarmOrange)
                                .font(.system(size: 14))
                                .padding(.top, 2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rec.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.formaLabel)
                                Text(rec.detail)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.formaSecondaryLabel)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.formaWarmOrange.opacity(Color.FormaOpacity.subtle))
                .formaCornerRadius(FormaRadius.card)
            }
            
            Spacer()
            
            // Footer
            HStack {
                Spacer()
                Text("Forma File Organizing System")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.formaSecondaryLabel)
                Spacer()
            }
        }
        .padding(40) // Margins
        .frame(width: pageSize.width, height: pageSize.height, alignment: .topLeading)
        .background(Color.formaBoneWhite)
    }
}

private extension ReportPeriod {
    var description: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .custom: return "Custom"
        }
    }
}

private extension DateFormatter {
    static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
