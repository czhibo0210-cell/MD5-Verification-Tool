# ==============================================
# MD5 Bulk Verification Script for Metagenomics Data
# Platform: Windows PowerShell
# Usage: Run in the parent folder containing all sequencing data subfolders
# ==============================================

# INSTRUCTIONS:
# 1. Navigate to your main data folder in File Explorer
# 2. Hold Shift + Right-click → Select "Open PowerShell window here"
# 3. Copy and paste this entire script
# 4. Press Enter to execute

# MD5 Bulk Verification Script - Final Stable Version
$logDate = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$logFile = "Metagenomics_MD5_Verification_$logDate.txt"
$jsonReport = "MD5_Verification_Report_$logDate.json"

# Initialize statistics
$globalStats = @{
    StartTime = Get-Date
    TotalFolders = 0
    TotalFiles = 0
    PassedFiles = 0
    FailedFiles = 0
    MissingFiles = 0
    TotalSizeGB = 0
    Folders = @()
}

# Create detailed log header
$logHeader = @"
==============================================
Metagenomics MD5 Bulk Verification Report
==============================================
Execution Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Working Directory: $(Get-Location)
Computer Name: $env:COMPUTERNAME
Username: $env:USERNAME
PowerShell Version: $($PSVersionTable.PSVersion)
Operating System: $([System.Environment]::OSVersion.VersionString)

"@

Write-Host $logHeader -ForegroundColor Cyan
$logHeader | Out-File -FilePath $logFile -Encoding UTF8

# Search for all MD5 files
Write-Host "Searching for MD5 files..." -ForegroundColor Yellow
$md5Files = Get-ChildItem -Recurse -Filter "*_MD5.txt"

if ($md5Files.Count -eq 0) {
    $errorMsg = "ERROR: No MD5 files found! Please check that MD5 files exist with '*_MD5.txt' pattern."
    Write-Host $errorMsg -ForegroundColor Red
    $errorMsg | Out-File -FilePath $logFile -Append -Encoding UTF8
    exit 1
}

Write-Host "Found $($md5Files.Count) MD5 files" -ForegroundColor Green
"Found $($md5Files.Count) MD5 files`n" | Out-File -FilePath $logFile -Append -Encoding UTF8

$globalStats.TotalFolders = $md5Files.Count
$folderIndex = 0

