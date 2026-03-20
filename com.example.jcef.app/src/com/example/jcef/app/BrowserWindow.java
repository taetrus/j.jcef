package com.example.jcef.app;

import me.friwi.jcefmaven.CefAppBuilder;
import me.friwi.jcefmaven.MavenCefAppHandlerAdapter;
import org.cef.CefApp;
import org.cef.CefClient;
import org.cef.browser.CefBrowser;

import javax.swing.JFrame;
import javax.swing.SwingUtilities;
import java.awt.BorderLayout;
import java.awt.Dialog;
import java.awt.Frame;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.io.File;

public class BrowserWindow {

    private static final String DEFAULT_URL = "https://www.apple.com";
    private static final String INSTALL_DIR = "jcef-bundle";

    public static void main(String[] args) throws Exception {
        System.out.println("[JCEF] Starting...");

        // Invisible modal dialog blocks main() but runs the Cocoa event loop
        // on the AppKit main thread. Without this, main() returns, the main
        // thread exits, and macOS never paints any windows.
        Dialog blocker = new Dialog((Frame) null, "init", true);
        blocker.setUndecorated(true);
        blocker.setSize(0, 0);
        blocker.setLocation(-9999, -9999);

        // CEF initialization on background thread
        new Thread(() -> {
            try {
                System.out.println("[JCEF] Building CefApp...");
                CefAppBuilder builder = new CefAppBuilder();
                builder.setInstallDir(new File(INSTALL_DIR));
                builder.getCefSettings().windowless_rendering_enabled = false;

                builder.setAppHandler(new MavenCefAppHandlerAdapter() {
                    @Override
                    public void stateHasChanged(CefApp.CefAppState state) {
                        System.out.println("[JCEF] State: " + state);
                        if (state == CefApp.CefAppState.TERMINATED) {
                            System.exit(0);
                        }
                    }
                });

                CefApp cefApp = builder.build();
                System.out.println("[JCEF] CefApp built.");

                System.out.println("[JCEF] Creating client...");
                CefClient client = cefApp.createClient();
                System.out.println("[JCEF] Creating browser...");
                CefBrowser browser = client.createBrowser(DEFAULT_URL, false, false);
                System.out.println("[JCEF] Browser created.");

                SwingUtilities.invokeLater(() -> {
                    JFrame frame = new JFrame("JCEF Browser");
                    frame.getContentPane().add(browser.getUIComponent(), BorderLayout.CENTER);
                    frame.setSize(1024, 768);
                    frame.setLocationRelativeTo(null);
                    frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
                    frame.addWindowListener(new WindowAdapter() {
                        @Override
                        public void windowClosing(WindowEvent e) {
                            browser.close(true);
                            client.dispose();
                            cefApp.dispose();
                        }
                    });
                    frame.setVisible(true);
                    System.out.println("[JCEF] Frame visible.");

                    // Dismiss the blocker — main thread will unblock
                    blocker.setVisible(false);
                    blocker.dispose();
                });
            } catch (Exception e) {
                System.err.println("[JCEF] Error: " + e.getMessage());
                e.printStackTrace();
                blocker.setVisible(false);
                blocker.dispose();
            }
        }, "cef-init").start();

        // Block the main/AppKit thread in a modal event loop.
        // This keeps the thread alive and processing Cocoa events
        // so that macOS can actually paint windows.
        System.out.println("[JCEF] Entering main thread event loop...");
        blocker.setVisible(true); // blocks until dismissed
        System.out.println("[JCEF] Main thread event loop exited.");
    }
}
