#
# Downloads JCEF JARs into the bundle's lib/ directory and prepares
# JCEF native binaries for offline/airgapped use.
#
# Windows PowerShell equivalent of setup.sh.
# Run this script ONCE on a machine with Maven Central access.
# Then copy the entire project (including lib/ and jcef-bundle/) to the airgapped machine.
#
# Usage:
#   .\scripts\setup.ps1
#   $env:MAVEN_REPO_URL="https://nexus.internal/repository/maven-central"; .\scripts\setup.ps1
#
# Git Bash users: use scripts/setup.sh instead.
#
#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$LibDir     = Join-Path $ProjectDir "com.example.jcef.browser\lib"

$JcefVersion  = if ($env:JCEF_VERSION)   { $env:JCEF_VERSION }   else { "122.1.10" }
$MavenRepoUrl = if ($env:MAVEN_REPO_URL) { $env:MAVEN_REPO_URL } else { "https://repo1.maven.org/maven2" }

# Locate Maven executable (mvn.cmd on Windows, mvn on Unix-like)
$MvnCmd = @("mvn.cmd", "mvn") | Where-Object { Get-Command $_ -ErrorAction SilentlyContinue } | Select-Object -First 1
if (-not $MvnCmd) { throw "Maven not found on PATH. Install Maven and ensure 'mvn.cmd' or 'mvn' is on your PATH." }

Write-Host "=== JCEF OSGi Project Setup ==="
Write-Host "JCEF Maven version : $JcefVersion"
Write-Host "Maven repo         : $MavenRepoUrl"
Write-Host "Maven command      : $MvnCmd"
Write-Host ""

# ── Step 1: Download JCEF JARs to lib/ ──────────────────────────────────────

Write-Host "── Downloading JCEF JARs to lib/ ──"
New-Item -ItemType Directory -Force -Path $LibDir | Out-Null

$TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $TmpDir | Out-Null
$Staging = Join-Path $TmpDir "staging"

try {
    # Write a temporary POM to resolve jcefmaven and its transitive deps
    $PomPath = Join-Path $TmpDir "pom.xml"
    @"
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
            <version>$JcefVersion</version>
        </dependency>
    </dependencies>
    <repositories>
        <repository>
            <id>central-override</id>
            <url>$MavenRepoUrl</url>
        </repository>
    </repositories>
</project>
"@ | Set-Content -Path $PomPath -Encoding UTF8

    # Download transitive deps to staging dir
    & $MvnCmd -f $PomPath dependency:copy-dependencies `
        "-DoutputDirectory=$Staging" `
        "-DincludeGroupIds=me.friwi,org.jogamp.gluegen,org.jogamp.jogl,com.google.code.gson,org.apache.commons" `
        -q
    if ($LASTEXITCODE -ne 0) { throw "Maven dependency:copy-dependencies failed (exit $LASTEXITCODE)" }

    # Rename to clean, predictable names that match MANIFEST.MF Bundle-ClassPath
    $JarNames = [ordered]@{
        "jcefmaven"        = "jcefmaven.jar"
        "jcef-api"         = "jcef-api.jar"
        "gluegen-rt"       = "gluegen-rt.jar"
        "jogl-all"         = "jogl-all.jar"
        "gson"             = "gson.jar"
        "commons-compress" = "commons-compress.jar"
    }

    Get-ChildItem -Path $Staging -Filter "*.jar" | ForEach-Object {
        $BaseName = $_.Name
        $Matched  = $false
        foreach ($Prefix in $JarNames.Keys) {
            if ($BaseName.StartsWith($Prefix)) {
                $DestName = $JarNames[$Prefix]
                Copy-Item $_.FullName (Join-Path $LibDir $DestName) -Force
                Write-Host "  $BaseName -> $DestName"
                $Matched = $true
                break
            }
        }
        if (-not $Matched) {
            Write-Host "  WARNING: unexpected JAR $BaseName (copying as-is)"
            Copy-Item $_.FullName (Join-Path $LibDir $BaseName) -Force
        }
    }
    Write-Host ""

    # ── Step 2: Verify Bundle-ClassPath matches downloaded JARs ──────────────

    Write-Host "── Verifying MANIFEST.MF Bundle-ClassPath ──"
    $ManifestPath    = Join-Path $ProjectDir "com.example.jcef.browser\META-INF\MANIFEST.MF"
    $ManifestContent = Get-Content $ManifestPath -Raw
    $Missing = $false

    Get-ChildItem -Path $LibDir -Filter "*.jar" | ForEach-Object {
        $JarName = $_.Name
        if ($ManifestContent -notmatch [regex]::Escape($JarName)) {
            Write-Host "WARNING: lib/$JarName is NOT listed in Bundle-ClassPath in MANIFEST.MF"
            Write-Host "  Add this line to Bundle-ClassPath:  lib/$JarName"
            $Missing = $true
        }
    }
    if (-not $Missing) {
        Write-Host "All JARs are referenced in MANIFEST.MF. OK."
    }
    Write-Host ""

    # ── Step 3: Pre-install JCEF natives (for airgapped deployment) ──────────

    Write-Host "── JCEF Native Binaries ──"
    Write-Host "JCEF natives are downloaded automatically on first run by jcefmaven."
    Write-Host "For airgapped deployment:"
    Write-Host "  1. Run the application once on a connected machine."
    Write-Host "  2. Copy the 'jcef-bundle/' directory to the airgapped machine."
    Write-Host "  3. The app will detect 'install.lock' and skip downloading."
    Write-Host ""

    # ── Step 4: List all Maven artifacts needed for Nexus ────────────────────

    Write-Host "── Maven artifacts required in Nexus ──"
    Write-Host "Ensure these artifacts are cached/proxied in your Nexus instance:"
    Write-Host ""

    & $MvnCmd -f $PomPath dependency:list -q 2>$null |
        Where-Object { $_ -match ":.*:.*:" } |
        ForEach-Object { "  $_" }

    Write-Host ""
    Write-Host "Additionally, for the Tycho/OSGi build, ensure these are available:"
    Write-Host "  org.eclipse.tycho:tycho-maven-plugin:4.0.4"
    Write-Host "  org.eclipse.tycho:target-platform-configuration:4.0.4"
    Write-Host "  (and their transitive dependencies)"
    Write-Host ""
    Write-Host "For the Eclipse p2 repository, mirror:"
    Write-Host "  https://download.eclipse.org/eclipse/updates/4.30/"
    Write-Host "  to a local path accessible from the build machine."
    Write-Host ""

} finally {
    Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
}

Write-Host "=== Setup complete ==="
