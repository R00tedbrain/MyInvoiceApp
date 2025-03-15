import SwiftUI
import AppKit // para NSPrintOperation

struct ContentView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var showCreateInvoice = false
    @State private var showEditInvoice   = false
    @State private var showPrintPreview  = false
    @State private var selectedInvoice: Invoice? = nil

    @State private var showClientsView  = false
    @State private var showReportsView  = false

    // Para Presupuestos, Gastos, Servicios, Emisores
    @State private var showBudgetsView  = false
    @State private var showExpensesView = false
    @State private var showServicesView = false
    @State private var showIssuersView  = false
    
    // Botón para configurar logo
    @State private var showLogoSettings = false

    // Factor de escalado al imprimir
    let forcedScale: CGFloat = 0.85

    var body: some View {
        NavigationView {
            List {
                ForEach(dbManager.invoices) { inv in
                    VStack(alignment: .leading) {
                        Text("Factura N.º \(inv.invoiceNumber)")
                            .font(.headline)
                        Text("Fecha: \(inv.invoiceDate)")
                            .font(.subheadline)
                        Text("Cliente: \(inv.clientName)")
                            .font(.footnote)
                    }
                    .contextMenu {
                        Button("Editar") {
                            // Aseguramos tomar la versión más reciente del invoice (por si se acaba de guardar)
                            if let updated = dbManager.invoices.first(where: { $0.id == inv.id }) {
                                selectedInvoice = updated
                            } else {
                                selectedInvoice = inv
                            }
                            showEditInvoice = true
                        }
                        Button("Eliminar", role: .destructive) {
                            dbManager.deleteInvoice(inv)
                        }
                        Button("Ver / Imprimir (preview)") {
                            // Tomamos la versión actualizada
                            if let updated = dbManager.invoices.first(where: { $0.id == inv.id }) {
                                selectedInvoice = updated
                            } else {
                                selectedInvoice = inv
                            }
                            showPrintPreview = true
                        }
                        Button("Imprimir directo") {
                            // Tomamos la versión actualizada
                            let invoiceToPrint = dbManager.invoices.first(where: { $0.id == inv.id }) ?? inv
                            printDirectly(invoice: invoiceToPrint)
                        }
                        Button("Exportar PDF directo") {
                            let invoiceToExport = dbManager.invoices.first(where: { $0.id == inv.id }) ?? inv
                            exportPDFDirectly(invoice: invoiceToExport)
                        }
                        Button("Exportar PDF sin panel") {
                            let invoiceToExport = dbManager.invoices.first(where: { $0.id == inv.id }) ?? inv
                            exportPDFDirectlyNoPanel(invoice: invoiceToExport)
                        }
                    }
                }
            }
            .navigationTitle("Facturas")
            .toolbar {
                ToolbarItemGroup {
                    // Botón Nueva Factura
                    Button {
                        showCreateInvoice = true
                    } label: {
                        Label("Nueva factura", systemImage: "plus")
                    }
                    // Botón Clientes
                    Button {
                        showClientsView = true
                    } label: {
                        Label("Clientes", systemImage: "person.2.fill")
                    }
                    // Botón Emisores
                    Button {
                        showIssuersView = true
                    } label: {
                        Label("Emisores", systemImage: "building.2.fill")
                    }
                    // Backup DB
                    Button {
                        backupDatabaseAction()
                    } label: {
                        Label("Backup DB", systemImage: "externaldrive.badge.plus")
                    }
                    // Restaurar DB
                    Button {
                        loadDatabaseAction()
                    } label: {
                        Label("Cargar DB", systemImage: "arrow.down.doc")
                    }
                    // Informes
                    Button {
                        showReportsView = true
                    } label: {
                        Label("Informes", systemImage: "doc.text.magnifyingglass")
                    }
                    
                    // NUEVOS BOTONES: Presupuestos, Gastos, Servicios
                    Button {
                        showBudgetsView = true
                    } label: {
                        Label("Presupuestos", systemImage: "doc.text.fill")
                    }
                    Button {
                        showExpensesView = true
                    } label: {
                        Label("Gastos", systemImage: "cart.fill")
                    }
                    Button {
                        showServicesView = true
                    } label: {
                        Label("Servicios", systemImage: "wrench.and.screwdriver")
                    }
                    
                    // Configurar Logo
                    Button {
                        showLogoSettings = true
                    } label: {
                        Label("Logo", systemImage: "photo")
                    }
                }
            }

            ZStack {
                // Imagen con opacidad baja
                Image("etm")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300)
                    .opacity(0.1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Ventanas emergentes
        .sheet(isPresented: $showCreateInvoice) {
            CreateInvoiceView()
        }
        .sheet(isPresented: $showEditInvoice) {
            if let invoice = selectedInvoice {
                CreateInvoiceView(invoiceToEdit: invoice)
            }
        }
        .sheet(isPresented: $showPrintPreview) {
            if let invoice = selectedInvoice {
                PrintPreviewView(invoice: invoice)
                    .environmentObject(dbManager) // Inyectamos DB
            }
        }
        .sheet(isPresented: $showClientsView) {
            ClientsView()
        }
        .sheet(isPresented: $showReportsView) {
            InformesView()
        }
        .sheet(isPresented: $showBudgetsView) {
            BudgetsView()
        }
        .sheet(isPresented: $showExpensesView) {
            ExpensesView()
        }
        .sheet(isPresented: $showServicesView) {
            ServicesView()
        }
        .sheet(isPresented: $showIssuersView) {
            IssuersView()
        }
        .sheet(isPresented: $showLogoSettings) {
            LogoSettingsView()
                .environmentObject(dbManager)
        }
    }

    // MARK: - Acciones backup / restaurar
    private func backupDatabaseAction() {
        let panel = NSSavePanel()
        panel.title = "Exportar Copia de Seguridad"
        panel.nameFieldStringValue = "BackupDB-\(Date().timeIntervalSince1970).sqlite"
        panel.allowedFileTypes = ["sqlite"]

        if panel.runModal() == .OK, let url = panel.url {
            _ = dbManager.backupDatabase(to: url)
        }
    }

    private func loadDatabaseAction() {
        let panel = NSOpenPanel()
        panel.title = "Cargar Copia de Seguridad"
        panel.allowedFileTypes = ["sqlite"]

        if panel.runModal() == .OK, let url = panel.url {
            _ = dbManager.restoreDatabase(from: url)
        }
    }

    // MARK: - Impresión directa
    private func printDirectly(invoice: Invoice) {
        let scaled = ScaledView(scale: forcedScale) {
            PagedInvoiceDetailView(invoice: invoice)
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
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()
    }

    // MARK: - Exportar PDF (con panel)
    private func exportPDFDirectly(invoice: Invoice) {
        let scaled = ScaledView(scale: forcedScale) {
            PagedInvoiceDetailView(invoice: invoice)
                .environmentObject(dbManager)
        }
        let multiPageView = MultiPageNSView(rootView: scaled)

        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.paperSize = NSSize(width: 595, height: 842)
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
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false

        let panel = NSSavePanel()
        panel.title = "Exportar Factura a PDF"
        panel.nameFieldStringValue = "Factura-\(invoice.invoiceNumber)"
        panel.allowedFileTypes = ["pdf"]

        if panel.runModal() == .OK, let url = panel.url {
            operation.printInfo.dictionary().setValue("NSPrintSaveJob", forKey: "NSPrintJobDisposition")
            operation.printInfo.dictionary().setValue(url, forKey: "NSPrintJobSavingURL")

            let success = operation.run()
            if success {
                print("PDF exportado en \(url.path)")
            } else {
                print("ERROR al exportar PDF.")
            }
        }
    }

    // MARK: - Exportar PDF sin panel de impresión
    private func exportPDFDirectlyNoPanel(invoice: Invoice) {
        let scaled = ScaledView(scale: forcedScale) {
            PagedInvoiceDetailView(invoice: invoice)
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

        let op = NSPrintOperation(view: multiPageView, printInfo: printInfo)
        op.showsPrintPanel    = false
        op.showsProgressPanel = false

        let panel = NSSavePanel()
        panel.title = "Exportar Factura a PDF (sin panel de impresión)"
        panel.nameFieldStringValue = "Factura-\(invoice.invoiceNumber)"
        panel.allowedFileTypes = ["pdf"]

        if panel.runModal() == .OK, let url = panel.url {
            op.printInfo.jobDisposition = .save
            op.printInfo.dictionary().setValue(url, forKey: NSPrintInfo.AttributeKey.jobSavingURL.rawValue)

            let success = op.run()
            if success {
                print("PDF exportado en \(url.path)")
            } else {
                print("ERROR al exportar PDF (no se completó la operación).")
            }
        }
    }
}
