# Azure Key Vault BEK Unwrapper

This PowerShell script retrieves **wrapped BitLocker Encryption Keys (BEKs)** from an **Azure Key Vault**, **unwraps** them using their associated **Key Encryption Keys (KEKs)**, and **saves** the decrypted BEKs to a local directory.

> **Author:** Didier Van Hoye - [WorkingHardInIT](https://workinghardinit.work)  
> **Date:** 2023-10-03

---

## Overview

The script follows a structured process:

1. **Retrieve** all wrapped BEKs (secrets) in the specified Azure Key Vault that match a GUID format and have the `ContentType` of "Wrapped BEK".
2. **Identify** the correct KEK (Azure Key Vault key) associated with each BEK, based on the `MachineName` tag.
3. **Prepare** the Base64 string for decoding and handle padding if necessary.
4. **Unwrap** the BEK using the KEK with the `RSA-OAEP` algorithm.
5. **Save** the unwrapped BEK as a `.bek` file to the specified local directory.

All steps include error handling. If an error occurs while processing a BEK, the script will log the error and continue processing the next BEK without terminating.  
The console will **remain open** after execution (no forced exit), allowing you to review the output.

---

## Prerequisites

- **Azure PowerShell Modules**:
  - `Az.Accounts`
  - `Az.KeyVault`
- **Permissions** required for the executing user or service principal:
  - **Secrets**:
    - `Get`
    - `List`
  - **Keys**:
    - `Get`
    - `Unwrap Key`
    - `List`
- **Operating System**:
  - Windows, Linux, or macOS with PowerShell 5.1 or PowerShell 7+
- **Authentication**:
  - Ensure you are authenticated to the correct Azure subscription using `Connect-AzAccount`.
  - The executing identity must have the necessary Azure Key Vault access rights (either via Key Vault Access Policies or Azure RBAC).

---

## Usage

1. **Set the required variables** at the top of the script:
    ```powershell
    $keyVaultName = "<Your-KeyVault-Name>"
    $UnwrappedBekPath = "C:\Temp" # Directory where decrypted BEKs will be saved
    ```

2. **Run the script** in a PowerShell session:
    ```powershell
    .\Unwrap-AzKeyVaultBEKs.ps1
    ```

3. **Review the console output**.  
   Unwrapped BEKs will be saved with filenames based on:
   - Volume letter
   - Volume label
   - Machine name
   - Secret GUID
   - Timestamp

   Example filename:
   ```
   C:\Temp\C-DATA-SRV01-Unwrapped-0e9a83c1-b7ea-45a4-9e97-3b8cfb60af8a-20250426110500.bek
   ```

---

## Important Notes

- **Key Vault Access**:  
  Make sure your identity has permissions to both secrets and keys. Otherwise, the script will fail to retrieve or unwrap the BEKs.

- **Error Handling**:  
  If an error occurs when processing a specific BEK, the script logs the error and moves on to the next BEK without terminating.

- **Console Behavior**:  
  The script never forcefully closes or exits the PowerShell console. This allows for review of all output and error messages after execution.

- **Output**:  
  Decrypted BEKs are written to the specified output directory with unique filenames to prevent overwriting.

- **Security Consideration**:  
  Always secure the output folder where the unwrapped BEKs are stored. These files are sensitive.

---

## Example

Example execution:
```powershell
Step 0: Initializing variables and retrieving wrapped BEKs...
Processing BEK: 0e9a83c1-b7ea-45a4-9e97-3b8cfb60af8a
Step 1.1: Retrieving wrapped BEK from Key Vault...
Step 1.2: Identifying correct KEK for unwrapping...
Matched KEK: C-DATA-SRV01-KEK
Step 2: Preparing Base64 string for decoding...
Step 3: Unwrapping BEK using KEK...
Step 4: Saving unwrapped BEK to file...
Successfully unwrapped and saved BEK to: C:\Temp\C-DATA-SRV01-Unwrapped-0e9a83c1-b7ea-45a4-9e97-3b8cfb60af8a-20250426110500.bek

All BEKs processing completed.
```

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.
