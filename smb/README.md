# Optimizing SMB Streaming Performance from Windows 10 to Android

Enhance the performance of streaming files over Wi-Fi from your Windows 10 PC to an Android device by following this step-by-step guide.

## Assumptions

Before you begin, ensure the following:

- **Connection**: Windows 10 PC is connected to the router via **Ethernet**.
- **Router**: Supports **Wi-Fi 6** and provides a stable **5 GHz** connection to the Android device.
- **Roles**:
  - **Windows 10**: Acts as the **server**.
  - **Android 14**: Acts as the **client**, streaming files via SMB (e.g., using MX Player).
- **Setup**: No media server is involved; focus solely on optimizing raw SMB performance.

## Step 1: Enable SMBv2/SMBv3 and Disable SMBv1

SMBv2 and SMBv3 provide improved performance and security over SMBv1.

1. **Open PowerShell as Administrator**:

   - Press `Win + X` and select **Windows PowerShell (Admin)**.

2. **Disable SMBv1**:

   - Enter the following command and press **Enter**:
     ```powershell
     Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
     ```

3. **Enable SMBv2/SMBv3**:
   - Verify that SMBv2/SMBv3 is enabled by running:
     ```powershell
     Get-SmbServerConfiguration | Select EnableSMB2Protocol
     ```
   - Ensure the output shows `EnableSMB2Protocol : True`.

## Step 2: Configure Folder Sharing and Permissions

Proper sharing settings are crucial for a smooth SMB connection.

1. **Set Up Folder Sharing**:

   - Right-click the desired folder and select **Properties**.
   - Navigate to the **Sharing** tab and click **Advanced Sharing**.
   - Check **Share this folder** and click **OK**.

2. **Adjust Permissions**:

   - In the **Advanced Sharing** window, click **Permissions**.
   - Click **Add**, type **Everyone**, and set the desired permission level (**Read** or **Full Control**).
   - Remove any unnecessary user accounts to maintain security.

3. **Modify Security Settings**:

   - Go to the **Security** tab in the folder properties.
   - Ensure that only authorized users have appropriate permissions.
   - Click **Edit** to add or remove users and set their permissions accordingly.

   **⚠️ Security Note**: Only grant permissions to trusted users to protect your system.

## Step 3: Optimize SMB Server Settings in the Registry

Adjusting registry settings can enhance SMB performance. **Proceed with caution**.

**⚠️ Warning**: Incorrectly editing the registry can cause system issues. **Backup the registry** before making changes.

1. **Open Registry Editor**:

   - Press `Win + R`, type `regedit`, and press **Enter**.

2. **Navigate to SMB Server Parameters**:

   - Go to:
     ```
     HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters
     ```

3. **Increase SMB Credits**:

   - **Smb2CreditsMax**:
     - If it doesn't exist, right-click, select **New > DWORD (32-bit) Value**, name it `Smb2CreditsMax`.
     - Double-click it and set the value to **8192** (Decimal).
   - **Smb2CreditsMin**:
     - Similarly, create `Smb2CreditsMin` and set it to **512** (Decimal).

4. **Enable Large MTU Support**:

   - Create or modify a `DWORD` named `EnableLargeMtu` and set it to **1** (Decimal).
   - This allows larger network packets, boosting performance on high-speed networks.

5. **Increase Request Buffer Size**:
   - Create or modify a `DWORD` named `SizReqBuf` and set it to **65535** (Decimal).

## Step 4: Adjust Windows Networking Settings

Fine-tune network settings for optimal performance.

1. **Disable Network Throttling Index**:

   - In Registry Editor, navigate to:
     ```
     HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile
     ```
   - Create or modify a `DWORD` named `NetworkThrottlingIndex` and set it to **FFFFFFFF** (Hexadecimal).

2. **Disable Windows Auto-Tuning**:

   - Open **PowerShell** as Administrator.
   - Run the command:
     ```powershell
     netsh interface tcp set global autotuninglevel=disabled
     ```
   - **To Revert** (if issues arise):
     ```powershell
     netsh interface tcp set global autotuninglevel=normal
     ```