# Process each MD5 file
foreach ($md5File in $md5Files) {
    $folderIndex++
    $folderStats = @{
        FolderName = $md5File.Directory.Name
        FolderPath = $md5File.DirectoryName
        FileCount = 0
        PassedFiles = 0
        FailedFiles = 0
        MissingFiles = 0
        AllPassed = $true
        StartTime = Get-Date
        Files = @()
    }

    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "Processing [$folderIndex/$($md5Files.Count)]: $($md5File.Directory.Name)" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan

    "==============================================`nProcessing [$folderIndex/$($md5Files.Count)]: $($md5File.Directory.Name)`n==============================================" | Out-File -FilePath $logFile -Append -Encoding UTF8

    $expectedHashes = Get-Content $md5File.FullName
    $fileIndex = 0

    # Check each file listed in the MD5 file
    foreach ($line in $expectedHashes) {
        if ($line.Trim()) {
            $parts = $line.Trim() -split '\s+', 2
            if ($parts.Length -eq 2) {
                $fileIndex++
                $expectedHash = $parts[0].ToLower()
                $fileName = $parts[1].Trim()

                # Clean file path prefixes
                if ($fileName.StartsWith("./")) { $fileName = $fileName.Substring(2) }
                if ($fileName.StartsWith(".\")) { $fileName = $fileName.Substring(2) }

                $filePath = Join-Path $md5File.DirectoryName $fileName

                # Initialize file information
                $fileInfo = @{
                    FileName = $fileName
                    ExpectedHash = $expectedHash
                    Status = "Unknown"
                    FileSizeMB = 0
                    ActualHash = ""
                    CheckTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                }

                Write-Host "File [$fileIndex]: $fileName" -NoNewline -ForegroundColor Gray

                if (Test-Path $filePath) {
                    try {
                        # Get file size
                        $fileItem = Get-Item $filePath
                        $sizeMB = [math]::Round($fileItem.Length / 1MB, 2)
                        $fileInfo.FileSizeMB = $sizeMB
                        $globalStats.TotalSizeGB += $sizeMB / 1024
                        $globalStats.TotalFiles++
                        $folderStats.FileCount++

                        # Calculate and compare MD5 hash
                        Write-Host " - Calculating MD5..." -NoNewline -ForegroundColor Gray
                        $actualHash = (Get-FileHash -Path $filePath -Algorithm MD5).Hash.ToLower()
                        $fileInfo.ActualHash = $actualHash

                        if ($actualHash -eq $expectedHash) {
                            $successMsg = "PASS $fileName : OK (Size: $sizeMB MB)"
                            Write-Host " PASS" -ForegroundColor Green
                            $fileInfo.Status = "Passed"
                            $globalStats.PassedFiles++
                            $folderStats.PassedFiles++
                        } else {
                            $errorMsg = "FAIL $fileName : VERIFICATION FAILED (Size: $sizeMB MB)"
                            Write-Host " FAIL" -ForegroundColor Red
                            $fileInfo.Status = "Failed"
                            $folderStats.AllPassed = $false
                            $globalStats.FailedFiles++
                            $folderStats.FailedFiles++
                        }
                    } catch {
                        $errorMsg = "ERROR $fileName : File read error - $($_.Exception.Message)"
                        Write-Host " ERROR" -ForegroundColor Red
                        $fileInfo.Status = "Error"
                        $folderStats.AllPassed = $false
                        $globalStats.FailedFiles++
                        $folderStats.FailedFiles++
                    }
                } else {
                    $errorMsg = "MISSING $fileName : File not found"
                    Write-Host " MISSING" -ForegroundColor Red
                    $fileInfo.Status = "Missing"
                    $folderStats.AllPassed = $false
                    $globalStats.MissingFiles++
                    $folderStats.MissingFiles++
                }

                # Write result to log file
                $logEntry = if ($fileInfo.Status -eq "Passed") {
                    "PASS $fileName : OK (Size: $($fileInfo.FileSizeMB) MB)"
                } elseif ($fileInfo.Status -eq "Failed") {
                    "FAIL $fileName : VERIFICATION FAILED (Size: $($fileInfo.FileSizeMB) MB)`n   Expected: $expectedHash`n   Actual: $($fileInfo.ActualHash)"
                } else {
                    "$($fileInfo.Status.ToUpper()) $fileName : $($fileInfo.Status)"
                }
                $logEntry | Out-File -FilePath $logFile -Append -Encoding UTF8

                $folderStats.Files += $fileInfo
            }
        }
    }

    $folderStats.EndTime = Get-Date
    $folderStats.Duration = [math]::Round(($folderStats.EndTime - $folderStats.StartTime).TotalSeconds, 2)
    $globalStats.Folders += $folderStats

    # Output folder summary (修复的部分)
    $folderSummary = if ($folderStats.AllPassed) {
        "SUCCESS: All files verified successfully! Files: $($folderStats.FileCount)/$($folderStats.FileCount) passed (Time: $($folderStats.Duration)s)"
    } else {
        "FAILURE: Verification issues found! Passed: $($folderStats.PassedFiles), Failed: $($folderStats.FailedFiles), Missing: $($folderStats.MissingFiles) (Time: $($folderStats.Duration)s)"
    }

    # 修复三元运算符问题
    if ($folderStats.AllPassed) {
        Write-Host $folderSummary -ForegroundColor Green
    } else {
        Write-Host $folderSummary -ForegroundColor Red
    }
    Write-Host ""

    $folderSummary + "`n" | Out-File -FilePath $logFile -Append -Encoding UTF8
}

# Calculate total execution time
$globalStats.EndTime = Get-Date
$globalStats.TotalDuration = [math]::Round(($globalStats.EndTime - $globalStats.StartTime).TotalSeconds, 2)
$globalStats.TotalSizeGB = [math]::Round($globalStats.TotalSizeGB, 2)

# Calculate success rate
$successRate = if ($globalStats.TotalFiles -gt 0) {
    [math]::Round(($globalStats.PassedFiles / $globalStats.TotalFiles) * 100, 2)
} else {
    0
}

# Generate final report
$finalReport = @"
==============================================
MD5 VERIFICATION FINAL REPORT
==============================================
Total Folders: $($globalStats.TotalFolders)
Total Files: $($globalStats.TotalFiles)
Passed Files: $($globalStats.PassedFiles)
Failed Files: $($globalStats.FailedFiles)
Missing Files: $($globalStats.MissingFiles)
Total Data Size: $($globalStats.TotalSizeGB) GB
Total Time: $($globalStats.TotalDuration) seconds
Success Rate: $successRate%
Start Time: $($globalStats.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))
End Time: $($globalStats.EndTime.ToString('yyyy-MM-dd HH:mm:ss'))

"@

Write-Host $finalReport -ForegroundColor Cyan
$finalReport | Out-File -FilePath $logFile -Append -Encoding UTF8

# Generate JSON report for programmatic access
$jsonStats = @{
    ReportType = "MD5Verification"
    StartTime = $globalStats.StartTime.ToString('yyyy-MM-dd HH:mm:ss')
    EndTime = $globalStats.EndTime.ToString('yyyy-MM-dd HH:mm:ss')
    TotalFolders = $globalStats.TotalFolders
    TotalFiles = $globalStats.TotalFiles
    PassedFiles = $globalStats.PassedFiles
    FailedFiles = $globalStats.FailedFiles
    MissingFiles = $globalStats.MissingFiles
    TotalSizeGB = $globalStats.TotalSizeGB
    TotalDuration = $globalStats.TotalDuration
    SuccessRate = $successRate
    Folders = @($globalStats.Folders | ForEach-Object {
        @{
            FolderName = $_.FolderName
            FolderPath = $_.FolderPath
            AllPassed = $_.AllPassed
            FileCount = $_.FileCount
            PassedFiles = $_.PassedFiles
            FailedFiles = $_.FailedFiles
            MissingFiles = $_.MissingFiles
            Duration = $_.Duration
        }
    })
}

try {
    $jsonStats | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonReport -Encoding UTF8
    Write-Host "JSON report saved to: $jsonReport" -ForegroundColor Yellow
} catch {
    Write-Host "WARNING: JSON report generation failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "Detailed log saved to: $logFile" -ForegroundColor Green
Write-Host "Verification completed successfully!" -ForegroundColor Green

# Display log file location
Write-Host "`nLog file location: $(Join-Path (Get-Location) $logFile)" -ForegroundColor Cyan

# Generate Problem Files Summary
Write-Host "`n" + "="*60 -ForegroundColor Red
Write-Host "PROBLEM FILES SUMMARY" -ForegroundColor Red
Write-Host "="*60 -ForegroundColor Red

$problemFiles = @()
foreach ($folder in $globalStats.Folders) {
    foreach ($file in $folder.Files) {
        if ($file.Status -ne "Passed") {
            $problemFiles += [PSCustomObject]@{
                Folder = $folder.FolderName
                File = $file.FileName
                Status = $file.Status
                SizeMB = $file.FileSizeMB
                ExpectedHash = $file.ExpectedHash
                ActualHash = $file.ActualHash
            }
        }
    }
}

if ($problemFiles.Count -eq 0) {
    Write-Host "? NO PROBLEM FILES FOUND - All files passed verification!" -ForegroundColor Green
} else {
    Write-Host "? PROBLEM FILES FOUND ($($problemFiles.Count) files):" -ForegroundColor Red

    $problemFiles | Group-Object Status | ForEach-Object {
        Write-Host "`n$($_.Name) ($($_.Count) files):" -ForegroundColor $(if($_.Name -eq "Failed"){"Red"}else{"Yellow"})
        $_.Group | ForEach-Object {
            Write-Host "   ?? $($_.Folder)/$($_.File)" -ForegroundColor $(if($_.Name -eq "Failed"){"Red"}else{"Yellow"})
        }
    }

    # Save problem files to separate report
    $problemReport = "Problem_Files_$logDate.csv"
    $problemFiles | Export-Csv -Path $problemReport -NoTypeInformation
    Write-Host "`n?? Detailed problem list saved to: $problemReport" -ForegroundColor Cyan
}

