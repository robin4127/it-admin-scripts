#Requires -Version 5.1
<#
.SYNOPSIS
    Tests Microsoft 365 SMTP relay and STARTTLS protocol/cipher negotiation.
.DESCRIPTION
    Tests an anonymous SMTP connection to a Microsoft 365 MX endpoint on TCP/25.

    Mode Plain (default): sends one unencrypted test message, as the previous
    script did. Mode StartTls: negotiates and validates STARTTLS, reports the
    negotiated protocol/cipher, and does not send mail unless -SendAfterTls is set.
    Mode Both: runs Plain, then StartTls in a separate SMTP connection.

    A STARTTLS result describes THIS COMPUTER, not the cipher capabilities of
    a printer. Internal delivery may be Direct Send instead of SMTP relay.
    SMTP acceptance does not prove connector matching or final delivery.
.PARAMETER Mode
    Select Plain (default), StartTls, or Both.
.PARAMETER Sender
    Sender address for MX lookup and test mail; prompted when needed.
.PARAMETER Recipient
    Destination for actual test mail; prompted when needed.
.PARAMETER SmtpServer
    Optional explicit Microsoft 365 MX host if the public MX is third-party.
.PARAMETER SendAfterTls
    Also send one real test message in the STARTTLS session; when using Both,
    the script sends two test messages (one plain and one encrypted).
.PARAMETER TimeoutSeconds
    TCP and SMTP read/write timeout in seconds (default 15).
.EXAMPLE
    .\Test-M365SmtpRelay.ps1
    Original anonymous plaintext relay test, with interactive prompts.
.EXAMPLE
    .\Test-M365SmtpRelay.ps1 -Mode StartTls -Sender 'scanner@contoso.com'
    Handshake only: no message sent.
.EXAMPLE
    .\Test-M365SmtpRelay.ps1 -Mode Both -Sender 'scanner@contoso.com' -Recipient 'test@example.net'
    One plaintext test mail and a separate encrypted handshake.
.EXAMPLE
    .\Test-M365SmtpRelay.ps1 -Mode StartTls -SendAfterTls -SmtpServer 'contoso-com.mail.protection.outlook.com' -Sender 'scanner@contoso.com' -Recipient 'test@example.net'
    Send a real test mail after the STARTTLS handshake.
.NOTES
    Version: 0.2.0
    Requires: Windows PowerShell 5.1 or PowerShell 7; Resolve-DnsName for MX
              discovery, and TCP/25 connectivity.
    Permissions: No Microsoft 365 admin rights (anonymous SMTP).
    Impact: Sends email only with Plain or -SendAfterTls; no tenant changes.
    Security: Retains default server certificate and hostname validation.
    Limitations: No printer TLS probe, SMTP AUTH, connector authentication,
                 external IP parity check or delivery trace.
#>
[CmdletBinding()]
param(
    [ValidateSet('Plain','StartTls','Both')][string]$Mode='Plain',
    [string]$Sender,
    [string]$Recipient,
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$')][string]$SmtpServer,
    [switch]$SendAfterTls,
    [ValidateRange(3,120)][int]$TimeoutSeconds=15
)
$ErrorActionPreference='Stop'

