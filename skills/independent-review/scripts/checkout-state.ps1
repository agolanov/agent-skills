# Windows PowerShell 5.1 entrypoint and trusted owner-local engine initializer.
# Dot-source only to import these fixed functions; arbitrary argv uses the JSON recipe.
function Initialize-CheckoutStateEngine {
    param([string]$OwnerScript, [string[]]$ProtectedRoots = @())
    if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
        throw 'Native observation unavailable under managed language restrictions.'
    }
    foreach ($scope in @('MachinePolicy', 'UserPolicy')) {
        $policy = Get-ExecutionPolicy -Scope $scope
        if ($policy -ne 'Undefined' -and $policy -ne 'Bypass' -and $policy -ne 'Unrestricted') {
            throw "Managed execution policy prevents this trusted-script path: $scope=$policy"
        }
    }
    # This managed-only precheck MUST precede Add-Type/CodeDom temporary writes.
    # The compiled native layer then repeats validation with pinned no-reparse handles.
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    $at = $temp
    while ($at) {
        $attributes = [IO.File]::GetAttributes($at)
        if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
            ($attributes -band [IO.FileAttributes]::Directory) -eq 0) {
            throw 'Compiler temp ancestry must contain ordinary directories only.'
        }
        $parent = [IO.Path]::GetDirectoryName($at)
        if ($parent -eq $at) { break }
        $at = $parent
    }
    $acl = [IO.Directory]::GetAccessControl($temp)
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().User
    if (-not $acl.GetOwner([Security.Principal.SecurityIdentifier]).Equals($user)) {
        throw 'Compiler temp owner mismatch; Add-Type was not started.'
    }
    $unsafe = [Security.AccessControl.FileSystemRights]::Write -bor
              [Security.AccessControl.FileSystemRights]::Delete -bor
              [Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
              [Security.AccessControl.FileSystemRights]::ChangePermissions -bor
              [Security.AccessControl.FileSystemRights]::TakeOwnership
    foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
        if ($rule.AccessControlType -ne 'Allow' -or ($rule.PropagationFlags -band 2) -ne 0) { continue }
        $sid = $rule.IdentityReference.Value
        if ($sid -eq $user.Value -or $sid -eq 'S-1-5-18' -or $sid -eq 'S-1-5-32-544') { continue }
        if (($rule.FileSystemRights -band $unsafe) -ne 0 -or
            ([int64]$rule.FileSystemRights -band 1342177280) -ne 0) {
            throw "Compiler temp ACL permits foreign mutation ($sid); Add-Type was not started."
        }
    }
    foreach ($root in $ProtectedRoots) {
        $full = [IO.Path]::GetFullPath($root).TrimEnd('\')
        if ($temp.Equals($full, [StringComparison]::OrdinalIgnoreCase) -or
            $temp.StartsWith($full + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Compiler temp must be outside protected checkout and administration.'
        }
    }
    if (-not ('CheckoutState.Engine' -as [type])) {
        $compileRoot = Join-Path $temp ('checkout-state-compiler-' + [Guid]::NewGuid().ToString('N'))
        $security = New-Object Security.AccessControl.DirectorySecurity
        $security.SetOwner($user)
        $security.SetAccessRuleProtection($true, $false)
        $security.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($user, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')))
        if ([IO.Directory]::Exists($compileRoot)) { throw 'Compiler directory is already present.' }
        [IO.Directory]::CreateDirectory($compileRoot, $security) | Out-Null
        try {
            $parameters = New-Object CodeDom.Compiler.CompilerParameters
            $parameters.GenerateInMemory = $true
            $parameters.TempFiles = New-Object CodeDom.Compiler.TempFileCollection($compileRoot, $false)
            foreach ($assembly in @('System.dll', 'System.Core.dll', 'System.Numerics.dll')) {
                $parameters.ReferencedAssemblies.Add($assembly) | Out-Null
            }
            $source = Join-Path ([IO.Path]::GetDirectoryName($OwnerScript)) 'checkout-state.windows.cs'
            Add-Type -TypeDefinition ([IO.File]::ReadAllText($source)) -CompilerParameters $parameters
        } finally {
            if ([IO.Directory]::Exists($compileRoot)) { [IO.Directory]::Delete($compileRoot, $true) }
        }
    }
    [CheckoutState.Engine]::ValidateRuntimeRoot($temp, $ProtectedRoots)
}
if ($MyInvocation.InvocationName -eq '.') { return }
$ErrorActionPreference = 'Stop'
try {
    Initialize-CheckoutStateEngine $PSCommandPath
    [CheckoutState.Engine]::OwnerScript = $PSCommandPath
    exit [CheckoutState.Engine]::Dispatch([string[]]$args)
} catch {
    [Console]::Error.WriteLine('state verification unavailable: ' + $_.Exception.Message)
    exit 2
}
