import SwiftUI
import Charts

struct ExpensesView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) var dismiss
    
    // Campos para añadir un nuevo gasto
    @State private var concept: String = ""
    @State private var dateStr: String = ""
    @State private var amount: Double = 0.0
    
    // Lista completa de gastos (todos)
    @State private var expenses: [Expense] = []
    
    // Para edición
    @State private var editExpense: Expense? = nil
    @State private var editConcept: String = ""
    @State private var editDate: String = ""
    @State private var editAmount: Double = 0.0
    @State private var showEditSheet = false
    
    // ----------------------------
    // Filtro de fechas + Gráfica
    // ----------------------------
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    
    // Gastos filtrados según el rango
    @State private var filteredExpenses: [Expense] = []
    
    // Total de gastos en el rango
    @State private var totalFilteredExpenses: Double = 0.0
    
    // Datos mensuales para la gráfica
    private struct MonthlyExpense: Identifiable {
        let id = UUID()
        let month: String  // ejemplo: "2025-03"
        let total: Double
    }
    @State private var monthlyData: [MonthlyExpense] = []
    
    // Alerta de confirmación tras guardar
    @State private var showSuccessAlert = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Gastos Mensuales")
                .font(.largeTitle)
                .padding(.bottom, 8)
            
            // ---------------------------------------------
            // Formulario rápido para añadir un nuevo gasto
            // ---------------------------------------------
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    TextField("Concepto", text: $concept)
                    TextField("Fecha (dd/MM/yyyy)", text: $dateStr)
                    TextField("Cantidad", value: $amount, formatter: NumberFormatter())
                    
                    Button("Añadir Gasto") {
                        dbManager.insertExpense(
                            concept: concept,
                            expenseDate: dateStr,
                            amount: amount
                        )
                        loadExpenses()
                        generateReport()
                        clearFields()
                        
                        // Mostrar alerta de confirmación
                        showSuccessAlert = true
                    }
                    .disabled(concept.isEmpty)
                }
                .frame(width: 250)
                
                Divider()
                
                // -------------------------
                // Lista de gastos filtrados
                // -------------------------
                List {
                    ForEach(filteredExpenses) { exp in
                        VStack(alignment: .leading) {
                            Text(exp.concept)
                                .font(.headline)
                            Text("Fecha: \(exp.expenseDate)")
                            Text(String(format: "Importe: %.2f €", exp.amount))
                                .font(.footnote)
                        }
                        .contextMenu {
                            Button("Editar") {
                                editExpense = exp
                                editConcept = exp.concept
                                editDate    = exp.expenseDate
                                editAmount  = exp.amount
                                showEditSheet = true
                            }
                            Button("Borrar", role: .destructive) {
                                dbManager.deleteExpense(exp)
                                loadExpenses()
                                generateReport()
                            }
                        }
                    }
                }
                .frame(minWidth: 400, minHeight: 300)
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // -------------------------------------
            // BLOQUE de FILTRO de FECHAS + INFORME
            // -------------------------------------
            HStack {
                Text("Filtrar Desde:")
                DatePicker("", selection: $startDate, displayedComponents: .date)
                    .labelsHidden()
                
                Text("Hasta:")
                DatePicker("", selection: $endDate, displayedComponents: .date)
                    .labelsHidden()
                
                Button("Generar Informe") {
                    generateReport()
                }
            }
            
            Text(String(format: "Total Gastos en el período: %.2f €", totalFilteredExpenses))
                .font(.headline)
                .padding(.vertical, 4)
            
            // -----------------------------------------------
            // Gráficos: “Quesito” + Barras
            // -----------------------------------------------
            if !monthlyData.isEmpty {
                Text("Gastos por Mes")
                    .font(.headline)
                    .padding(.top, 6)
                
                HStack(alignment: .top, spacing: 30) {
                    
                    // --------- GRÁFICO DE SECTORES (“QUESITO”) ---------
                    Chart(monthlyData) { data in
                        SectorMark(
                            angle: .value("Total Gastos", data.total),
                            innerRadius: .ratio(0.6),    // para estilo donut
                            outerRadius: .ratio(0.95)
                        )
                        .foregroundStyle(by: .value("Mes", data.month))
                        // Etiqueta sobre el sector (opcional)
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
                        Chart(monthlyData) { data in
                            BarMark(
                                x: .value("Mes", data.month),
                                y: .value("Total Gastos", data.total)
                            )
                        }
                        .frame(height: 300)
                        .padding()
                    }
                }
            } else {
                Text("No hay datos para la gráfica en este rango.")
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            
            // Botón Cerrar
            HStack {
                Spacer()
                Button("Cerrar") {
                    dismiss()
                }
            }
            .padding(.top)
        }
        .padding()
        .frame(minWidth: 900, minHeight: 600) // Tamaño mínimo similar a InformesView
        .onAppear {
            loadExpenses()
            generateReport()
        }
        .sheet(isPresented: $showEditSheet) {
            editView
        }
        // Alerta de confirmación tras guardar un nuevo gasto
        .alert(isPresented: $showSuccessAlert) {
            Alert(
                title: Text("Gasto Agregado"),
                message: Text("Se ha guardado correctamente."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // ---------------------------------------------------
    // Cargar todos los gastos y resetear campos del form
    // ---------------------------------------------------
    private func loadExpenses() {
        expenses = dbManager.fetchAllExpenses()
    }
    
    private func clearFields() {
        concept = ""
        dateStr = ""
        amount = 0.0
    }
    
    // -----------------------------
    // Vista para editar un gasto
    // -----------------------------
    @ViewBuilder
    private var editView: some View {
        if let exp = editExpense {
            VStack(alignment: .leading) {
                Text("Editar Gasto")
                    .font(.headline)
                
                TextField("Concepto", text: $editConcept)
                TextField("Fecha (dd/MM/yyyy)", text: $editDate)
                TextField("Cantidad", value: $editAmount, formatter: NumberFormatter())
                
                HStack {
                    Spacer()
                    Button("Guardar") {
                        let updated = Expense(
                            id: exp.id,
                            concept: editConcept,
                            expenseDate: editDate,
                            amount: editAmount
                        )
                        dbManager.updateExpense(updated)
                        loadExpenses()
                        generateReport()
                        showEditSheet = false
                    }
                    Button("Cancelar") {
                        showEditSheet = false
                    }
                }
                .padding(.top)
            }
            .padding()
            .frame(width: 300)
        }
    }
    
    // ------------------------------------------------
    // Filtrar, calcular total y preparar datos Chart
    // ------------------------------------------------
    private func generateReport() {
        // 1. Filtrar gastos según las fechas
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        
        let filtered = expenses.filter { exp in
            if let d = df.date(from: exp.expenseDate) {
                return (d >= startDate && d <= endDate)
            }
            return false
        }
        self.filteredExpenses = filtered
        
        // 2. Calcular total
        totalFilteredExpenses = filtered.reduce(0) { $0 + $1.amount }
        
        // 3. Agrupar por mes (yyyy-MM) y sumar
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        
        var monthlyTotals: [String: Double] = [:]
        for exp in filtered {
            if let d = df.date(from: exp.expenseDate) {
                let key = monthFormatter.string(from: d)
                monthlyTotals[key, default: 0] += exp.amount
            }
        }
        
        // 4. Crear array ordenado de datos mensuales
        var current = startDate.startOfMonthForExpenses()!
        let lastMonth = endDate.startOfMonthForExpenses()!
        let cal = Calendar.current
        
        var tempData: [MonthlyExpense] = []
        while current <= lastMonth {
            let key = monthFormatter.string(from: current)
            let total = monthlyTotals[key] ?? 0.0
            tempData.append(MonthlyExpense(month: key, total: total))
            
            if let next = cal.date(byAdding: .month, value: 1, to: current) {
                current = next
            } else {
                break
            }
        }
        self.monthlyData = tempData
    }
}

// Helper para coger inicio de mes sin chocar con la otra extension:
extension Date {
    func startOfMonthForExpenses() -> Date? {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: self)
        return cal.date(from: comps)
    }
}