function Assert-Email {
    param([string]$Value,[string]$Label)
    if ($Value -notmatch '^[^@<>\s]+@[^@<>\s]+\.[^@<>\s]+$') { throw "Invalid $Label email: $Value" }
}
function New-SmtpText {
    param($Session,[System.IO.Stream]$Transport)
    $Session.Reader=[System.IO.StreamReader]::new($Transport,[Text.Encoding]::ASCII,$false,1024,$true)
    $Session.Writer=[System.IO.StreamWriter]::new($Transport,[Text.Encoding]::ASCII,1024,$true)
    $Session.Writer.NewLine=([string][char]13+[char]10)
    $Session.Writer.AutoFlush=$true
}
function Close-Smtp {
    param($Session)
    if (-not $Session) { return }
    if ($Session.Writer) { $Session.Writer.Dispose() }
    if ($Session.Reader) { $Session.Reader.Dispose() }
    if ($Session.Ssl) { $Session.Ssl.Dispose() }
    if ($Session.Network) { $Session.Network.Dispose() }
    if ($Session.Client) { $Session.Client.Dispose() }
}
function Read-SmtpReply {
    param($Session)
    $lines=[System.Collections.Generic.List[string]]::new()
    $firstCode=$null
    for ($i=0;$i -lt 80;$i++) {
        $line=$Session.Reader.ReadLine()
        if ($null -eq $line) { throw 'SMTP server closed the connection unexpectedly.' }
        Write-Host "S: $line" -ForegroundColor DarkGray
        if ($line -notmatch '^(\d{3})([- ])') { throw "Invalid SMTP reply: $line" }
        if (-not $firstCode) { $firstCode=$Matches[1] }
        if ($Matches[1] -ne $firstCode) { throw "Inconsistent SMTP reply: $line" }
        $lines.Add($line)
        if ($Matches[2] -eq ' ') { return $lines.ToArray() }
    }
    throw 'SMTP reply has too many lines.'
}
function Send-Smtp {
    param($Session,[string]$Command)
    Write-Host "C: $Command" -ForegroundColor Cyan
    $Session.Writer.WriteLine($Command)
    return Read-SmtpReply -Session $Session
}
function Assert-Code {
    param([string[]]$Lines,[int[]]$Expected,[string]$Step)
    if (-not $Lines) { throw "No reply for $Step" }
    $code=[int]$Lines[-1].Substring(0,3)
    if ($code -notin $Expected) { throw "$Step failed: $($Lines[-1])" }
}
function Open-Smtp {
    param([string]$HostName,[int]$Timeout)
    $session=[pscustomobject]@{Client=$null;Network=$null;Reader=$null;Writer=$null;Ssl=$null}
    try {
        $session.Client=[Net.Sockets.TcpClient]::new()
        $connection=$session.Client.ConnectAsync($HostName,25)
        if (-not $connection.Wait($Timeout*1000)) { throw "TCP/25 timeout to $HostName" }
        $connection.GetAwaiter().GetResult() | Out-Null
        $session.Client.ReceiveTimeout=$Timeout*1000
        $session.Client.SendTimeout=$Timeout*1000
        $session.Network=$session.Client.GetStream()
        New-SmtpText $session $session.Network
        Assert-Code -Lines @(Read-SmtpReply $session) -Expected @(220) -Step 'Banner'
        return $session
    } catch { Close-Smtp $session; throw }
}
function Send-TestMail {
    param($Session,[string]$MailFrom,[string]$MailTo,[string]$HostName,[string]$TransportName)
    Assert-Code -Lines @(Send-Smtp $Session "MAIL FROM:<$MailFrom>") -Expected @(250) -Step 'MAIL FROM'
    Assert-Code -Lines @(Send-Smtp $Session "RCPT TO:<$MailTo>") -Expected @(250,251) -Step 'RCPT TO'
    Assert-Code -Lines @(Send-Smtp $Session 'DATA') -Expected @(354) -Step 'DATA'
    $utc=(Get-Date).ToUniversalTime()
    $message=@(
        "From: <$MailFrom>"
        "To: <$MailTo>"
        "Subject: Microsoft 365 SMTP Relay Test - $($utc.ToString('yyyy-MM-dd HH:mm:ss')) UTC"
        "Date: $($utc.ToString('r'))"
        'MIME-Version: 1.0'
        'Content-Type: text/plain; charset=us-ascii'
        ''
        'Microsoft 365 SMTP relay diagnostic.'
        "Server: $HostName"
        "Transport: $TransportName"
        'SMTP acceptance does not prove final delivery.'
    )
    Write-Host 'C: <test message>' -ForegroundColor Cyan
    foreach ($line in $message) {
        if ($line.StartsWith('.')) { $line='.'+$line }
        $Session.Writer.WriteLine($line)
    }
    $Session.Writer.WriteLine('.')
    Write-Host 'C: .' -ForegroundColor Cyan
    Assert-Code -Lines @(Read-SmtpReply $Session) -Expected @(250) -Step 'Message acceptance'
    Write-Host '[OK] Test mail accepted; check message trace and recipient.' -ForegroundColor Green
}
function Invoke-SmtpDiagnostic {
    param([string]$HostName,[bool]$UseTls,[bool]$SendMessage,
          [string]$MailFrom,[string]$MailTo,[int]$Timeout)
    $label=if($UseTls){'STARTTLS'}else{'PLAIN'}
    Write-Host ''
    Write-Host "=== $label (TCP/25) ===" -ForegroundColor Yellow
    $session=$null
    $protocol=$null
    $suite=$null
    try {
        $session=Open-Smtp -HostName $HostName -Timeout $Timeout
        $ehlo=if ($env:COMPUTERNAME -match '^[a-zA-Z0-9-]+$') {$env:COMPUTERNAME} else {'smtp-relay-test.local'}
        $response=@(Send-Smtp $session "EHLO $ehlo")
        Assert-Code -Lines $response -Expected @(250) -Step 'EHLO'
        if ($UseTls) {
            if (@($response | Where-Object { $_ -match '^250[- ]STARTTLS(\s|$)' }).Count -eq 0) {
                throw 'Server does not advertise STARTTLS.'
            }
            Assert-Code -Lines @(Send-Smtp $session 'STARTTLS') -Expected @(220) -Step 'STARTTLS'
            # Replace text wrappers without closing the underlying TCP stream.
            $session.Writer.Dispose()
            $session.Reader.Dispose()
            $session.Writer=$null
            $session.Reader=$null
            # Default .NET certificate chain + hostname verification is preserved.
            $session.Ssl=[Net.Security.SslStream]::new($session.Network,$true)
            $session.Ssl.ReadTimeout=$Timeout*1000
            $session.Ssl.WriteTimeout=$Timeout*1000
            $session.Ssl.AuthenticateAsClient($HostName)
            $protocol=[string]$session.Ssl.SslProtocol
            $suite=try {[string]$session.Ssl.NegotiatedCipherSuite} catch {'Unavailable on this .NET runtime'}
            Write-Host "[OK] STARTTLS: $protocol (certificate validated)" -ForegroundColor Green
            Write-Host "Cipher suite: $suite"
            Write-Host "Cipher algorithm: $($session.Ssl.CipherAlgorithm) / $($session.Ssl.CipherStrength) bits"
            if ($protocol -notin @('Tls12','Tls13')) { Write-Warning "Negotiated protocol below TLS 1.2: $protocol" }
            New-SmtpText $session $session.Ssl
            Assert-Code -Lines @(Send-Smtp $session "EHLO $ehlo") -Expected @(250) -Step 'EHLO after STARTTLS'
        }
        if ($SendMessage) {
            Send-TestMail -Session $session -MailFrom $MailFrom -MailTo $MailTo -HostName $HostName -TransportName $label
        }
        Assert-Code -Lines @(Send-Smtp $session 'QUIT') -Expected @(221) -Step 'QUIT'
        return [pscustomobject]@{Mode=$label;Success=$true;MessageSent=$SendMessage;TlsVersion=$protocol;CipherSuite=$suite}
    } catch {
        Write-Warning "$label failed: $($_.Exception.Message)"
        return [pscustomobject]@{Mode=$label;Success=$false;MessageSent=$false;TlsVersion=$protocol;CipherSuite=$suite}
    } finally { Close-Smtp $session }
}

