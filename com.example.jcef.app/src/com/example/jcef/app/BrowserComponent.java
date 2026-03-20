package com.example.jcef.app;

import org.osgi.service.component.annotations.Activate;
import org.osgi.service.component.annotations.Component;
import org.osgi.service.component.annotations.Deactivate;

/**
 * OSGi Declarative Services component. SCR instantiates this immediately on
 * bundle activation and calls {@link #activate()} to launch the browser window.
 *
 * <p>Replaces the BundleActivator pattern — no Bundle-Activator header needed.
 * The component XML is generated at build time by tycho-ds-plugin.
 */
@Component(immediate = true)
public class BrowserComponent {

    @Activate
    void activate() throws Exception {
        BrowserWindow.main(new String[0]);
    }

    @Deactivate
    void deactivate() {
        // CEF cleanup is handled by the window close listener in BrowserWindow
    }
}
