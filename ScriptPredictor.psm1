using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Subsystem
using namespace System.Management.Automation.Subsystem.Prediction
using namespace System.Threading
using namespace ScriptPredictor

Add-Type -Path $(Join-Path $PSScriptRoot '*.dll')

# This "works" but because the scriptblocks get marshaled to the default runspace, it ends up being blocking and bad performance.
# class ScriptPredictor : ICommandPredictor {
# 	[ScriptBlock]$ScriptBlock;
# 	[string]$Name;
# 	[string]$Description;
# 	[guid]$Id;

# 	ScriptPredictor([ScriptBlock]$ScriptBlock, [string]$Name, [string]$Description, [guid]$Id) {
# 		$this.ScriptBlock = $ScriptBlock;
# 		$this.Name = $Name;
# 		$this.Description = $Description;
# 		$this.Id = $Id ?? [Guid]::NewGuid();
# 	}

# 	[SuggestionPackage] GetSuggestion(
# 		[PredictionClient]$client,
# 		[PredictionContext]$context,
# 		[CancellationToken]$cancellationToken
# 	) {
# 		[Console]::WriteLine('test')
# 		[Console]::WriteLine('test2')

# 		$suggestions = $this.ScriptBlock.Invoke($Context);
# 		$formattedSuggestions = foreach ($suggestion in $suggestions) {
# 			if ($suggestion -is [PredictiveSuggestion]) {
# 				$suggestion
# 			} elseif ($suggestion -is [string]) {
# 				[PredictiveSuggestion]$suggestion
# 			} else {
# 				throw "ScriptPredictor $($this.Name) [$($this.Id)]: ScriptBlock returned objects that arent a string or a [PredictiveSuggestion] object. Unexpected Object Type: $($suggestion.GetType())"
# 			}
# 		}

# 		return [SuggestionPackage]::new($formattedSuggestions)
# 	}

# 	# TODO: Provide hooks for this feedback behavior
# 	[bool] CanAcceptFeedback([PredictionClient]$client, [PredictorFeedbackKind]$feedback) { return $false }
# 	[void] OnCommandLineAccepted([PredictionClient]$client, [IReadOnlyList[string]]$history) {}
# 	[void] OnCommandLineExecuted([PredictionClient]$client, [string]$commandLine, [bool]$success) {}
# 	[void] OnSuggestionAccepted([PredictionClient]$client, [uint]$session, [string]$acceptedSuggestion) {}
# 	[void] OnSuggestionDisplayed([PredictionClient]$client, [uint]$session, [int]$countOrIndex) {}
# }


function Register-ScriptPredictor {
	<#
	.SYNOPSIS
	Registers a scriptblock as a PowerShell Predictor. This works very similarly to an ArgumentCompleter.

	Your scriptblock should take a [PredictionContext] as a parameter, and must return zero or more [PredictiveSuggestion] objects

	.EXAMPLE
	Register-ScriptPredictor {
		try{
			$args[0].InputScript.Text + (Get-Random)
		} catch {

		}
	}
	A simple registration that adds a random number to your current input


	#>
	param(
		#The scriptblock for the predictor. It runs in its own runspace and can't use any external state except .NET static objects/methods. You can use either $args[0] to access the [ParameterContext] object, or use param([ParameterContext]$context). If you use the latter, you will get Intellisense in VSCode for the object.
		[Parameter(ValueFromPipeline)][ScriptBlock]$ScriptBlock,

		#The name of your predictor as will be seen in the subsystem registration. This defaults to 'ScriptPredictor'
		[ValidateNotNullOrEmpty()]
		[string]$Name = 'ScriptPredictor',

		#A description of your predictor. This defaults to the same as the Name.
		[ValidateNotNullOrEmpty()]
		[string]$Description = $Name,

		#Optionally specify a custom GUID for your predictor. A random one will be generated instead if you do not.
		[ValidateNotNullOrEmpty()]
		[guid]$Id = $(New-Guid)
	)

	$ErrorActionPreference = 'Stop'
	[ScriptPredictor]$predictor = [ScriptPredictor]::new(
		$ScriptBlock,
		$Name,
		$Description,
		$Id
	)

	#TODO: Add a quick script verification to sanity check it has the right parameters and maybe run a test for output
	[SubsystemManager]::RegisterSubsystem([SubsystemKind]::CommandPredictor, $predictor)

}