if ($SendAfterTls -and $Mode -eq 'Plain') { throw '-SendAfterTls requires StartTls or Both.' }
$sendMail=($Mode -in @('Plain','Both')) -or $SendAfterTls.IsPresent
if (-not $Sender -and ($sendMail -or -not $SmtpServer)) { $Sender=Read-Host 'Sender email address' }
if ($Sender) { Assert-Email -Value $Sender -Label 'sender' }
if ($sendMail) {
    if (-not $Sender) { throw 'Sender is required to send messages.' }
    if (-not $Recipient) { $Recipient=Read-Host 'Recipient email address' }
    Assert-Email -Value $Recipient -Label 'recipient'
}
if (-not $SmtpServer) {
    $domain=($Sender -split '@')[-1]
    $mx=@(Resolve-DnsName -Name $domain -Type MX -ErrorAction Stop |
        Where-Object { $_.NameExchange -match '\.mail\.protection\.outlook\.com\.?$' } |
        Sort-Object Preference)
    if ($mx.Count -eq 0) { throw "No Microsoft 365 MX for $domain. Use -SmtpServer for filtered domains." }
    $SmtpServer=$mx[0].NameExchange.TrimEnd('.')
}
Write-Host "SMTP endpoint: $SmtpServer" -ForegroundColor Cyan
Write-Host 'TLS results reflect this workstation, not the printer.' -ForegroundColor Yellow
$results=@()
if ($Mode -in @('Plain','Both')) {
    $results+=Invoke-SmtpDiagnostic -HostName $SmtpServer -UseTls $false -SendMessage $true -MailFrom $Sender -MailTo $Recipient -Timeout $TimeoutSeconds
}
if ($Mode -in @('StartTls','Both')) {
    $results+=Invoke-SmtpDiagnostic -HostName $SmtpServer -UseTls $true -SendMessage $SendAfterTls.IsPresent -MailFrom $Sender -MailTo $Recipient -Timeout $TimeoutSeconds
}
Write-Host ''
Write-Host '=== SUMMARY ===' -ForegroundColor Cyan
$results | Format-Table Mode,Success,MessageSent,TlsVersion,CipherSuite -AutoSize | Out-Host
if (@($results | Where-Object { -not $_.Success }).Count -gt 0) { throw 'One or more SMTP tests failed.' }
Write-Host '[OK] All selected SMTP tests completed.' -ForegroundColor Green
