# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OSGi application built with **Tycho 4.0.4** that embeds a Chromium browser (JCEF) inside a Swing JFrame. Split into a **service provider** bundle (`com.example.jcef.browser`) and a **service consumer** bundle (`com.example.jcef.app`) wired together via **OSGi Declarative Services** (Felix SCR). Designed for deployment on airgapped networks with limited Nexus proxy access to Maven Central.

## Build Commands

```bash
# First-time setup: download JCEF JARs to lib/ (requires Maven Central access)
./scripts/setup.sh                          # Linux/macOS or Git Bash on Windows
.\scripts\setup.ps1                         # Windows PowerShell

# Point to a custom Nexus instance instead of Maven Central
MAVEN_REPO_URL=https://nexus.internal/repository/maven-central ./scripts/setup.sh
$env:MAVEN_REPO_URL="https://nexus.internal/repository/maven-central"; .\scripts\setup.ps1

# Build all bundles
mvn clean verify

# Build the full runnable product (Equinox + Felix SCR + bundles → jcef-browser.exe)
mvn clean package
```

## Run Commands

```bash
# Windows (after mvn package):
.\com.example.jcef.product\target\products\com.example.jcef.product\win32\win32\x86_64\jcef-browser.exe

# macOS (after mvn package):
./com.example.jcef.product/target/products/com.example.jcef.product/macosx/cocoa/aarch64/Eclipse.app/Contents/MacOS/jcef-browser

# Linux (after mvn package):
./com.example.jcef.product/target/products/com.example.jcef.product/linux/gtk/x86_64/jcef-browser
```

## Architecture

- **Service provider/consumer split** — `com.example.jcef.browser` exports `IBrowserService` and manages the CEF runtime (CefApp, CefClient). `com.example.jcef.app` consumes the service via DS `@Reference` and creates the JFrame. The app bundle has no JCEF dependency — only the API package.
- **Tycho `eclipse-plugin` packaging** — dependencies resolved from MANIFEST.MF, not pom.xml `<dependencies>`. The parent POM's p2 repository (Eclipse 4.30) provides OSGi framework and Felix SCR bundles.
- **Embedded JARs pattern** — JCEF JARs live in `com.example.jcef.browser/lib/` and are referenced via `Bundle-ClassPath` in its MANIFEST.MF. Only the `api` package is exported; JCEF internals stay encapsulated.
- **OSGi Declarative Services** — Component descriptors are in `OSGI-INF/*.xml` (written manually; `tycho-ds-plugin` auto-runs but does not generate XML when the DS annotations package is marked optional). Felix SCR reads the descriptors and wires services at runtime.
- **Product module** — `com.example.jcef.product` uses `eclipse-repository` packaging with a `.product` file. `mvn package` materializes a self-contained runnable product via `tycho-p2-director-plugin`.
- **JCEF native binaries** (~100MB Chromium engine) are downloaded on first run by jcefmaven. The install directory is resolved in order: (1) `-Djcef.install.dir=<path>` system property, (2) `jcef-bundle/` next to the executable if it contains `install.lock`, (3) `~/.jcef-bundle/` as a stable fallback that survives `mvn clean` rebuilds. For airgapped deployment, pre-populate one of these locations from a connected machine.

## Module Structure

```
pom.xml                          # Parent reactor (Tycho 4.0.4)
com.example.jcef.browser/       # eclipse-plugin: service provider (IBrowserService + JCEF JARs)
com.example.jcef.app/            # eclipse-plugin: service consumer (JFrame display)
com.example.jcef.product/        # eclipse-repository: runnable product definition
scripts/
  setup.sh                       # Download JCEF JARs (Linux/macOS/Git Bash)
  setup.ps1                      # Download JCEF JARs (Windows PowerShell)
```

## Key Constraints

- If you add JARs to `lib/`, you **must** also add them to `Bundle-ClassPath` in `com.example.jcef.browser/META-INF/MANIFEST.MF` and ensure `lib/` is in `bin.includes` in `build.properties`.
- If you add or rename DS components, update `OSGI-INF/<classname>.xml` and the `Service-Component: OSGI-INF/*.xml` header in MANIFEST.MF. Do not rely on `tycho-ds-plugin` to auto-generate the XML in this project.
- `OSGI-INF/` must be listed in `bin.includes` in `build.properties` or the packaging step will fail.
- New service interfaces must be added to `Export-Package` in the provider's MANIFEST.MF and `Import-Package` in the consumer's MANIFEST.MF.
- The p2 repository URL in the parent `pom.xml` must be changed to a local mirror for airgapped builds.
- macOS requires `-XstartOnFirstThread` and `--add-opens` for `sun.awt`, `sun.lwawt`, and `sun.lwawt.macosx` (already set in the `.product` launcher args). The `--add-opens` flags must use `=` format (e.g. `--add-opens=java.desktop/sun.awt=ALL-UNNAMED`) so the Equinox native launcher passes them correctly to the JVM.
- Java 17+ required (`Bundle-RequiredExecutionEnvironment: JavaSE-17`).
- For OSGi product deployment, either copy `jcef-bundle/` next to the executable or to `~/.jcef-bundle/`. The `install.lock` file tells jcefmaven to skip re-downloading. During development, `~/.jcef-bundle/` is preferred since it survives `mvn clean` rebuilds.
- Do **not** copy JCEF JARs into `com.example.jcef.app/lib/` — only the browser bundle (`com.example.jcef.browser/lib/`) should contain them. The app bundle resolves the API via `Import-Package`.
