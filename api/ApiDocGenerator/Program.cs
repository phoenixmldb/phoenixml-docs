// API Documentation Generator
// Transforms .NET XML documentation into Crucible's intermediate XML format
// using the PhoenixmlDb XSLT engine.
//
// Usage: ApiDocGenerator <stylesheet> <intermediate-dir> <xmldoc-dir> [--exclude-namespaces ns1,ns2]

using System.Diagnostics;
using PhoenixmlDb.Xslt;

if (args.Length < 3)
{
    Console.Error.WriteLine("Usage: ApiDocGenerator <stylesheet.xslt> <intermediate-dir> <xmldoc-dir> [--exclude-namespaces ns1,ns2,...]");
    return 1;
}

var stylesheetPath = Path.GetFullPath(args[0]);
var intermediateDir = Path.GetFullPath(args[1]);
var xmlDocDir = Path.GetFullPath(args[2]);

// Parse --exclude-namespaces flag
var excludeNamespaces = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
for (var i = 3; i < args.Length; i++)
{
    if (args[i] == "--exclude-namespaces" && i + 1 < args.Length)
    {
        foreach (var ns in args[i + 1].Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            excludeNamespaces.Add(ns);
        }

        i++;
    }
}

if (!File.Exists(stylesheetPath))
{
    Console.Error.WriteLine($"Stylesheet not found: {stylesheetPath}");
    return 1;
}

if (!Directory.Exists(xmlDocDir))
{
    Console.Error.WriteLine($"XML doc directory not found: {xmlDocDir}");
    return 1;
}

var stylesheet = await File.ReadAllTextAsync(stylesheetPath).ConfigureAwait(true);
var stylesheetUri = new Uri(stylesheetPath);

// Assemblies to process
var assemblies = new Dictionary<string, string>
{
    ["PhoenixmlDb.Core"] = "api/core",
    ["PhoenixmlDb.Xdm"] = "api/xdm",
    ["PhoenixmlDb.XQuery"] = "api/xquery",
    ["PhoenixmlDb.Xslt"] = "api/xslt",
};

var totalSw = Stopwatch.StartNew();

// Build exclude parameter string for the XSLT
var excludeParam = string.Join(",", excludeNamespaces);

// Process assemblies in parallel
var tasks = new List<Task<bool>>();
var skipped = new List<string>();
foreach (var (assemblyName, basePath) in assemblies)
{
    var xmlDocPath = Path.Combine(xmlDocDir, $"{assemblyName}.xml");
    if (!File.Exists(xmlDocPath))
    {
        Console.Error.WriteLine($"  SKIP {assemblyName} (no XML docs)");
        skipped.Add(assemblyName);
        continue;
    }

    tasks.Add(ProcessAssemblyAsync(assemblyName, basePath, xmlDocPath, stylesheet,
        stylesheetUri, intermediateDir, excludeParam));
}

var outcomes = await Task.WhenAll(tasks).ConfigureAwait(true);

totalSw.Stop();
Console.Error.WriteLine($"  Total API generation: {totalSw.ElapsedMilliseconds}ms");

// A failed assembly must reach the exit code. Previously every exception was caught,
// logged, and swallowed: the process returned 0, build.sh's `set -e` saw success, and the
// site deployed with that assembly's /api/ pages silently missing. The error scrolled past
// in a build log nobody reads when the build says it passed.
var failedCount = outcomes.Count(static ok => !ok);
if (failedCount > 0)
{
    Console.Error.WriteLine(
        $"ERROR: {failedCount} of {outcomes.Length} assemblies failed to generate API docs (see above).");
    return 1;
}

// Producing nothing at all is a failure too, not a fast success. This is what an empty or
// wrong XMLDOC_DIR looks like from here.
if (outcomes.Length == 0)
{
    Console.Error.WriteLine(
        $"ERROR: no API docs were generated — no XML documentation found in {xmlDocDir}.");
    if (skipped.Count > 0)
        Console.Error.WriteLine($"  skipped: {string.Join(", ", skipped)}");
    return 1;
}

return 0;

/// <summary>
/// Generates one assembly's API pages. Returns false if it failed, so the caller can make the
/// process exit non-zero — a logged-and-swallowed error is invisible to build.sh.
/// </summary>
static async Task<bool> ProcessAssemblyAsync(string assemblyName, string basePath,
    string xmlDocPath, string stylesheet, Uri stylesheetUri,
    string intermediateDir, string excludeNamespaces)
{
    var sw = Stopwatch.StartNew();
    var outputDir = Path.Combine(intermediateDir, basePath);
    Directory.CreateDirectory(outputDir);

    try
    {
        var transformer = new XsltTransformer();
        await transformer.LoadStylesheetAsync(stylesheet, stylesheetUri).ConfigureAwait(true);
        transformer.SetParameter("assembly-name", assemblyName);
        transformer.SetParameter("base-path", basePath);
        if (!string.IsNullOrEmpty(excludeNamespaces))
        {
            transformer.SetParameter("exclude-namespaces", excludeNamespaces);
        }

        var xmlDoc = await File.ReadAllTextAsync(xmlDocPath).ConfigureAwait(true);
        var indexXml = await transformer.TransformAsync(xmlDoc).ConfigureAwait(true);

        // Write primary output (index page)
        await File.WriteAllTextAsync(
            Path.Combine(outputDir, "index.xml"), indexXml).ConfigureAwait(true);

        // Write secondary result documents (one per type)
        foreach (var (href, content) in transformer.SecondaryResultDocuments)
        {
            var filePath = Path.Combine(outputDir, href);
            var dir = Path.GetDirectoryName(filePath);
            if (dir != null) Directory.CreateDirectory(dir);
            await File.WriteAllTextAsync(filePath, content).ConfigureAwait(true);
        }

        sw.Stop();
        var totalFiles = 1 + transformer.SecondaryResultDocuments.Count;
        Console.Error.WriteLine($"  {assemblyName}: {totalFiles} pages ({sw.ElapsedMilliseconds}ms)");
        return true;
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"  {assemblyName}: ERROR — {ex.Message}");
        return false;
    }
}