3. **Disable Remote Differential Compression**:
   - Go to **Control Panel** > **Programs** > **Turn Windows features on or off**.
   - Uncheck **Remote Differential Compression API Support** and click **OK**.

## Step 5: Optimize Network Adapter Settings

Ensure your Ethernet adapter is configured for maximum throughput.

1. **Update Ethernet Adapter Driver**:

   - Open **Device Manager**.
   - Expand **Network adapters**.
   - Right-click your Ethernet adapter and select **Update driver**.
   - Choose **Search automatically for updated driver software**.

2. **Adjust Advanced Adapter Settings**:

   - Right-click your Ethernet adapter and select **Properties**.
   - Go to the **Advanced** tab and configure the following:
     - **Speed & Duplex**: Set to the highest supported speed (e.g., **1.0 Gbps Full Duplex**).
     - **Jumbo Frame**: Enable and set **Jumbo Packet** size to **9014** bytes (if supported).
     - **Flow Control**: Set to **Enabled**.
     - **Large Send Offload (IPv4)**: **Enabled**.
     - **Large Send Offload (IPv6)**: **Enabled**.

3. **Disable Power Management for the Adapter**:
   - In the adapter's **Properties**, navigate to the **Power Management** tab.
   - Uncheck **Allow the computer to turn off this device to save power**.

## Step 6: Set High-Performance Power Options

Prevent power-saving features from limiting performance.

1. **Select a High-Performance Plan**:

   - Open **Control Panel** > **Power Options**.
   - Choose **High performance** or create a custom high-performance plan.

2. **Adjust Advanced Power Settings**:
   - Click **Change plan settings** next to your selected plan.
   - Click **Change advanced power settings**.
   - Expand **PCI Express** > **Link State Power Management** and set it to **Off**.

## Step 7: Exclude Shared Folders from Antivirus Scanning

Reduce overhead by preventing antivirus from scanning shared folders in real-time.

1. **Open Windows Security**:

   - Go to **Settings** > **Privacy & Security** > **Windows Security** > **Virus & threat protection**.

2. **Manage Exclusions**:

   - Click **Manage settings** under **Virus & threat protection settings**.
   - Scroll down to **Exclusions** and click **Add or remove exclusions**.
   - Click **Add an exclusion** and select **Folder**.
   - Choose your shared folder.

   **⚠️ Caution**: Excluding folders can pose security risks. Only exclude if necessary and ensure regular scans.

## Step 8: Restart the Computer

Reboot your system to apply all the changes made.

## Step 9: Monitor SMB Performance

Use system tools to verify performance improvements.

1. **Use Performance Monitor**:

   - Press `Win + R`, type `perfmon`, and press **Enter**.
   - Navigate to **Monitoring Tools** > **Performance Monitor**.
   - Click the **+** icon to add the following counters:
     - **SMB Server Shares**: **Files Open**, **Reads/sec**, **Writes/sec**.
     - **Network Interface**: **Bytes Total/sec**.
     - **TCPv4**/**TCPv6**: **Segments Retransmitted/sec**.

2. **Observe Network Activity**:
   - Open **Task Manager** (`Ctrl + Shift + Esc`) and go to the **Performance** tab.
   - Select **Ethernet** to view real-time network usage.

## Additional Recommendations

- **Keep Windows Updated**: Regularly install Windows updates for optimal performance and security.
- **Limit Background Applications**: Close unnecessary programs that may consume bandwidth or system resources.
- **Optimize Android SMB Client**:

  - **Update the App**: Ensure your SMB client app (e.g., MX Player) is up to date.
  - **Configure SMB Version**: Use SMBv2 or SMBv3 if the app allows.
  - **Adjust Buffer Settings**: Modify buffer sizes within the app for smoother playback.

- **Check Wi-Fi Signal Strength**: Ensure your Android device has a strong Wi-Fi signal to minimize latency and packet loss.
- **Use Quality of Service (QoS)**: If your router supports QoS, prioritize SMB or streaming traffic to enhance performance.

## Conclusion

By meticulously following these steps, you can significantly improve SMB streaming performance from your Windows 10 server to your Android 14 device over Wi-Fi. Regularly monitor performance and adjust settings as needed to maintain optimal streaming quality.
