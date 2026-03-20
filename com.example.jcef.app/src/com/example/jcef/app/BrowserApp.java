package com.example.jcef.app;

import com.example.jcef.browser.api.IBrowserService;
import org.osgi.service.component.annotations.Activate;
import org.osgi.service.component.annotations.Component;
import org.osgi.service.component.annotations.Deactivate;
import org.osgi.service.component.annotations.Reference;

import javax.swing.JFrame;
import javax.swing.SwingUtilities;
import java.awt.BorderLayout;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;

/**
 * DS component that consumes {@link IBrowserService} and displays
 * the browser inside a Swing JFrame.
 */
@Component(immediate = true)
public class BrowserApp {

    private static final String DEFAULT_URL = "https://www.example.com";

    private IBrowserService browserService;

    @Reference
    void setBrowserService(IBrowserService service) {
        this.browserService = service;
    }

    @Activate
    void activate() {
        System.out.println("[App] Browser service bound, launching window...");
        SwingUtilities.invokeLater(() -> {
            java.awt.Component browser = browserService.createBrowser(DEFAULT_URL);

            JFrame frame = new JFrame("JCEF Browser");
            frame.getContentPane().add(browser, BorderLayout.CENTER);
            frame.setSize(1024, 768);
            frame.setLocationRelativeTo(null);
            frame.setDefaultCloseOperation(JFrame.DO_NOTHING_ON_CLOSE);
            frame.addWindowListener(new WindowAdapter() {
                @Override
                public void windowClosing(WindowEvent e) {
                    browserService.shutdown();
                    frame.dispose();
                }
            });
            frame.setVisible(true);
            System.out.println("[App] Frame visible.");
        });
    }

    @Deactivate
    void deactivate() {
        // Window disposal handled by window close listener
    }
}
