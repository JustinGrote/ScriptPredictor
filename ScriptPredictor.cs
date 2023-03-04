using System.Diagnostics;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Management.Automation.Subsystem.Prediction;
using System.Text;

namespace ScriptPredictor;
public class ScriptPredictor : ICommandPredictor
{
	public Guid Id { get; init; }
	public string Name { get; init; }
	public string Description { get; init; }

	public ScriptBlock ScriptBlock { get; init; }

	private RunspacePool RunspacePool { get; init; }

	public ScriptPredictor(ScriptBlock scriptBlock, string name, string description, Guid? id)
	{
		ScriptBlock = scriptBlock;
		Id = id ?? Guid.NewGuid();
		Name = name;
		Description = description;
		RunspacePool = RunspaceFactory.CreateRunspacePool(InitialSessionState.CreateDefault2());
		RunspacePool.SetMaxRunspaces(10);
		RunspacePool.Open();

		// Warm up a runspace
		using var ps = PowerShell.Create(InitialSessionState.CreateDefault2());
		ps.RunspacePool = RunspacePool;
		ps.AddScript("").Invoke();
		ps.Dispose();
	}

	public SuggestionPackage GetSuggestion(PredictionClient client, PredictionContext context, CancellationToken cancellationToken)
	{
		var timer = Stopwatch.StartNew();
		using var ps = PowerShell.Create(InitialSessionState.CreateDefault2());
		ps.RunspacePool = RunspacePool;
		StringBuilder script = new(ScriptBlock.ToString());

		// Assign $PSItem to $args[0] for ease of use
		script.Insert(0, "$PSItem = $args[0]\n");

		// The prediction engine silently swallows errors so we add this to the script to surface them.
		script.Insert(0, "$ErrorActionPreference='stop'\ntrap {[Console]::WriteLine(\"`nScriptPredictor Error: $($PSItem.FullyQualifiedErrorID): $PSItem\"); return}\n");

		// This allows the [PredictionContext] and [PredictiveSuggestion] types to be used in shorthand. These can't be supplied in the scriptblock itself due to PowerShell limitations on the using namespace keyword where it has to be the first line of a script.
		script.Insert(0, "using namespace System.Management.Automation.Subsystem.Prediction\n");

		ps.AddScript(script.ToString());
		ps.AddArgument(context.InputAst.Extent.Text);
		ps.AddArgument(context);

		PSObject[] result = Array.Empty<PSObject>();
		try
		{
			result = ps.Invoke().ToArray();
		}
		catch (Exception e)
		{
			// The predictor engine silently swallows predictor errors, this way we can surface them to help with troubleshooting
			Console.WriteLine("\nUntrapped ScriptPredictor Error - " + e.GetType().Name + ": " + e.Message);
			throw;
		}

		List<PredictiveSuggestion> suggestions = new();

		// TODO: More strict handling maybe?
		foreach (var psobject in result)
		{
			PredictiveSuggestion suggestion = psobject.BaseObject switch
			{
				PredictiveSuggestion pSuggestion => pSuggestion,
				string suggestString => new PredictiveSuggestion(suggestString),
				_ => throw new InvalidDataException($"ScriptPredictor: Your script should only output strings or [PredictiveSuggestion] objects. Detected invalid object type: {psobject.GetType().FullName}")
			};

			suggestions.Add(suggestion);
		}

		var elapsed = timer.ElapsedMilliseconds;
		if (elapsed > 15)
		{
			Console.WriteLine($"\nWARNING: Completion took {timer.ElapsedMilliseconds}ms which may be longer than the default timeout. You probably won't see your prediction results, it will silently drop it.");
		}

		return new SuggestionPackage(suggestions);
	}

	// These are currently not used and only here for interface completeness
	public bool CanAcceptFeedback(PredictionClient client, PredictorFeedbackKind feedback) => false;
	public void OnCommandLineAccepted(PredictionClient client, IReadOnlyList<string> history) { }
	public void OnCommandLineExecuted(PredictionClient client, string commandLine, bool success) { }
	public void OnSuggestionAccepted(PredictionClient client, uint session, string acceptedSuggestion) { }
	public void OnSuggestionDisplayed(PredictionClient client, uint session, int countOrIndex) { }
}
