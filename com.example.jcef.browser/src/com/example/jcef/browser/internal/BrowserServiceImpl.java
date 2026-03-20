package com.example.jcef.browser.internal;

import com.example.jcef.browser.api.IBrowserService;
import me.friwi.jcefmaven.CefAppBuilder;
import me.friwi.jcefmaven.MavenCefAppHandlerAdapter;
import org.cef.CefApp;
import org.cef.CefClient;
import org.cef.browser.CefBrowser;
import org.osgi.service.component.annotations.Activate;
import org.osgi.service.component.annotations.Component;
import org.osgi.service.component.annotations.Deactivate;

import java.io.File;

/**
 * DS component that initialises the CEF runtime and registers
 * {@link IBrowserService} in the OSGi service registry.
 */
@Component(service = IBrowserService.class, immediate = true)
public class BrowserServiceImpl implements IBrowserService {

    private static final String INSTALL_DIR_NAME = "jcef-bundle";

    private CefApp cefApp;
    private CefClient client;
    private File installDir;

    @Activate
    void activate() throws Exception {
        // On macOS, CEF must be initialized on the main AppKit thread.
        // With -XstartOnFirstThread the AWT EDT is the main thread,
        // but OSGi activates components on arbitrary framework threads.
        if (isMac()) {
            System.out.println("[JCEF] macOS detected — initializing CEF on EDT...");
            javax.swing.SwingUtilities.invokeAndWait(this::initCef);
        } else {
            initCef();
        }
    }

    /**
     * Resolves the JCEF native bundle directory. Checks (in order):
     * 1. System property {@code jcef.install.dir} (explicit override)
     * 2. {@code jcef-bundle/} next to the running executable (production deployment)
     * 3. {@code ~/.jcef-bundle/} as a stable fallback that survives {@code mvn clean}
     */
    private static File resolveInstallDir() {
        String override = System.getProperty("jcef.install.dir");
        if (override != null) {
            return new File(override);
        }
        // Check working directory (Equinox launcher sets this to the executable's dir)
        File local = new File(INSTALL_DIR_NAME);
        if (local.isDirectory() && new File(local, "install.lock").exists()) {
            return local;
        }
        // Stable location that survives mvn clean rebuilds
        return new File(System.getProperty("user.home"), "." + INSTALL_DIR_NAME);
    }

    private void initCef() {
        try {
            installDir = resolveInstallDir();
            System.out.println("[JCEF] Initializing CEF runtime (install dir: " + installDir.getAbsolutePath() + ")...");
            CefAppBuilder builder = new CefAppBuilder();
            builder.setInstallDir(installDir);
            builder.getCefSettings().windowless_rendering_enabled = false;
            builder.getCefSettings().root_cache_path = new File(installDir, "cache").getAbsolutePath();

            builder.setAppHandler(new MavenCefAppHandlerAdapter() {
                @Override
                public void stateHasChanged(CefApp.CefAppState state) {
                    System.out.println("[JCEF] State: " + state);
                }
            });

            cefApp = builder.build();
            client = cefApp.createClient();
            System.out.println("[JCEF] CEF runtime ready.");
        } catch (Exception e) {
            throw new RuntimeException("Failed to initialize CEF runtime", e);
        }
    }

    private static boolean isMac() {
        return System.getProperty("os.name", "").toLowerCase().contains("mac");
    }

    @Override
    public java.awt.Component createBrowser(String url) {
        System.out.println("[JCEF] Creating browser for: " + url);
        CefBrowser browser = client.createBrowser(url, false, false);
        return browser.getUIComponent();
    }

    @Override
    public void shutdown() {
        System.out.println("[JCEF] Shutting down CEF runtime...");
        if (client != null) client.dispose();
        if (cefApp != null) cefApp.dispose();
    }

    @Deactivate
    void deactivate() {
        shutdown();
    }
}
