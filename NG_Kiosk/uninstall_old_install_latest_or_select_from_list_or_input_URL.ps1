# Check if the PowerShell PackageManagement module is installed, if not install it
if (-not (Get-Module -Name PackageManagement -ListAvailable)) {
    Install-Module -Name PackageManagement -Force -Scope CurrentUser -AllowClobber
}

# Function to download the file from a given URL
function Download-File {
    param (
        [string]$url,
        [string]$destination
    )

    Write-Host "Downloading file from $url..."
    try {
        Invoke-WebRequest -Uri $url -OutFile $destination -ErrorAction Stop
        Write-Host "File downloaded successfully to $destination."
    } catch {
        Write-Host "Error downloading file: $_"
        exit
    }
}

# Function to extract the version from the URL
function Extract-Version {
    param (
        [string]$url
    )
    
    # Use regex to extract the version from the URL
    if ($url -match "Grubbrr%20Kiosk_(\d+\.\d+\.\d+\.\d+)_") {
        return $matches[1]  # Return the extracted version
    } elseif ($url -match "Grubbrr%20Kiosk_(\d+\.\d+\.\d+)") {
        return $matches[1]  # Return the extracted version without the fourth digit
    } else {
        Write-Host "Version not found in the URL."
        return $null
    }
}

# Define paths
$downloadFolderPath = Join-Path -Path $env:UserProfile -ChildPath "Downloads"
$programName = "Grubbrr Kiosk"

# Get the latest MSI file in the Downloads folder matching the pattern
$existingMsiFiles = Get-ChildItem -Path $downloadFolderPath -Filter "Grubbrr Kiosk_*.msi" | Sort-Object LastWriteTime -Descending

# Check if any MSI files are found
if ($existingMsiFiles) {
    # Display the existing MSI files and ask for the user's choice
    Write-Host "Found the following MSI files:"
    foreach ($file in $existingMsiFiles) {
        Write-Host $file.Name
    }

    $userInput = Read-Host "Do you want to proceed with the latest version found? (Y/N)"

    if ($userInput -eq 'Y' -or $userInput -eq 'y') {
        $msiFilePath = $existingMsiFiles[0].FullName
        Write-Host "Proceeding with installation of $($existingMsiFiles[0].Name)..."
    } elseif ($userInput -eq 'N' -or $userInput -eq 'n') {
        # Ask if they want to select from the list
        $selectFromList = Read-Host "Do you want to select an MSI from the list? (Y/N)"
        
        if ($selectFromList -eq 'Y' -or $selectFromList -eq 'y') {
            $index = 0
            foreach ($file in $existingMsiFiles) {
                Write-Host "${index}: $($file.Name)"
                $index++
            }
            
            $selectedIndex = Read-Host "Enter the index of the MSI you want to install"
            if ($selectedIndex -lt $existingMsiFiles.Count) {
                $msiFilePath = $existingMsiFiles[$selectedIndex].FullName
                Write-Host "You have selected $($existingMsiFiles[$selectedIndex].Name)"
            } else {
                Write-Host "Invalid selection. Exiting."
                exit
            }
        } else {
            # Ask for the URL to download the file
            $url = Read-Host "Please enter the URL to download the script"
            $versionFromUrl = Extract-Version -url $url

            if ($versionFromUrl) {
                $msiFilePath = Join-Path -Path $downloadFolderPath -ChildPath "Grubbrr Kiosk setup $versionFromUrl.msi"
                Download-File -url $url -destination $msiFilePath
            } else {
                Write-Host "Failed to extract version from the URL. Exiting."
                exit
            }
        }
    } else {
        Write-Host "Invalid input. Exiting."
        exit
    }
} else {
    # If no MSI files were found, prompt for the URL
    $url = Read-Host "No MSI files found. Please enter the URL to download the script"
    $versionFromUrl = Extract-Version -url $url

    if ($versionFromUrl) {
        $msiFilePath = Join-Path -Path $downloadFolderPath -ChildPath "Grubbrr Kiosk setup $versionFromUrl.msi"
        Download-File -url $url -destination $msiFilePath
    } else {
        Write-Host "Failed to extract version from the URL. Exiting."
        exit
    }
}

# Function to stop the program's processes
function Stop-ProgramProcesses {
    param(
        [string]$programName
    )

    $processes = Get-Process | Where-Object { $_.MainWindowTitle -eq $programName }
    if ($processes) {
        Write-Host "Stopping processes related to $programName..."
        $processes | ForEach-Object { Stop-Process -Id $_.Id -Force }
        Write-Host "Processes related to $programName have been stopped."
    }
}

# Function to uninstall the program if installed
function Uninstall-Program {
    param(
        [string]$packageName,
        [string]$programName
    )

    Stop-ProgramProcesses -programName $programName

    $package = Get-Package -Name $packageName -ErrorAction SilentlyContinue

    if ($package) {
        Write-Host "Uninstalling $packageName..."
        Uninstall-Package -Name $packageName -Force -Confirm:$false
        Write-Host "$packageName has been uninstalled successfully."
    } else {
        Write-Host "$packageName is not installed."
    }
}

# Function to install the selected MSI file
function Install-Program {
    # Define the path for the install log file
    $installLogFilePath = Join-Path -Path $downloadFolderPath -ChildPath "install.log"

    Write-Host "Installing $($msiFilePath)..."
    
    # Install the MSI file in passive mode and generate a log file
    Start-Process -FilePath msiexec.exe -ArgumentList "/i `"$msiFilePath`" /quiet /passive /L*V `"$installLogFilePath`"" -Wait

    # Define the path to the installed application
    $appPath = "C:\Program Files\Grubbrr Kiosk\Grubbrr Kiosk.exe"

    # Check if the application exists and start it
    if (Test-Path $appPath) {
        Start-Process -FilePath $appPath
        Write-Host "Installation successful. Application started."
    } else {
        Write-Host "Failed to locate the installed application."
    }
}

try {
    # Main execution
    $packageName = "Grubbrr Kiosk"

    # Uninstall the existing program
    Uninstall-Program -packageName $packageName -programName $programName

    # Install the selected version
    Install-Program
} catch {
    Write-Host "An error occurred: $_"
} finally {
    Read-Host "Please press Enter to exit"
}
