# ScriptPredictor

This is an implementation of the PowerShell prediction subsystem that allows you to specify any scriptblock as a prediction plugin, similar to how Argument Completers work. Unfortunately it's not very useful at the moment due to a 20ms runtime restriction on prediction subsystems - https://github.com/PowerShell/PSReadLine/issues/3607

## Quick Start

```powershell
Install-Module ScriptPredictor
Import-Module ScriptPredictor
Set-PSReadlineOption -PredictionSource Plugin
Register-ScriptPredictor -Name 'RandomNumberAppend' {
	$PSItem + (Get-Random)
}
#Anything you type at the prompt should now predict a random number after it. This may take a few tries for the runspace to "warm up" and operate under the 20ms limit.
```

