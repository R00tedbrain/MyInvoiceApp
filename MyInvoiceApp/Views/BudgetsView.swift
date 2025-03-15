import SwiftUI

struct BudgetsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) var dismiss

    @State private var budgets: [Budget] = []
    @State private var showCreateBudget = false
    @State private var showEditBudget   = false

    @State private var selectedBudget: Budget? = nil

    var body: some View {
        VStack {
            Text("Presupuestos")
                .font(.largeTitle)
                .padding(.bottom, 8)

            List(budgets) { bdg in
                VStack(alignment: .leading) {
                    Text("Presupuesto N.º \(bdg.budgetNumber)")
                        .font(.headline)
                    Text("Fecha: \(bdg.budgetDate)")
                    Text(String(format: "Total: %.2f €", bdg.totalBudget))
                        .font(.footnote)
                }
                .contextMenu {
                    Button("Exportar PDF") {
                        selectedBudget = bdg
                        exportBudgetPDFNoPanel(bdg)
                    }
                    Button("Previsualizar") {
                        selectedBudget = bdg
                        previewBudget(bdg)
                    }
                    Button("Editar") {
                        selectedBudget = bdg
                        showEditBudget = true
                    }
                    Button("Borrar", role: .destructive) {
                        dbManager.deleteBudget(bdg)
                        loadBudgets()
                    }
                }
            }
            .frame(minWidth: 500, minHeight: 300)

            HStack {
                Button("Nuevo Presupuesto") {
                    selectedBudget = nil
                    showCreateBudget = true
                }
                Spacer()
                Button("Cerrar") {
                    dismiss()
                }
            }
            .padding(.top, 6)
        }
        .padding()
        .sheet(isPresented: $showCreateBudget, onDismiss: {
            loadBudgets()
        }) {
            CreateBudgetView(budgetToEdit: nil)
                .environmentObject(dbManager)
        }
        .sheet(isPresented: $showEditBudget, onDismiss: {
            loadBudgets()
        }) {
            if let bdg = selectedBudget {
                CreateBudgetView(budgetToEdit: bdg)
                    .environmentObject(dbManager)
            }
        }
        .onAppear {
            loadBudgets()
        }
    }

    private func loadBudgets() {
        budgets = dbManager.fetchAllBudgets()
    }

    // Función para exportar el presupuesto a PDF sin panel
    private func exportBudgetPDFNoPanel(_ budget: Budget) {
        print("DEBUG BudgetsView: exportBudgetPDFNoPanel -> \(budget)")

        let scaled = ScaledView(scale: 0.85) {
            // Inyectamos el dbManager aquí para que PagedBudgetDetailView
            // tenga acceso a .environmentObject(DatabaseManager)
            PagedBudgetDetailView(budget: budget)
                .environmentObject(dbManager)
        }
        let multiPageView = MultiPageNSView(rootView: scaled)

        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.paperSize = NSSize(width: 595, height: 842) // A4
        printInfo.orientation = .portrait
        printInfo.leftMargin   = 0
        printInfo.rightMargin  = 0
        printInfo.topMargin    = 0
        printInfo.bottomMargin = 0
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered   = false
        printInfo.horizontalPagination   = .clip
        printInfo.verticalPagination     = .clip
        printInfo.scalingFactor         = 1.0

        let operation = NSPrintOperation(view: multiPageView, printInfo: printInfo)
        // Sin panel de impresión
        operation.showsPrintPanel    = false
        operation.showsProgressPanel = false

        let panel = NSSavePanel()
        panel.title = "Exportar Presupuesto a PDF (sin panel de impresión)"
        panel.nameFieldStringValue = "Presupuesto-\(budget.budgetNumber)"
        panel.allowedFileTypes = ["pdf"]

        if panel.runModal() == .OK, let url = panel.url {
            operation.printInfo.jobDisposition = .save
            operation.printInfo.dictionary().setValue(
                url,
                forKey: NSPrintInfo.AttributeKey.jobSavingURL.rawValue
            )

            let success = operation.run()
            if success {
                print("PDF exportado en \(url.path)")
            } else {
                print("ERROR BudgetsView: al exportar PDF (No se completó la operación).")
            }
        }
    }

    // Función para previsualizar el presupuesto (mostrando el panel de impresión)
    private func previewBudget(_ budget: Budget) {
        print("DEBUG BudgetsView: previewBudget -> \(budget)")

        let scaled = ScaledView(scale: 0.85) {
            PagedBudgetDetailView(budget: budget)
                .environmentObject(dbManager)
        }
        let multiPageView = MultiPageNSView(rootView: scaled)

        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.paperSize = NSSize(width: 595, height: 842) // A4
        printInfo.orientation = .portrait
        printInfo.leftMargin   = 0
        printInfo.rightMargin  = 0
        printInfo.topMargin    = 0
        printInfo.bottomMargin = 0
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered   = false
        printInfo.horizontalPagination   = .clip
        printInfo.verticalPagination     = .clip
        printInfo.scalingFactor         = 1.0

        let operation = NSPrintOperation(view: multiPageView, printInfo: printInfo)
        // Habilitamos el panel de impresión para previsualizar
        operation.showsPrintPanel    = true
        operation.showsProgressPanel = true

        // Ejecutamos la operación, lo que abrirá la previsualización
        _ = operation.run()
    }
}
