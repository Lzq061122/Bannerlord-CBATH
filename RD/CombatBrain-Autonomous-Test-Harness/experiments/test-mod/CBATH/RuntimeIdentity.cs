using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using TaleWorlds.Library;
using TaleWorlds.ModuleManager;

namespace CombatBrainAutonomousTestHarness
{
    internal static class RuntimeIdentity
    {
        private const string Marker = "CBATH_RUNTIME_IDENTITY";
        private static volatile bool _emitted;
        private static string _lastLine = string.Empty;

        internal static string LastLine => _lastLine;

        internal static string GameVersion()
        {
            return Safe(() => ApplicationVersion.FromParametersFile().ToString(), "<unknown>");
        }

        internal static Dictionary<string, object> AsObject()
        {
            var asm = Assembly.GetExecutingAssembly();
            var loc = Safe(() => asm.Location, "<unknown>");

            return new Dictionary<string, object>
            {
                { "marker", Marker },
                { "module", BuildIdentity.ModuleId },
                { "build_id", BuildIdentity.BuildId },
                { "build_timestamp", BuildIdentity.BuildTimestamp },
                { "assembly_version", BuildIdentity.AssemblyVersion },
                { "mvid", Safe(() => asm.ManifestModule.ModuleVersionId.ToString(), "<unknown>") },
                { "assembly_location", loc },
                { "assembly_sha256", Safe(() => Sha256OfFile(loc), "<unknown>") },
                { "game_version", GameVersion() },
                { "pid", Process.GetCurrentProcess().Id },
                { "active_modules", string.Join(",", ActiveModuleIds()) }
            };
        }

        internal static string Build()
        {
            var asm = Assembly.GetExecutingAssembly();
            var loc = Safe(() => asm.Location, "<unknown>");
            var appVersion = GameVersion();

            var parts = new[]
            {
                Marker,
                "module=" + BuildIdentity.ModuleId,
                "build_id=" + BuildIdentity.BuildId,
                "build_timestamp=" + BuildIdentity.BuildTimestamp,
                "assembly_version=" + BuildIdentity.AssemblyVersion,
                "mvid=" + Safe(() => asm.ManifestModule.ModuleVersionId.ToString(), "<unknown>"),
                "assembly_location=" + loc,
                "assembly_sha256=" + Safe(() => Sha256OfFile(loc), "<unknown>"),
                "game_version=" + appVersion,
                "pid=" + Process.GetCurrentProcess().Id,
                "active_modules=" + string.Join(",", ActiveModuleIds())
            };

            _lastLine = string.Join("\n", parts);
            return _lastLine;
        }

        internal static void Emit()
        {
            if (_emitted) return;
            _emitted = true;

            var line = Build();

            try { TaleWorlds.Library.Debug.Print(line); } catch { }
            try { Console.WriteLine(line); } catch { }
            try { File.AppendAllText(IdentityFilePath, line + "\n\n", Encoding.UTF8); } catch { }
            try { InformationManager.DisplayMessage(new InformationMessage(line.Substring(0, Math.Min(line.Length, 400)))); } catch { }
        }

        private static List<string> ActiveModuleIds()
        {
            var names = new List<string>();
            foreach (var mi in ModuleHelper.GetActiveModules()) names.Add(mi.Id);
            return names;
        }

        private static string IdentityFilePath
        {
            get
            {
                var dir = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
                    "CommandBrainATH");
                Directory.CreateDirectory(dir);
                return Path.Combine(dir, "cbath-runtime-identity-" + Process.GetCurrentProcess().Id + ".txt");
            }
        }

        private static string Sha256OfFile(string path)
        {
            if (string.IsNullOrEmpty(path) || !File.Exists(path)) return "<missing>";
            using (var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
            {
                var bytes = SHA256.Create().ComputeHash(fs);
                var sb = new StringBuilder();
                foreach (var b in bytes) sb.Append(b.ToString("x2"));
                return sb.ToString();
            }
        }

        private static string Safe(Func<string> f, string fallback)
        {
            try { return f() ?? fallback; }
            catch (Exception e) { return fallback + ":" + e.GetType().Name; }
        }
    }
}
