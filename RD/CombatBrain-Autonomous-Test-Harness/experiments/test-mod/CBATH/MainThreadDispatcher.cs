using System;
using System.Collections.Concurrent;
using System.Threading.Tasks;

namespace CombatBrainAutonomousTestHarness
{
    // GABP tool handlers run on background TCP threads; Bannerlord API calls must run on
    // the game's main thread. Same pattern as Bannerlord.GABS.
    internal static class MainThreadDispatcher
    {
        private static readonly ConcurrentQueue<Action> Queue = new ConcurrentQueue<Action>();

        internal static Task<T> EnqueueAsync<T>(Func<T> func)
        {
            var tcs = new TaskCompletionSource<T>();
            Queue.Enqueue(() =>
            {
                try { tcs.SetResult(func()); }
                catch (Exception ex) { tcs.SetException(ex); }
            });
            return tcs.Task;
        }

        internal static void ProcessQueue()
        {
            Action a;
            while (Queue.TryDequeue(out a))
            {
                try { a.Invoke(); }
                catch (Exception) { }
            }
        }
    }
}
