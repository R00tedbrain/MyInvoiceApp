import SwiftUI
import AppKit

// ScaledView (igual que siempre)
struct ScaledView<Content: View>: View {
    let scale: CGFloat
    let content: Content

    init(scale: CGFloat, @ViewBuilder _ builder: () -> Content) {
        self.scale = scale
        self.content = builder()
    }

    var body: some View {
        content
            .scaleEffect(scale, anchor: .topLeading)
    }
}

// MultiPageNSView con extraTopMargin
class MultiPageNSView<RootView: View>: NSView {
    let hostingView: NSHostingView<RootView>

    private let extraTopMargin: CGFloat = 80

    init(rootView: RootView) {
        self.hostingView = NSHostingView(rootView: rootView)
        super.init(frame: .zero)
        addSubview(hostingView)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        hostingView.frame = bounds
    }

    private func printableRect(for printInfo: NSPrintInfo) -> NSRect {
        // Toma todo el papel (márgenes = 0, etc.)
        let paper = printInfo.paperSize
        return NSRect(x: 0, y: 0, width: paper.width, height: paper.height)
    }

    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        guard let printOp = NSPrintOperation.current else { return false }

        hostingView.layoutSubtreeIfNeeded()

        let usableRect = printableRect(for: printOp.printInfo)
        let contentH = hostingView.fittingSize.height

        let totalHeight = contentH + extraTopMargin
        self.frame.size = CGSize(width: usableRect.width, height: totalHeight)

        // Desplazamos el hostingView
        hostingView.frame = CGRect(x: 0, y: extraTopMargin,
                                   width: usableRect.width,
                                   height: contentH)

        let pageCount = Int(ceil(totalHeight / usableRect.height))
        range.pointee = NSMakeRange(1, pageCount)
        return true
    }

    override func rectForPage(_ page: Int) -> NSRect {
        guard let printOp = NSPrintOperation.current else { return .zero }
        let usableRect = printableRect(for: printOp.printInfo)
        let pageIndex  = page - 1
        let yOffset    = CGFloat(pageIndex) * usableRect.height
        let totalH     = self.frame.size.height

        let remaining = totalH - yOffset
        if remaining <= 0 { return .zero }

        let thisPageHeight = min(usableRect.height, remaining)
        return NSRect(x: 0, y: yOffset,
                      width: usableRect.width,
                      height: thisPageHeight)
    }
}

// PrintPreviewView: usa la vista paginada (PagedInvoiceDetailView) y ahora incluye un ScrollView para previsualizar la factura completa
struct PrintPreviewView: View {
    let invoice: Invoice

    // AÑADIDO: necesitamos el dbManager para inyectarlo en PagedInvoiceDetailView
    @EnvironmentObject var dbManager: DatabaseManager  // AÑADIDO

    let forcedScale: CGFloat = 0.85

    var body: some View {
        VStack {
            Text("Vista previa (25 filas máx. por página)")
                .font(.headline)
                .padding(.bottom, 8)

            // Se envuelve la vista paginada en un ScrollView para permitir el desplazamiento vertical
            ScrollView {
                PagedInvoiceDetailView(invoice: invoice)
                    .environmentObject(dbManager) // AÑADIDO, por si se requiere en previsualización
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Button("Imprimir") {
                    printDirectly()
                }
                Button("Exportar PDF") {
                    exportPDFDirectly()
                }
                Button("Cerrar") {
                    // Por ser .sheet, se cierra con el environment dismiss
                    NSApp.keyWindow?.close() // o environment(\.dismiss)
                }
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func printDirectly() {
        // AÑADIDO environmentObject para la subvista
        let scaled = ScaledView(scale: forcedScale) {
            PagedInvoiceDetailView(invoice: invoice)
                .environmentObject(dbManager)
        }
        let multiPageView = MultiPageNSView(rootView: scaled)

        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.paperSize = NSSize(width: 595, height: 842) // A4
        printInfo.orientation = .portrait

        // Márgenes = 0 para no recortar
        printInfo.leftMargin   = 0
        printInfo.rightMargin  = 0
        printInfo.topMargin    = 0
        printInfo.bottomMargin = 0
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered   = false
        printInfo.horizontalPagination   = .clip
        printInfo.verticalPagination     = .clip
        printInfo.scalingFactor         = 1.0

        multiPageView.hostingView.layoutSubtreeIfNeeded()
        multiPageView.hostingView.frame = multiPageView.bounds

        let op = NSPrintOperation(view: multiPageView, printInfo: printInfo)
        op.showsPrintPanel = true
        op.showsProgressPanel = true
        op.run()
    }

    private func exportPDFDirectly() {
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

        multiPageView.hostingView.layoutSubtreeIfNeeded()
        multiPageView.hostingView.frame = multiPageView.bounds

        let op = NSPrintOperation(view: multiPageView, printInfo: printInfo)
        op.showsPrintPanel = false
        op.showsProgressPanel = false

        let panel = NSSavePanel()
        panel.title = "Exportar Factura a PDF"
        panel.nameFieldStringValue = "Factura-\(invoice.invoiceNumber)"
        panel.allowedFileTypes = ["pdf"]

        if panel.runModal() == .OK, let url = panel.url {
            op.printInfo.dictionary().setValue("NSPrintSaveJob", forKey: "NSPrintJobDisposition")
            op.printInfo.dictionary().setValue(url, forKey: "NSPrintJobSavingURL")

            let success = op.run()
            if success {
                print("PDF exportado en \(url.path)")
            } else {
                print("ERROR al exportar PDF.")
            }
        }
    }
}
