# JCEF OSGi Browser - Project Explanation

## What is this?

A Java project that opens a **web browser inside a Swing JFrame** using
JCEF (Java Chromium Embedded Framework) — essentially embedding Chrome into your
Java desktop app. The project is structured as two **OSGi bundles** built with
**Apache Tycho** (Eclipse's Maven-based build system for OSGi/Eclipse projects),
using **OSGi Declarative Services** for component lifecycle and service wiring.

Think of it like a Russian nesting doll:
- **Outermost**: Maven builds everything
- **Middle**: Tycho adds OSGi awareness to Maven
- **Inner**: Felix SCR manages component lifecycle and wires services via DS
- **Innermost**: Your Java code uses JCEF to embed a Chrome browser in a JFrame

## Project Structure

```
j.jcef/
├── pom.xml                                  # Parent POM — Tycho config, module list
├── com.example.jcef.browser/               # Service PROVIDER (eclipse-plugin)
│   ├── pom.xml
│   ├── META-INF/MANIFEST.MF                 # Exports com.example.jcef.browser.api
│   ├── build.properties
│   ├── OSGI-INF/
│   │   └── ...BrowserServiceImpl.xml        # DS descriptor with <service><provide>
│   ├── lib/                                 # JCEF JARs (downloaded by setup script)
│   └── src/.../browser/
│       ├── api/IBrowserService.java         # Service interface: createBrowser(), shutdown()
│       └── internal/BrowserServiceImpl.java # @Component managing CefApp/CefClient lifecycle
├── com.example.jcef.app/                    # Service CONSUMER (eclipse-plugin)
│   ├── pom.xml
│   ├── META-INF/MANIFEST.MF                 # Imports com.example.jcef.browser.api
│   ├── build.properties
│   ├── OSGI-INF/
│   │   └── ...BrowserApp.xml                # DS descriptor with <reference> to IBrowserService
│   └── src/.../app/
│       └── BrowserApp.java                  # @Component with @Reference — creates JFrame
├── com.example.jcef.product/                # Runnable product (eclipse-repository)
│   ├── pom.xml                              # tycho-p2-director-plugin → materializes product
│   └── com.example.jcef.product.product     # .product: Equinox + Felix SCR + our bundles
├── scripts/
│   ├── setup.sh                             # Download JCEF JARs (Linux/macOS/Git Bash)
│   └── setup.ps1                            # Download JCEF JARs (Windows PowerShell)
└── .gitignore
```

## Key Concepts

### Why Tycho instead of regular Maven?

Regular Maven doesn't understand OSGi bundles. Tycho is a set of Maven plugins
that teach Maven to:
- Read `MANIFEST.MF` for dependency resolution (instead of pom.xml `<dependencies>`)
- Use Eclipse's p2 repository format (instead of Maven Central)
- Build `eclipse-plugin` and `eclipse-repository` artifacts

It's like Maven learned a second language (OSGi) through Tycho.

### The Service Provider / Consumer Split

The project follows the classic OSGi service pattern:

**Provider** (`com.example.jcef.browser`):
- Owns the JCEF JARs in `lib/` (embedded via `Bundle-ClassPath`)
- Exports only the `com.example.jcef.browser.api` package (the interface)
- `BrowserServiceImpl` is a DS `@Component` that initialises CefApp/CefClient
  on activation and registers `IBrowserService` in the OSGi service registry

**Consumer** (`com.example.jcef.app`):
- Has **zero JCEF dependencies** — only imports the `api` package
- `BrowserApp` is a DS `@Component` with a `@Reference` to `IBrowserService`
- SCR waits for the browser service, then calls `activate()` which creates the JFrame

```
Equinox starts
  → Felix SCR starts (level 2)
  → browser bundle starts (level 3)
    → SCR instantiates BrowserServiceImpl
    → CefApp/CefClient initialised
    → IBrowserService registered in service registry
  → app bundle starts (level 4)
    → SCR sees @Reference satisfied → instantiates BrowserApp
    → BrowserApp.activate() creates JFrame with browserService.createBrowser()
```

### What is OSGi Declarative Services (DS)?

DS is the OSGi way of declaring components that the framework wires together
automatically — similar to Spring's `@Component` but built into the OSGi spec.

Instead of a `BundleActivator` that manually starts things in `start()`, you declare
component classes annotated with `@Component`. The SCR (Service Component Runtime —
in our case, Apache Felix SCR) reads the component descriptor XML and manages the
lifecycle: instantiation, service binding via `@Reference`, activation, deactivation.

The component descriptors (`OSGI-INF/*.xml`) are normally auto-generated from
annotations by `tycho-ds-plugin`. In this project they are written manually because
the DS annotations package cannot be resolved from the p2 repo when marked optional
(the plugin silently skips generation). The XML is equivalent to what the plugin
would have produced.

### Why is JCEF complicated in OSGi?

JCEF is a **regular Java library** — it doesn't speak OSGi. It's like trying to
plug a US appliance into a European outlet. We need an adapter:

The `lib/` directory approach: we embed the JCEF JARs directly inside the browser
bundle and list them in `Bundle-ClassPath` in `MANIFEST.MF`. The OSGi framework
doesn't need to resolve JCEF from any repository — it's bundled right inside our
plugin, like packing your own adapter when traveling. Only the clean API interface
is exported; JCEF internals stay encapsulated.

### The Product Module

`com.example.jcef.product` is an `eclipse-repository` module containing a single
`.product` file. This file declares:
- Which bundles to include (browser + app + Equinox + Felix SCR + Gogo console)
- Start levels for each bundle (SCR at 2, browser at 3, app at 4)
- Runtime properties (`osgi.noShutdown=true`, `eclipse.ignoreApp=true`)
- A native launcher name (`jcef-browser`)

`mvn package` runs `tycho-p2-director-plugin` which resolves all declared bundles
from the Eclipse p2 repository and materializes a self-contained directory you can
zip up and ship. The result includes `jcef-browser.exe` and a `plugins/` directory.

### The Airgapped Network Problem

On a normal network, Maven happily downloads everything from the internet.
On an airgapped network with only Nexus access, you need to ensure:

1. **Maven Central artifacts** are cached in Nexus (Tycho plugins, JCEF JARs)
2. **Eclipse p2 repository** is mirrored locally (provides OSGi framework + Felix SCR)
3. **JCEF native binaries** (~100MB of Chromium) are pre-downloaded

The `scripts/setup.sh` / `setup.ps1` scripts handle #1 and #3, and print exactly
what needs to be in Nexus. For #2, you mirror the Eclipse update site once.

### How JCEF Works

JCEF wraps the Chromium Embedded Framework (CEF) for Java. The flow:

1. `CefAppBuilder` initializes the native Chromium engine
2. `CefApp` is the singleton Chromium process
3. `CefClient` handles browser events (page loaded, console messages, etc.)
4. `CefBrowser` is the actual browser instance
5. `browser.getUIComponent()` returns a Swing `Component` you add to a JFrame

The `jcefmaven` wrapper handles downloading and extracting the ~100MB native
Chromium binaries on first run. The app looks for natives in this order:

1. **`-Djcef.install.dir=<path>`** — explicit override via system property
2. **`jcef-bundle/`** next to the executable — if it contains `install.lock`
3. **`~/.jcef-bundle/`** — stable fallback that survives `mvn clean` rebuilds

Think of it like a package delivery: if you already have the package at your
door (option 2) or in your garage (option 3), the courier skips the trip.
The `install.lock` file is the "delivered" sticker — jcefmaven sees it and
skips downloading entirely.

For airgapped use, pre-populate `~/.jcef-bundle/` or place `jcef-bundle/`
next to the executable.

## How to Build & Run

```bash
# 1. Download JCEF JARs (needs internet/Nexus access) — run once
./scripts/setup.sh                     # Linux/macOS or Git Bash
.\scripts\setup.ps1                    # Windows PowerShell

# 2. Build the full OSGi product
mvn clean package

# 3. Run the product (Equinox + Felix SCR wire the service automatically)
# Windows:
.\com.example.jcef.product\target\products\com.example.jcef.product\win32\win32\x86_64\jcef-browser.exe

# macOS (Apple Silicon):
./com.example.jcef.product/target/products/com.example.jcef.product/macosx/cocoa/aarch64/Eclipse.app/Contents/MacOS/jcef-browser

# Linux:
./com.example.jcef.product/target/products/com.example.jcef.product/linux/gtk/x86_64/jcef-browser
```

### macOS Notes

JCEF on macOS requires special JVM flags that are already configured in the
`.product` file:

- **`-XstartOnFirstThread`** — macOS's AppKit requires the main thread to be the
  UI thread. This flag tells the JVM to use the main thread as the AWT Event
  Dispatch Thread. Think of it like a concert venue that only lets the first person
  in line be the lead singer — macOS insists the main thread handles all UI.
- **`--add-opens` flags** — JCEF's macOS code needs access to internal JDK packages
  (`sun.awt`, `sun.lwawt`, `sun.lwawt.macosx`) to get native window handles. Java's
  module system blocks this by default, so we explicitly open these packages. These
  must use the `=` format (e.g. `--add-opens=java.desktop/sun.awt=ALL-UNNAMED`) —
  the space-separated format gets swallowed by the Equinox native launcher.

## JCEF Natives for Development

During development, `mvn clean` wipes the `target/` directory — including any
`jcef-bundle/` that was downloaded inside the product output. To avoid
re-downloading ~100MB of Chromium binaries on every rebuild:

1. Run the app once on a connected machine — natives download automatically
2. They're saved to `~/.jcef-bundle/` (the stable fallback location)
3. All subsequent runs (even after `mvn clean package`) reuse that copy

You can also explicitly set the location:
```bash
# Override via system property (add to .product vmArgs or command line)
-Djcef.install.dir=/path/to/jcef-bundle
```

## Airgapped Deployment Checklist

1. On a connected machine, run `./scripts/setup.sh` (or `.\scripts\setup.ps1`) — note the printed artifact list
2. Ensure all listed Maven artifacts are in your Nexus (proxy Maven Central)
3. Mirror the Eclipse p2 repo to a local path or HTTP server:
   ```
   https://download.eclipse.org/eclipse/updates/4.30/
   ```
4. Update the `<url>` in the parent `pom.xml` p2 repository to point to your mirror
5. Run `mvn clean package` to build the product
6. Run the product once on a connected machine to download JCEF natives (saved to `~/.jcef-bundle/`)
7. Deploy: copy the materialized product directory to the airgapped machine, **and** either:
   - Copy `~/.jcef-bundle/` to the target user's home directory, **or**
   - Copy it as `jcef-bundle/` next to the executable
8. On the airgapped machine, run the executable — `install.lock` skips any download
