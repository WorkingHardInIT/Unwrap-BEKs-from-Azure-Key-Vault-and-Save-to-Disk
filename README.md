# 🛡️Azure Key Vault BEK Unwrapper

This PowerShell script retrieves 🔎 wrapped BitLocker Encryption Keys (BEKs) from an Azure Key Vault, unwraps 🔓 them using their associated Key Encryption Keys (KEKs), and saves 📀 the decrypted BEKs to a local directory. These can be used to unlock the encrypted disks of a Windows virtual machine for offline repair.

Author: Didier Van Hoye - WorkingHardInITDate: 2025-04-26

📚 Table of Contents

✨ Overview

🛠️ Prerequisites

🚀 Usage

📌 Important Notes

🧪 Example

📄 License

✨ Overview

The script follows a structured process:

Retrieve 📥 all wrapped BEKs (secrets) in the specified Azure Key Vault matching a GUID format and with ContentType of "Wrapped BEK".

Identify 🧬 the correct KEK (Azure Key Vault key) for each BEK based on the MachineName tag.

Prepare 🛠️ the Base64 string for decoding and handle any necessary padding.

Unwrap 🔓 the BEK using the KEK and the RSA-OAEP algorithm.

Save 📀 the unwrapped BEK as a .bek file to your specified output directory.

All steps include error handling ⚠️.
If an error occurs during BEK processing, the script logs the error 📋 and continues with the next BEK — no premature termination!
The console will remain open after execution for you to review the results 📜.

🛠️ Prerequisites

Azure PowerShell Modules 🛆:

Az.Accounts

Az.KeyVault

Permissions 🔐 for the executing user or service principal:

Secrets:

Get

List

Keys:

Get

Unwrap Key

List

Operating System 🖥️:

Windows, Linux, or macOS with PowerShell 5.1+ or 7+

Authentication ✅:

Ensure you're logged into Azure with Connect-AzAccount.

Confirm your identity has the necessary Key Vault access rights (Access Policies or Azure RBAC).

🚀 Usage

Set the required variables 📝 at the top of the script:

$keyVaultName = "<Your-KeyVault-Name>"
$UnwrappedBekPath = "C:\Temp" # Directory where decrypted BEKs will be saved

Run the script ▶️ in a PowerShell session:

.\Unwrap-AzKeyVaultBEKs.ps1

Review the console output 👀.
Unwrapped BEKs will be saved using filenames that include:

Volume letter

Volume label

Machine name

Secret GUID

Timestamp

Example:

C:\Temp\C-DATA-SRV01-Unwrapped-0e9a83c1-b7ea-45a4-9e97-3b8cfb60af8a-20250426110500.bek

📌 Important Notes

Key Vault Access 🔑:
Your identity must have permissions to secrets and keys — otherwise the script cannot retrieve or unwrap BEKs.

Error Handling ⚠️:
If an error occurs when processing a BEK, it will be logged 📋, and processing will continue with the next item.

Console Behavior 🖥️:
The script never closes the PowerShell session automatically — so you can review all output/errors after execution.

Output Files 📀:
Decrypted BEKs are saved with unique filenames to avoid overwriting previous results.

Security Considerations 🔒:
Secure your output folder! BEKs are sensitive data and must be protected appropriately.

🧪 Example

Example output:

Step 0: Initializing variables and retrieving wrapped BEKs...
Processing BEK: 0e9a83c1-b7ea-45a4-9e97-3b8cfb60af8a
Step 1.1: Retrieving wrapped BEK from Key Vault...
Step 1.2: Identifying correct KEK for unwrapping...
Matched KEK: C-DATA-SRV01-KEK
Step 2: Preparing Base64 string for decoding...
Step 3: Unwrapping BEK using KEK...
Step 4: Saving unwrapped BEK to file...
✅ Successfully unwrapped and saved BEK to: C:\Temp\C-DATA-SRV01-Unwrapped-0e9a83c1-b7ea-45a4-9e97-3b8cfb60af8a-20250426110500.bek

🎉 All BEKs processing completed.

📄 License

This project is licensed under the MIT License — see the LICENSE file for full details.
