# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Minimal OSGi bundle built with **Tycho 4.0.4** that embeds a Chromium browser (JCEF) inside a Swing JFrame. Designed for deployment on airgapped networks with limited Nexus proxy access to Maven Central.

## Build Commands

```bash
# First-time setup: download JCEF JARs to lib/ (requires Maven Central access)
./scripts/setup.sh

# Point to a custom Nexus instance instead of Maven Central
MAVEN_REPO_URL=https://nexus.internal/repository/maven-central ./scripts/setup.sh

# Build the OSGi bundle
mvn clean verify
```

## Architecture

- **Tycho `eclipse-plugin` packaging** — dependencies are resolved from MANIFEST.MF, not pom.xml `<dependencies>`. The parent POM's p2 repository provides `org.osgi.framework`.
- **Embedded JARs pattern** — JCEF JARs (`jcefmaven.jar`, `jcef-api.jar`) live in `com.example.jcef.app/lib/` and are referenced via `Bundle-ClassPath` in MANIFEST.MF. This avoids needing JCEF to have OSGi metadata.
- **JCEF native binaries** (~100MB Chromium engine) are downloaded at runtime by jcefmaven into `jcef-bundle/`. For airgapped: run once on a connected machine, then copy that directory.

## Key Constraints

- If you add JARs to `lib/`, you **must** also add them to `Bundle-ClassPath` in `META-INF/MANIFEST.MF` and ensure `lib/` is in `bin.includes` in `build.properties`.
- The p2 repository URL in the parent `pom.xml` must be changed to a local mirror for airgapped builds.
- macOS requires `-XstartOnFirstThread` JVM argument to run JCEF.
- Java 17+ required (`Bundle-RequiredExecutionEnvironment: JavaSE-17`).
