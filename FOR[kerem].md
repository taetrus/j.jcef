# JCEF OSGi Browser - Project Explanation

## What is this?

A minimal Java project that opens a **web browser inside a Swing JFrame** using
JCEF (Java Chromium Embedded Framework) - essentially embedding Chrome into your
Java desktop app. The project is structured as an **OSGi bundle** built with
**Apache Tycho** (Eclipse's Maven-based build system for OSGi/Eclipse projects).

Think of it like a Russian nesting doll:
- **Outermost**: Maven builds everything
- **Middle**: Tycho adds OSGi awareness to Maven
- **Innermost**: Your Java code uses JCEF to embed a Chrome browser in a JFrame

## Project Structure

```
j.jcef/
├── pom.xml                          # The "conductor" - parent POM with Tycho config
├── com.example.jcef.app/            # The actual OSGi bundle
│   ├── pom.xml                      # Says "I'm an eclipse-plugin" (Tycho packaging type)
│   ├── META-INF/MANIFEST.MF         # The bundle's "passport" - OSGi identity & deps
│   ├── build.properties             # Tells Tycho what files go into the bundle JAR
│   ├── lib/                         # JCEF JARs live here (downloaded by setup script)
│   └── src/.../app/
│       ├── Activator.java           # OSGi lifecycle hook - starts the browser
│       └── BrowserWindow.java       # The actual JFrame + JCEF browser code
├── scripts/
│   └── setup.sh                     # Downloads JCEF JARs & reports what Nexus needs
└── .gitignore
```

## Key Concepts

### Why Tycho instead of regular Maven?

Regular Maven doesn't understand OSGi bundles. Tycho is a set of Maven plugins
that teach Maven to:
- Read `MANIFEST.MF` for dependency resolution (instead of pom.xml `<dependencies>`)
- Use Eclipse's p2 repository format (instead of Maven Central)
- Build `eclipse-plugin` artifacts (instead of plain JARs)

It's like Maven learned a second language (OSGi) through Tycho.

### Why is JCEF complicated in OSGi?

JCEF is a **regular Java library** - it doesn't speak OSGi. It's like trying to
plug a US appliance into a European outlet. We need an adapter:

The `lib/` directory approach: we embed the JCEF JARs directly inside the bundle
and list them in `Bundle-ClassPath` in the MANIFEST.MF. This way, the OSGi
framework doesn't need to resolve JCEF from any repository - it's bundled right
inside our plugin, like packing your own adapter when traveling.

### The Airgapped Network Problem

On a normal network, Maven happily downloads everything from the internet.
On an airgapped network with only Nexus access, you need to ensure:

1. **Maven Central artifacts** are cached in Nexus (Tycho plugins, JCEF JARs)
2. **Eclipse p2 repository** is mirrored locally (provides OSGi framework)
3. **JCEF native binaries** (~100MB of Chromium) are pre-downloaded

The `scripts/setup.sh` script handles #1 and #3, and tells you exactly what
needs to be in Nexus. For #2, you mirror the Eclipse update site once.

### How JCEF Works

JCEF wraps the Chromium Embedded Framework (CEF) for Java. The flow:

1. `CefAppBuilder` initializes the native Chromium engine
2. `CefApp` is the singleton Chromium process
3. `CefClient` handles browser events (like page loaded, console messages)
4. `CefBrowser` is the actual browser instance
5. `browser.getUIComponent()` returns a Swing `Component` you add to a JFrame

The `jcefmaven` wrapper handles downloading and extracting the ~100MB native
Chromium binaries on first run. For airgapped use, you pre-extract these
into `jcef-bundle/` and the library detects the `install.lock` file and skips
the download.

## How to Build & Run

```bash
# 1. Download JCEF dependencies (needs internet/Nexus access)
chmod +x scripts/setup.sh
./scripts/setup.sh

# 2. Build with Tycho
mvn clean verify

# 3. Run standalone (the built JAR is in com.example.jcef.app/target/)
# On macOS:
java -XstartOnFirstThread -jar com.example.jcef.app/target/com.example.jcef.app-1.0.0-SNAPSHOT.jar
# On Linux/Windows:
java -jar com.example.jcef.app/target/com.example.jcef.app-1.0.0-SNAPSHOT.jar
```

## Airgapped Deployment Checklist

1. On a connected machine, run `./scripts/setup.sh` - note the artifact list
2. Ensure all listed artifacts are in your Nexus (proxy Maven Central)
3. Mirror the Eclipse p2 repo to a local path or HTTP server
4. Update `pom.xml` p2 repository URL to point to your mirror
5. Run the app once to extract JCEF natives to `jcef-bundle/`
6. Copy `jcef-bundle/` to the airgapped machine alongside the built JAR
7. Point your Maven `settings.xml` to Nexus for all builds
