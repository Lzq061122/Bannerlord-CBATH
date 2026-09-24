using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;

class Program
{
    static int Main(string[] argv)
    {
        if (argv.Length < 2)
        {
            Console.Error.WriteLine("usage: dump-api <assemblyPath> <outFile> [nameFilter]");
            return 2;
        }

        var asmPath = argv[0];
        var outFile = argv[1];
        var filter = argv.Length > 2 ? argv[2] : "";

        var refDirs = new List<string>();
        var nugetRoot = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            ".nuget", "packages");
        if (Directory.Exists(nugetRoot))
        {
            foreach (var dll in Directory.EnumerateFiles(nugetRoot, "*.dll", SearchOption.AllDirectories))
            {
                var dir = Path.GetDirectoryName(dll);
                if (dir != null && dir.Contains("net472") && !refDirs.Contains(dir)) refDirs.Add(dir);
            }
        }

        var resolverPaths = new List<string> { asmPath };
        resolverPaths.AddRange(refDirs.SelectMany(d => Directory.EnumerateFiles(d, "*.dll")));

        var resolver = new PathAssemblyResolver(resolverPaths.Distinct());
        using var mlc = new MetadataLoadContext(resolver);
        var asm = mlc.LoadFromAssemblyPath(asmPath);

        var lines = new List<string>();
        Type[] types;
        try { types = asm.GetTypes(); }
        catch (ReflectionTypeLoadException ex) { types = ex.Types.Where(t => t != null).ToArray()!; }

        foreach (var t in types)
        {
            if (filter.Length > 0 && !t.FullName!.Contains(filter, StringComparison.OrdinalIgnoreCase)) continue;
            MethodInfo[] ms;
            try { ms = t.GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static | BindingFlags.Instance | BindingFlags.DeclaredOnly); }
            catch { continue; }

            var interesting = ms.Where(m => m.Name.Contains("Open", StringComparison.OrdinalIgnoreCase)
                                         || m.Name.Contains("Start", StringComparison.OrdinalIgnoreCase)
                                         || m.Name.Contains("Mission", StringComparison.OrdinalIgnoreCase)).ToArray();

            var allMode = Environment.GetEnvironmentVariable("DUMP_ALL") == "1";

            if (allMode)
            {
                lines.Add("=== " + t.FullName);
                foreach (var c in t.GetConstructors())
                {
                    lines.Add("    ctor(" + string.Join(", ", c.GetParameters().Select(p => p.ParameterType.Name + " " + p.Name)) + ")");
                }
                foreach (var p in t.GetProperties(BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static | BindingFlags.DeclaredOnly))
                {
                    lines.Add("    prop " + p.PropertyType.Name + " " + p.Name);
                }
                foreach (var f in t.GetFields(BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static | BindingFlags.DeclaredOnly))
                {
                    lines.Add("    field " + f.FieldType.Name + " " + f.Name);
                }
                if (Environment.GetEnvironmentVariable("DUMP_METHODS") == "1")
                {
                    foreach (var m in t.GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static | BindingFlags.Instance | BindingFlags.DeclaredOnly))
                    {
                        if (m.IsSpecialName) continue;
                        lines.Add("    method " + (m.IsPublic ? "public " : "nonpublic ") + (m.IsStatic ? "static " : "") +
                                  m.ReturnType.Name + " " + m.Name + "(" + string.Join(", ", m.GetParameters().Select(p => p.ParameterType.Name + " " + p.Name)) + ")");
                    }
                }
            }
            else if (interesting.Length == 0) continue;

            if (!allMode)
            {
                lines.Add("=== " + t.FullName);
                foreach (var m in interesting)
                {
                    var ps = m.GetParameters().Select(p => p.ParameterType.Name + " " + p.Name);
                    lines.Add("    " + (m.IsPublic ? "public " : "private ") + (m.IsStatic ? "static " : "") +
                              m.ReturnType.Name + " " + m.Name + "(" + string.Join(", ", ps) + ")");
                }
            }
        }

        File.WriteAllLines(outFile, lines);
        Console.WriteLine("wrote " + lines.Count + " lines -> " + outFile);
        return 0;
    }
}
