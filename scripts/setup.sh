#!/bin/bash
#
# Downloads JCEF JARs into the bundle's lib/ directory and prepares
# JCEF native binaries for offline/airgapped use.
#
# Run this script ONCE on a machine with Maven Central access (directly or via Nexus).
# Then copy the entire project (including lib/ and jcef-bundle/) to the airgapped machine.
#
# Usage:
#   ./scripts/setup.sh                     # default: uses Maven Central
#   MAVEN_REPO_URL=https://nexus.internal/repository/maven-central ./scripts/setup.sh
#
# Windows users:
#   Git Bash: run this script as-is (requires Git for Windows + Maven on PATH)
#   PowerShell: use scripts/setup.ps1 instead 
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$PROJECT_DIR/com.example.jcef.browser/lib"
JCEF_VERSION="${JCEF_VERSION:-122.1.10}"
MAVEN_REPO_URL="${MAVEN_REPO_URL:-https://repo1.maven.org/maven2}"

# On Windows, Maven may be installed as mvn.cmd rather than mvn
MVN_CMD="mvn"
if ! command -v mvn &>/dev/null && command -v mvn.cmd &>/dev/null; then
    MVN_CMD="mvn.cmd"
fi

echo "=== JCEF OSGi Project Setup ==="
echo "JCEF Maven version: $JCEF_VERSION"
echo "Maven repo: $MAVEN_REPO_URL"
echo ""

# ── Step 1: Download JCEF JARs to lib/ ──────────────────────────────────────

echo "── Downloading JCEF JARs to lib/ ──"
mkdir -p "$LIB_DIR"

# Create a temporary POM to resolve jcefmaven and its transitive deps
TMP_WORK_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_WORK_DIR"' EXIT

cat > "$TMP_WORK_DIR/pom.xml" << POMEOF
<?xml version="1.0" encoding="UTF-8"?>
<project>
    <modelVersion>4.0.0</modelVersion>
    <groupId>temp</groupId>
    <artifactId>jcef-dep-resolver</artifactId>
    <version>1.0</version>
    <dependencies>
        <dependency>
            <groupId>me.friwi</groupId>
            <artifactId>jcefmaven</artifactId>
            <version>${JCEF_VERSION}</version>
        </dependency>
    </dependencies>
    <repositories>
        <repository>
            <id>central-override</id>
            <url>${MAVEN_REPO_URL}</url>
        </repository>
    </repositories>
</project>
POMEOF

# Download all transitive deps (me.friwi + org.jogamp) to a staging dir
STAGING="$TMP_WORK_DIR/staging"
"$MVN_CMD" -f "$TMP_WORK_DIR/pom.xml" dependency:copy-dependencies \
    -DoutputDirectory="$STAGING" \
    -DincludeGroupIds=me.friwi,org.jogamp.gluegen,org.jogamp.jogl,com.google.code.gson,org.apache.commons \
    -q

# Rename to clean, predictable names that match MANIFEST.MF Bundle-ClassPath
# Uses a function instead of associative arrays for Bash 3.2 (macOS) compatibility
clean_jar_name() {
    case "$1" in
        jcefmaven*)       echo "jcefmaven.jar" ;;
        jcef-api*)        echo "jcef-api.jar" ;;
        gluegen-rt*)      echo "gluegen-rt.jar" ;;
        jogl-all*)        echo "jogl-all.jar" ;;
        gson*)            echo "gson.jar" ;;
        commons-compress*) echo "commons-compress.jar" ;;
        *)                echo "" ;;
    esac
}

for jar in "$STAGING"/*.jar; do
    BASENAME=$(basename "$jar")
    CLEAN=$(clean_jar_name "$BASENAME")
    if [ -n "$CLEAN" ]; then
        cp "$jar" "$LIB_DIR/$CLEAN"
        echo "  $BASENAME -> $CLEAN"
    else
        echo "  WARNING: unexpected JAR $BASENAME (copying as-is)"
        cp "$jar" "$LIB_DIR/$BASENAME"
    fi
done
echo ""

# ── Step 2: Verify Bundle-ClassPath matches downloaded JARs ──────────────────

echo "── Verifying MANIFEST.MF Bundle-ClassPath ──"
MANIFEST="$PROJECT_DIR/com.example.jcef.browser/META-INF/MANIFEST.MF"
MISSING=0
for jar in "$LIB_DIR"/*.jar; do
    JAR_NAME=$(basename "$jar")
    if ! grep -q "$JAR_NAME" "$MANIFEST"; then
        echo "WARNING: lib/$JAR_NAME is NOT listed in Bundle-ClassPath in MANIFEST.MF"
        echo "  Add this line to Bundle-ClassPath:  lib/$JAR_NAME"
        MISSING=1
    fi
done
if [ "$MISSING" -eq 0 ]; then
    echo "All JARs are referenced in MANIFEST.MF. OK."
fi
echo ""

# ── Step 3: Pre-install JCEF natives (for airgapped deployment) ──────────────

echo "── JCEF Native Binaries ──"
echo "JCEF natives are downloaded automatically on first run by jcefmaven."
echo "For airgapped deployment:"
echo "  1. Run the application once on a connected machine."
echo "  2. Copy the 'jcef-bundle/' directory to the airgapped machine."
echo "  3. The app will detect 'install.lock' and skip downloading."
echo ""

# ── Step 4: List all Maven artifacts needed for Nexus ────────────────────────

echo "── Maven artifacts required in Nexus ──"
echo "Ensure these artifacts are cached/proxied in your Nexus instance:"
echo ""
"$MVN_CMD" -f "$TMP_WORK_DIR/pom.xml" dependency:list -q \
    -DoutputAbsoluteArtifactFilename=false \
    2>/dev/null | grep ":.*:.*:" | sed 's/^\[INFO\] */  /' || \
    echo "  (run 'mvn dependency:list' manually on the temp POM to see the full list)"
echo ""

echo "Additionally, for the Tycho/OSGi build, ensure these are available:"
echo "  org.eclipse.tycho:tycho-maven-plugin:4.0.4"
echo "  org.eclipse.tycho:target-platform-configuration:4.0.4"
echo "  (and their transitive dependencies)"
echo ""
echo "For the Eclipse p2 repository, mirror:"
echo "  https://download.eclipse.org/eclipse/updates/4.30/"
echo "  to a local path accessible from the build machine."
echo ""
echo "=== Setup complete ==="
