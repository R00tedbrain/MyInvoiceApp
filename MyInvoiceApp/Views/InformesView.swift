import SwiftUI
import Charts  // Framework nativo de Apple para gráficas (macOS 13+)

/// Estructura auxiliar para la gráfica
struct MonthlyData: Identifiable {
    let id = UUID()
    let month: String   // Por ejemplo "2025-03"
    let total: Double   // Total facturado ese mes
}

struct InformesView: View {
    
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) var dismiss
    
    // Fechas para el filtro
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date   = Date()
    
    // Resultados
    @State private var filteredInvoices: [Invoice] = []
    @State private var totalBaseImponible: Double = 0
    @State private var totalIVA: Double = 0
    @State private var totalIRPF: Double = 0
    @State private var totalFactura: Double = 0
    
    // Datos para la gráfica
    @State private var monthlyChartData: [MonthlyData] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Informes de Facturación")
                .font(.title)
            
            // Filtro de fechas
            HStack {
                Text("Desde:")
                DatePicker("", selection: $startDate, displayedComponents: .date)
                    .labelsHidden()
                
                Text("Hasta:")
                DatePicker("", selection: $endDate, displayedComponents: .date)
                    .labelsHidden()
                
                Button("Generar Informe") {
                    generarInforme()
                }
            }
            .padding(.bottom, 8)
            
            // Totales en el período
            VStack(alignment: .leading, spacing: 4) {
                Text("Totales en el período:")
                    .font(.headline)
                HStack {
                    Text("Base Imponible:")
                    Spacer()
                    Text(String(format: "%.2f €", totalBaseImponible))
                }
                HStack {
                    Text("Total IVA:")
                    Spacer()
                    Text(String(format: "%.2f €", totalIVA))
                }
                HStack {
                    Text("Total IRPF:")
                    Spacer()
                    Text(String(format: "%.2f €", totalIRPF))
                }
                HStack {
                    Text("Total Factura:")
                        .fontWeight(.bold)
                    Spacer()
                    Text(String(format: "%.2f €", totalFactura))
                        .fontWeight(.bold)
                }
            }
            .padding(.bottom, 8)
            
            // Lista de facturas filtradas
            if !filteredInvoices.isEmpty {
                Text("Facturas encontradas: \(filteredInvoices.count)")
                    .font(.headline)
                
                List(filteredInvoices) { inv in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Factura N.º \(inv.invoiceNumber)")
                            .font(.subheadline)
                        Text("Fecha: \(inv.invoiceDate)")
                        Text(String(format: "Total: %.2f €", inv.totalFactura))
                            .fontWeight(.bold)
                    }
                }
                .frame(minHeight: 200)
            } else {
                Text("No hay facturas en este rango.")
                    .foregroundColor(.secondary)
            }
            
            // Gráficos: “Quesito” + Barras
            if !monthlyChartData.isEmpty {
                Text("Facturación por Mes")
                    .font(.headline)
                    .padding(.top, 8)
                
                HStack(alignment: .top, spacing: 30) {
                    
                    // --------- GRÁFICO DE SECTORES (“QUESITO”) ---------
                    Chart(monthlyChartData) { data in
                        SectorMark(
                            angle: .value("Total Facturado", data.total),
                            innerRadius: .ratio(0.6),
                            outerRadius: .ratio(0.95)
                        )
                        .foregroundStyle(by: .value("Mes", data.month))
                        .annotation(position: .overlay) {
                            Text(String(format: "%.0f", data.total))
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 300, height: 300)
                    .chartLegend(.visible)
                    
                    // --------- GRÁFICO DE BARRAS (EXISTENTE) ---------
                    ScrollView(.horizontal) {
                        Chart(monthlyChartData) { data in
                            BarMark(
                                x: .value("Mes", data.month),
                                y: .value("Total Facturado", data.total)
                            )
                        }
                        .frame(height: 300)
                        .padding()
                    }
                }
            } else {
                Text("No hay datos para la gráfica en este rango.")
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            
            // Botón para cerrar la vista
            HStack {
                Spacer()
                Button("Cerrar") {
                    dismiss()
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            generarInforme()
        }
    }
    
    // MARK: - Lógica para generar el informe
    private func generarInforme() {
        // 1. Preparar DateFormatter para parsear invoiceDate (formato "dd/MM/yyyy")
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        
        // 2. Filtrar facturas según startDate y endDate
        let invoices = dbManager.invoices.filter { inv in
            guard let d = df.date(from: inv.invoiceDate) else { return false }
            return (d >= startDate && d <= endDate)
        }
        self.filteredInvoices = invoices
        
        // 3. Calcular sumas globales
        totalBaseImponible = invoices.reduce(0) { $0 + $1.baseImponible }
        totalIVA           = invoices.reduce(0) { $0 + $1.totalIVA }
        totalIRPF          = invoices.reduce(0) { $0 + $1.totalIRPF }
        totalFactura       = invoices.reduce(0) { $0 + $1.totalFactura }
        
        // 4. Construir un diccionario con facturación por mes real
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"  // ejemplo: "2025-03"
        
        var monthlyTotals: [String: Double] = [:]
        
        for inv in invoices {
            if let date = df.date(from: inv.invoiceDate) {
                let key = monthFormatter.string(from: date)
                monthlyTotals[key, default: 0] += inv.totalFactura
            }
        }
        
        // 5. Generar la lista de meses desde startDate hasta endDate (mes a mes)
        var allMonthKeys: [String] = []
        let calendar = Calendar.current
        
        guard let startOfMonth = calendar.date(from: DateComponents(
            year:  calendar.component(.year,  from: startDate),
            month: calendar.component(.month, from: startDate)
        )),
        let endOfMonth = calendar.date(from: DateComponents(
            year:  calendar.component(.year,  from: endDate),
            month: calendar.component(.month, from: endDate)
        )) else {
            self.monthlyChartData = []
            return
        }
        
        var current = startOfMonth
        while current <= endOfMonth {
            let key = monthFormatter.string(from: current)
            allMonthKeys.append(key)
            
            if let next = calendar.date(byAdding: .month, value: 1, to: current) {
                current = next
            } else {
                break
            }
        }
        
        // 6. Para cada mes posible en el rango, asignar el total o 0
        var tempData: [MonthlyData] = []
        for key in allMonthKeys {
            let total = monthlyTotals[key] ?? 0
            tempData.append(MonthlyData(month: key, total: total))
        }
        
        self.monthlyChartData = tempData
    }
}
