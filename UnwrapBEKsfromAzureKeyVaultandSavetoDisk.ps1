# Script: Unwrap BEKs from Azure Key Vault and save them to disk
# Author: Didier Van Hoye - WorkingHardInIT
# Date: 2025-04-26
# Purpose: Retrieve wrapped BEKs from Key Vault, unwrap using KEK, and save decrypted BEK files locally.
# Written to recover Azure VMs either in Azure or on-premises, and be able to decrypt the BitLocker-encrypted disk.


# Step 0: Set variables
$ErrorActionPreference = "Stop"  # Force all errors to throw exceptions
$keyVaultName = "<YOUR-KEY-VAULT>"     # Name of the Key Vault
$UnwrappedBekPath = "C:\Temp"                 # Path where the decrypted BEKs will be saved

Write-Host "Step 0: Initializing variables and retrieving wrapped BEKs..." -ForegroundColor Cyan

try {
    # Step 0.1: Retrieve all wrapped BEKs matching GUID (that's is what is use for the names) format and 'Wrapped BEK' ContentType
    $wrappedBeks = Get-AzKeyVaultSecret -VaultName $keyVaultName | Where-Object {
        $_.Name -match "^[0-9A-Fa-f\-]{36}$" -and $_.ContentType -eq "Wrapped BEK"
    }

    if (-not $wrappedBeks) {
        Write-Error "ERROR: No wrapped BEKs found in Key Vault '$keyVaultName'."
        return  # Only stop script logic, do not close console
    }
}
catch {
    Write-Error "ERROR: Failed to retrieve wrapped BEKs. Details: $_"
    return
}

# Step 1: Process each wrapped BEK individually
foreach ($wrappedBekName in $wrappedBeks) {
    Write-Host ""
    Write-Host "Step 1: Processing BEK: $($wrappedBekName.Name)" -ForegroundColor Yellow

    try {
        # Step 1.1: Retrieve the wrapped BEK secret
        Write-Host "Step 1.1: Retrieving wrapped BEK from Key Vault..."
        $wrappedBek = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $wrappedBekName.Name

        if (-not $wrappedBek) {
            Write-Error "ERROR: Wrapped BEK '$($wrappedBekName.Name)' not found in Key Vault."
            continue
        }

        $Base64String = $wrappedBek.SecretValue | ConvertFrom-SecureString -AsPlainText

        # Step 1.2: Identify the correct KEK by matching the machine name
        Write-Host "Step 1.2: Identifying correct KEK for unwrapping..."
        $KEKNames = (Get-AzKeyVaultKey -VaultName $keyVaultName).Name
        $kekName = $null

        foreach ($RetrievedKekName in $KEKNames) {
            if ($RetrievedKekName -like "*$($wrappedBek.Tags.MachineName)*") {
                $kekName = $RetrievedKekName
                Write-Host "Step 1.2.1: Matched KEK: $kekName" -ForegroundColor Magenta
                break
            }
        }

        if (-not $kekName) {
            Write-Error "ERROR: No matching KEK found for machine name '$($wrappedBek.Tags.MachineName)'."
            continue
        }

        # Step 1.3: Prepare the wrapped BEK bytes
        Write-Host "Step 1.3: Preparing Base64 string for decoding..."
        # Explanation: Azure Key Vault may store the Base64 string in URL-safe format. 
        # Replace '-' with '+' and '_' with '/' to restore standard Base64 format.
        $Base64String = $Base64String -replace "-", "+" -replace "_", "/"

        # Step 1.4: Correct Base64 padding if necessary
        Write-Host "Step 1.4: Correcting Base64 padding if necessary..."
        # Explanation: Standard Base64 strings must have a length divisible by 4. Padding with '=' fixes this.
        switch ($Base64String.Length % 4) {
            2 { $Base64String += "==" }
            3 { $Base64String += "=" }
        }

        $WrappedBEKBytes = [Convert]::FromBase64String($Base64String)

        # Step 1.5: Unwrap the BEK using the KEK
        Write-Host "Step 1.5: Unwrapping BEK using KEK..."
        $unwrappedResult = Invoke-AzKeyVaultKeyOperation `
            -Operation Unwrap `
            -Algorithm RSA-OAEP `
            -VaultName $keyVaultName `
            -Name $kekName `
            -ByteArrayValue $WrappedBEKBytes

        if (-not ($unwrappedResult -and $unwrappedResult.RawResult)) {
            Write-Error "ERROR: Failed to unwrap the BEK '$($wrappedBekName.Name)'."
            continue
        }

        # Step 1.6: Save the decrypted BEK to file
        Write-Host "Step 1.6: Saving unwrapped BEK to file..."
        $driveLetter = $wrappedBek.Tags.VolumeLetter.TrimEnd(":\\")
        $timestamp = (Get-Date).ToString("yyyyMMddHHmmss")
        $uniqueBekFileName = "$driveLetter-$($wrappedBek.Tags.VolumeLabel)-$($wrappedBek.Tags.MachineName)-Unwrapped-$($wrappedBek.Name)-$timestamp.bek"
        $FullFilePath = Join-Path -Path $UnwrappedBekPath -ChildPath $uniqueBekFileName

        [System.IO.File]::WriteAllBytes($FullFilePath, $unwrappedResult.RawResult)

        Write-Host "SUCCESS: Unwrapped and saved BEK to: $FullFilePath" -ForegroundColor Green
    }
    catch {
        Write-Error "ERROR: Processing BEK '$($wrappedBekName.Name)' failed. Details: $_"
        continue
    }
}

# Step 2: Completion
Write-Host ""
Write-Host "Step 2: All BEKs processed." -ForegroundColor Cyan
