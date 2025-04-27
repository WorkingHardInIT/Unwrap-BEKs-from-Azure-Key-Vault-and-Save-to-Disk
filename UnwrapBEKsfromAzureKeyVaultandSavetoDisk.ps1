# Script: Unwrap and/or Save BEKs from Azure Key Vault and save them to disk
# Author: Didier Van Hoye - WorkingHardInIT (Enhanced by ChatGPT)
# Date: 2025-04-26
# Purpose: Retrieve wrapped BEKs and plain BEKs from Key Vault, unwrap if needed, and save locally.

# Step 0: Set variables
$ErrorActionPreference = "Stop"  # Force all errors to throw exceptions
$keyVaultName = "<YOUR-KEY-VAULT>"  # Name of the Key Vault
$UnwrappedBekPath = "C:\Temp"       # Path where the decrypted BEKs will be saved

Write-Host "Step 0: Initializing variables and retrieving BEKs..." -ForegroundColor Cyan

try {
    # Step 0.1: Retrieve all BEKs matching GUID format and with 'Wrapped BEK' or 'BEK' ContentType
    $beks = Get-AzKeyVaultSecret -VaultName $keyVaultName | Where-Object {
        $_.Name -match "^[0-9A-Fa-f\-]{36}$" -and ($_.ContentType -eq "Wrapped BEK" -or $_.ContentType -eq "BEK")
    }

    if (-not $beks) {
        Write-Error "ERROR: No BEKs (wrapped or unwrapped) found in Key Vault '$keyVaultName'."
        return
    }
}
catch {
    Write-Error "ERROR: Failed to retrieve BEKs. Details: $_"
    return
}

# Step 1: Process each BEK individually
foreach ($bekSecret in $beks) {
    Write-Host ""
    Write-Host "Step 1: Processing BEK: $($bekSecret.Name)" -ForegroundColor Yellow

    try {
        Write-Host "Step 1.1: Retrieving BEK from Key Vault..."
        $bek = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $bekSecret.Name

        if (-not $bek) {
            Write-Error "ERROR: BEK '$($bekSecret.Name)' not found in Key Vault."
            continue
        }

        $ContentType = $bek.ContentType

        # Determine processing based on ContentType
        if ($ContentType -eq "Wrapped BEK") {
            Write-Host "INFO: Detected Wrapped BEK. Unwrapping required..." -ForegroundColor Cyan

            $Base64String = $bek.SecretValue | ConvertFrom-SecureString -AsPlainText

            # Step 1.2: Identify the correct KEK by matching the machine name
            Write-Host "Step 1.2: Identifying correct KEK for unwrapping..."
            $KEKNames = (Get-AzKeyVaultKey -VaultName $keyVaultName).Name
            $kekName = $null

            foreach ($RetrievedKekName in $KEKNames) {
                if ($RetrievedKekName -like "*$($bek.Tags.MachineName)*") {
                    $kekName = $RetrievedKekName
                    Write-Host "Step 1.2.1: Matched KEK: $kekName" -ForegroundColor Magenta
                    break
                }
            }

            if (-not $kekName) {
                Write-Error "ERROR: No matching KEK found for machine name '$($bek.Tags.MachineName)'."
                continue
            }

            # Step 1.3: Prepare the wrapped BEK bytes
            Write-Host "Step 1.3: Preparing Base64 string for decoding..."
            $Base64String = $Base64String -replace "-", "+" -replace "_", "/"

            # Step 1.4: Correct Base64 padding if necessary
            Write-Host "Step 1.4: Correcting Base64 padding if necessary..."
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
                Write-Error "ERROR: Failed to unwrap the BEK '$($bekSecret.Name)'."
                continue
            }

            $bekBytes = $unwrappedResult.RawResult
        }
        elseif ($ContentType -eq "BEK") {
            Write-Host "INFO: Detected Plain BEK. No unwrapping required..." -ForegroundColor Cyan
            $Base64String = $bek.SecretValue | ConvertFrom-SecureString -AsPlainText
            $bekBytes = [Convert]::FromBase64String($Base64String)
        }
        else {
            Write-Error "ERROR: Unknown ContentType '$ContentType' for BEK '$($bekSecret.Name)'. Skipping..."
            continue
        }

        # Step 1.6: Save the BEK to file
        Write-Host "Step 1.6: Saving BEK to file..."
        $driveLetter = $bek.Tags.VolumeLetter.TrimEnd(":\\")
        $timestamp = (Get-Date).ToString("yyyyMMddHHmmss")
        $uniqueBekFileName = "$driveLetter-$($bek.Tags.VolumeLabel)-$($bek.Tags.MachineName)-$($ContentType.Replace(' ',''))-$($bek.Name)-$timestamp.bek"
        $FullFilePath = Join-Path -Path $UnwrappedBekPath -ChildPath $uniqueBekFileName

        [System.IO.File]::WriteAllBytes($FullFilePath, $bekBytes)

        Write-Host "SUCCESS: Saved BEK to: $FullFilePath" -ForegroundColor Green
    }
    catch {
        Write-Error "ERROR: Processing BEK '$($bekSecret.Name)' failed. Details: $_"
        continue
    }
}

# Step 2: Completion
Write-Host ""
Write-Host "Step 2: All BEKs processed." -ForegroundColor Cyan
