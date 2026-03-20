# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OSGi bundle built with **Tycho 4.0.4** that embeds a Chromium browser (JCEF) inside a Swing JFrame. Uses **OSGi Declarative Services** (Felix SCR) for component lifecycle. Designed for deployment on airgapped networks with limited Nexus proxy access to Maven Central.

## Build Commands

```bash
# First-time setup: download JCEF JARs to lib/ (requires Maven Central access)
./scripts/setup.sh                          # Linux/macOS or Git Bash on Windows
.\scripts\setup.ps1                         # Windows PowerShell

# Point to a custom Nexus instance instead of Maven Central
MAVEN_REPO_URL=https://nexus.internal/repository/maven-central ./scripts/setup.sh
$env:MAVEN_REPO_URL="https://nexus.internal/repository/maven-central"; .\scripts\setup.ps1

# Build the OSGi bundle only
mvn clean verify

# Build the full runnable product (Equinox + Felix SCR + app, produces jcef-browser.exe)
mvn clean package
```

## Run Commands

```bash
# Standalone (no OSGi container, DS not active):
java -cp "com.example.jcef.app\target\com.example.jcef.app-1.0.0-SNAPSHOT.jar;com.example.jcef.app\lib\*" com.example.jcef.app.BrowserWindow

# Full OSGi product (after mvn package, DS active via Felix SCR):
.\com.example.jcef.product\target\products\com.example.jcef.product\win32\win32\x86_64\jcef-browser.exe
```

## Architecture

- **Tycho `eclipse-plugin` packaging** — dependencies resolved from MANIFEST.MF, not pom.xml `<dependencies>`. The parent POM's p2 repository (Eclipse 4.30) provides OSGi framework and Felix SCR bundles.
- **Embedded JARs pattern** — JCEF JARs live in `com.example.jcef.app/lib/` and are referenced via `Bundle-ClassPath` in MANIFEST.MF. This avoids needing JCEF to have OSGi metadata.
- **OSGi Declarative Services** — `BrowserComponent` is declared as an immediate `@Component`. The component descriptor is in `OSGI-INF/com.example.jcef.app.BrowserComponent.xml` (written manually; `tycho-ds-plugin` auto-runs but does not generate XML when the DS annotations package cannot be resolved as optional). Felix SCR reads the descriptor and calls `activate()` on bundle start.
- **Product module** — `com.example.jcef.product` uses `eclipse-repository` packaging with a `.product` file. `mvn package` materializes a self-contained runnable product via `tycho-p2-director-plugin`.
- **JCEF native binaries** (~100MB Chromium engine) are downloaded at runtime by jcefmaven into `jcef-bundle/`. For airgapped: run once on a connected machine, then copy that directory next to the executable.

## Module Structure

```
pom.xml                          # Parent reactor (Tycho 4.0.4)
com.example.jcef.app/            # eclipse-plugin: the OSGi bundle
com.example.jcef.product/        # eclipse-repository: runnable product definition
scripts/
  setup.sh                       # Download JCEF JARs (Linux/macOS/Git Bash)
  setup.ps1                      # Download JCEF JARs (Windows PowerShell)
```

## Key Constraints

- If you add JARs to `lib/`, you **must** also add them to `Bundle-ClassPath` in `META-INF/MANIFEST.MF` and ensure `lib/` is in `bin.includes` in `build.properties`.
- If you add or rename DS components, update `OSGI-INF/<classname>.xml` and the `Service-Component: OSGI-INF/*.xml` header in MANIFEST.MF. Do not rely on `tycho-ds-plugin` to auto-generate the XML in this project.
- `OSGI-INF/` must be listed in `bin.includes` in `build.properties` or the packaging step will fail.
- The p2 repository URL in the parent `pom.xml` must be changed to a local mirror for airgapped builds.
- macOS requires `-XstartOnFirstThread` JVM argument (already set in the `.product` launcher args).
- Java 17+ required (`Bundle-RequiredExecutionEnvironment: JavaSE-17`).
- For OSGi product deployment, copy `jcef-bundle/` next to `jcef-browser.exe`. The `install.lock` file tells jcefmaven to skip re-downloading.
