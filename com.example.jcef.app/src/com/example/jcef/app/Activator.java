package com.example.jcef.app;

import org.osgi.framework.BundleActivator;
import org.osgi.framework.BundleContext;

/**
 * OSGi bundle activator. In OSGi context, launches the browser
 * the same way as the standalone main() entry point.
 */
public class Activator implements BundleActivator {

    @Override
    public void start(BundleContext context) throws Exception {
        BrowserWindow.main(new String[0]);
    }

    @Override
    public void stop(BundleContext context) throws Exception {
        // CEF cleanup handled by window close listener
    }
}
