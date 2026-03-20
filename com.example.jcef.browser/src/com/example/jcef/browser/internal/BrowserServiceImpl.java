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

    private static final String INSTALL_DIR = "jcef-bundle";

    private CefApp cefApp;
    private CefClient client;

    @Activate
    void activate() throws Exception {
        System.out.println("[JCEF] Initializing CEF runtime...");
        CefAppBuilder builder = new CefAppBuilder();
        builder.setInstallDir(new File(INSTALL_DIR));
        builder.getCefSettings().windowless_rendering_enabled = false;

        builder.setAppHandler(new MavenCefAppHandlerAdapter() {
            @Override
            public void stateHasChanged(CefApp.CefAppState state) {
                System.out.println("[JCEF] State: " + state);
            }
        });

        cefApp = builder.build();
        client = cefApp.createClient();
        System.out.println("[JCEF] CEF runtime ready.");
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
