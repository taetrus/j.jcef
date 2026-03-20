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
Chromium binaries on first run. For airgapped use, pre-extract these into
`jcef-bundle/` — the library detects `install.lock` and skips the download.

## How to Build & Run

```powershell
# 1. Download JCEF JARs (needs internet/Nexus access) — run once
.\scripts\setup.ps1                    # Windows PowerShell
# ./scripts/setup.sh                  # Linux/macOS or Git Bash

# 2. Build the full OSGi product
mvn clean package

# 3. Run the product (Equinox + Felix SCR wire the service automatically)
.\com.example.jcef.product\target\products\com.example.jcef.product\win32\win32\x86_64\jcef-browser.exe
```

## Airgapped Deployment Checklist

1. On a connected machine, run `.\scripts\setup.ps1` — note the printed artifact list
2. Ensure all listed Maven artifacts are in your Nexus (proxy Maven Central)
3. Mirror the Eclipse p2 repo to a local path or HTTP server:
   ```
   https://download.eclipse.org/eclipse/updates/4.30/
   ```
4. Update the `<url>` in the parent `pom.xml` p2 repository to point to your mirror
5. Run `mvn clean package` to build the product
6. Run the product once on a connected machine to extract JCEF natives to `jcef-bundle/`
7. Deploy: copy the materialized product directory **and** `jcef-bundle/` to the airgapped machine
8. On the airgapped machine: `jcef-browser.exe` — the `install.lock` skips any download
