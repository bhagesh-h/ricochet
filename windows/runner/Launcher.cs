using System;
using System.IO;
using System.IO.Compression;
using System.Diagnostics;
using System.Reflection;
using System.Windows.Forms;

class Launcher {
    [STAThread]
    static void Main() {
        // Create a unique temporary runtime folder inside the user's Temp directory
        string tempDir = Path.Combine(Path.GetTempPath(), "ricochet_run_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(tempDir);

        try {
            // Extract the embedded payload.zip resource
            Assembly assembly = Assembly.GetExecutingAssembly();
            using (Stream stream = assembly.GetManifestResourceStream("payload.zip")) {
                if (stream == null) {
                    throw new Exception("Embedded software payload was not found inside the executable.");
                }
                using (ZipArchive archive = new ZipArchive(stream)) {
                    archive.ExtractToDirectory(tempDir);
                }
            }

            // Configure target executable parameters
            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.WorkingDirectory = tempDir;
            startInfo.FileName = Path.Combine(tempDir, "ricochet.exe");
            
            // Forward any incoming command-line parameters to the subprocess
            string[] args = Environment.GetCommandLineArgs();
            if (args.Length > 1) {
                startInfo.Arguments = string.Join(" ", args, 1, args.Length - 1);
            }

            // Start the main Ricochet process and wait for it to exit
            using (Process process = Process.Start(startInfo)) {
                process.WaitForExit();
            }
        }
        catch (Exception ex) {
            MessageBox.Show("Failed to launch Ricochet: " + ex.Message, "Execution Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally {
            // Clean up all unpacked binary DLLs and data assets silently
            try {
                if (Directory.Exists(tempDir)) {
                    Directory.Delete(tempDir, true);
                }
            }
            catch {}
        }
    }
}
