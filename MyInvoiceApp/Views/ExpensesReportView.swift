import SwiftUI
import Charts

struct ExpensesReportView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) var dismiss
    
    // Fechas de filtro
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    
    // Datos
    @State private var filteredExpenses: [Expense] = []
    @State private var totalExpenses: Double = 0.0
    
    // Para el chart
    private struct MonthlyExpense: Identifiable {
        let id = UUID()
        let month: String
        let total: Double
    }
    @State private var monthlyData: [MonthlyExpense] = []
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Informe de Gastos Mensuales")
                .font(.title)
                .padding(.bottom, 6)
            
            HStack {
                Text("Desde:")
                DatePicker("", selection: $startDate, displayedComponents: .date)
                    .labelsHidden()
                Text("Hasta:")
                DatePicker("", selection: $endDate, displayedComponents: .date)
                    .labelsHidden()
                
                Button("Generar Informe") {
                    generateReport()
                }
            }
            
            Divider()
            
            Text(String(format: "Total Gastos en el período: %.2f €", totalExpenses))
                .font(.headline)
                .padding(.vertical, 4)
            
            if !filteredExpenses.isEmpty {
                List(filteredExpenses) { exp in
                    VStack(alignment: .leading) {
                        Text(exp.concept).font(.headline)
                        Text("Fecha: \(exp.expenseDate)")
                        Text(String(format: "Importe: %.2f €", exp.amount))
                            .fontWeight(.bold)
                    }
                }
                .frame(minHeight: 200)
            } else {
                Text("No hay gastos en este rango.")
                    .foregroundColor(.secondary)
            }
            
            // Gráfica
            if !monthlyData.isEmpty {
                Text("Gastos por Mes").font(.headline).padding(.top, 8)
                ScrollView(.horizontal) {
                    Chart(monthlyData) { data in
                        BarMark(
                            x: .value("Mes", data.month),
                            y: .value("Total Gastos", data.total)
                        )
                    }
                    .frame(height: 250)
                }
            } else {
                Text("No hay datos para la gráfica.").foregroundColor(.secondary)
            }
            
            HStack {
                Spacer()
                Button("Cerrar") {
                    dismiss()
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            generateReport()
        }
    }
    
    private func generateReport() {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        
        // Filtrar
        let all = dbManager.fetchAllExpenses()
        let filtered = all.filter { exp in
            if let d = df.date(from: exp.expenseDate) {
                return d >= startDate && d <= endDate
            }
            return false
        }
        self.filteredExpenses = filtered
        
        // Total
        totalExpenses = filtered.reduce(0) { $0 + $1.amount }
        
        // Agrupar por mes
        var monthlyTotals: [String: Double] = [:]
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        
        for exp in filtered {
            if let d = df.date(from: exp.expenseDate) {
                let key = monthFormatter.string(from: d)
                monthlyTotals[key, default: 0] += exp.amount
            }
        }
        
        // Generar array sorted
        // Extraer todos los meses en el rango
        var current = startDate.startOfMonth()!
        let endOfMonth = endDate.startOfMonth()!
        
        var data: [MonthlyExpense] = []
        let calendar = Calendar.current
        
        while current <= endOfMonth {
            let key = monthFormatter.string(from: current)
            let val = monthlyTotals[key] ?? 0
            data.append(MonthlyExpense(month: key, total: val))
            
            if let next = calendar.date(byAdding: .month, value: 1, to: current) {
                current = next
            } else {
                break
            }
        }
        
        monthlyData = data
    }
}

// Helper
extension Date {
    func startOfMonth() -> Date? {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: self)
        return cal.date(from: comps)
    }
}
