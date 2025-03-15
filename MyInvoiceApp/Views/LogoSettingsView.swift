import SwiftUI

struct LogoSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dbManager: DatabaseManager
    
    // Para previsualizar la ruta actual
    @State private var currentLogoPath: String = ""
    // Para mostrar la imagen en la vista
    @State private var previewImage: NSImage? = nil
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Configurar Logo").font(.title2)
            
            if let img = previewImage {
                // Muestra la imagen a modo de preview
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 100)
            } else {
                Text("No hay logo seleccionado")
                    .foregroundColor(.secondary)
            }
            
            Button("Elegir Logo…") {
                pickLogoFile()
            }
            .padding(.top, 10)
            
            // Botón para limpiar y volver a la imagen por defecto
            Button("Restaurar Logo por defecto") {
                dbManager.setSettingValue("", forKey: "custom_logo_path")
                loadCurrentLogo()
            }
            .foregroundColor(.red)
            .padding(.top, 10)
            
            Spacer()
            Button("Cerrar") {
                dismiss()
            }
        }
        .padding()
        .frame(width: 400, height: 300)
        .onAppear {
            loadCurrentLogo()
        }
    }
    
    private func loadCurrentLogo() {
        // Leer la ruta guardada en app_settings
        let storedPath = dbManager.getSettingValue(forKey: "custom_logo_path")
        currentLogoPath = storedPath
        
        if !storedPath.isEmpty {
            // Cargar la imagen
            let url = URL(fileURLWithPath: storedPath)
            if let nsimg = NSImage(contentsOf: url) {
                previewImage = nsimg
            } else {
                previewImage = nil
            }
        } else {
            // Sin ruta => sin preview (o la default)
            previewImage = nil
        }
    }
    
    private func pickLogoFile() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["png", "jpg", "jpeg"]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Seleccionar imagen para el logo"
        
        if panel.runModal() == .OK, let url = panel.url {
            // Guardamos la ruta en DB (ORIGINAL)
            // dbManager.setSettingValue(url.path, forKey: "custom_logo_path") // COMENTADO para no borrarlo

            // NUEVO: copiamos la imagen a ApplicationSupport para que el path no se pierda
            do {
                let fm = FileManager.default
                let appSupport = try fm.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                let destURL = appSupport.appendingPathComponent(url.lastPathComponent)
                
                // Si ya existe, lo borramos
                if fm.fileExists(atPath: destURL.path) {
                    try fm.removeItem(at: destURL)
                }
                
                // Copiamos
                try fm.copyItem(at: url, to: destURL)
                
                // Guardamos la nueva ruta interna
                dbManager.setSettingValue(destURL.path, forKey: "custom_logo_path")
                
                // Recargamos preview
                loadCurrentLogo()
                
            } catch {
                print("ERROR al copiar el logo seleccionado: \(error)")
            }
        }
    }
}
