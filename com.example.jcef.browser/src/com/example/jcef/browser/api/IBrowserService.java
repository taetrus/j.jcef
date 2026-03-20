package com.example.jcef.browser.api;

import java.awt.Component;

/**
 * OSGi service that provides JCEF browser components.
 * The service manages the CEF runtime lifecycle.
 */
public interface IBrowserService {

    /**
     * Creates a new browser UI component for the given URL.
     * Embed the returned component in a Swing container.
     */
    Component createBrowser(String url);

    /**
     * Shuts down the CEF runtime. Call before application exit.
     */
    void shutdown();
}
