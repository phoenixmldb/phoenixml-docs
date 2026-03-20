// API Documentation Generator
// Transforms .NET XML documentation into Crucible's intermediate XML format
// using the PhoenixmlDb XSLT engine.

using PhoenixmlDb.Xslt;

if (args.Length < 3)
{
    Console.Error.WriteLine("Usage: ApiDocGenerator <stylesheet.xslt> <intermediate-dir> <xmldoc-dir>");
    return 1;
}

var stylesheetPath = Path.GetFullPath(args[0]);
var intermediateDir = Path.GetFullPath(args[1]);
var xmlDocDir = Path.GetFullPath(args[2]);

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

// Assemblies to process and their output subdirectories
var assemblies = new Dictionary<string, string>
{
    ["PhoenixmlDb.Core"] = "api/core",
    ["PhoenixmlDb.Xdm"] = "api/xdm",
    ["PhoenixmlDb.XQuery"] = "api/xquery",
    ["PhoenixmlDb.Xslt"] = "api/xslt",
};

foreach (var (assemblyName, basePath) in assemblies)
{
    var xmlDocPath = Path.Combine(xmlDocDir, $"{assemblyName}.xml");
    if (!File.Exists(xmlDocPath))
    {
        Console.Error.WriteLine($"  SKIP {assemblyName} (no XML docs)");
        continue;
    }

    var outputDir = Path.Combine(intermediateDir, basePath);
    Directory.CreateDirectory(outputDir);

    Console.Error.WriteLine($"  Processing {assemblyName} → {basePath}/");

    try
    {
        var transformer = new XsltTransformer();
        await transformer.LoadStylesheetAsync(stylesheet, stylesheetUri).ConfigureAwait(true);
        transformer.SetParameter("assembly-name", assemblyName);
        transformer.SetParameter("base-path", basePath);

        var xmlDoc = await File.ReadAllTextAsync(xmlDocPath).ConfigureAwait(true);
        var indexXml = await transformer.TransformAsync(xmlDoc).ConfigureAwait(true);

        // Write the primary output (index page)
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

        var totalFiles = 1 + transformer.SecondaryResultDocuments.Count;
        Console.Error.WriteLine($"    Generated {totalFiles} XML files");
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"    ERROR: {ex.Message}");
    }
}

return 0;
