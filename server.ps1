# Simple TCP Web Server to serve index.html (runs without admin privileges!)
$port = 8000
$ipAddress = [System.Net.IPAddress]::Any
$listener = New-Object System.Net.Sockets.TcpListener($ipAddress, $port)

# Force TLS 1.2 for all web requests to prevent SSL handshake errors on modern secure APIs
[System.Net.ServicePointManager]::SecurityProtocol = 3072

try {
    $listener.Start()
    Write-Host "============================================="
    Write-Host "   TJU Charging Map Local Web Server Started"
    Write-Host "============================================="
    Write-Host "Listening on port: $port"
    Write-Host ""
    
    # Get local IP address for user instruction
    $ips = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" }
    Write-Host "Please open one of the following URLs in your iPhone Safari browser:"
    foreach ($ip in $ips) {
        Write-Host "👉  http://$($ip.IPAddress):$port"
    }
    Write-Host ""
    Write-Host "(Make sure your phone and computer are on the same Wi-Fi)"
    Write-Host "============================================="

    # Keep listening for incoming TCP requests
    while ($true) {
        $client = $null
        try {
            $client = $listener.AcceptTcpClient()
            $stream = $client.GetStream()
            
            # Consuming the request header
            $buffer = New-Object Byte[] 16384
            $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
            if ($bytesRead -eq 0) {
                $stream.Close()
                $client.Close()
                continue
            }
            
            $reqStr = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $bytesRead)
            
            # Split request into lines
            $lines = $reqStr -split "`r`n"
            $reqLine = $lines[0]
            
            # Handle CORS proxy request: GET or OPTIONS /proxy?url=...
            if ($reqLine -match "^(?<method>GET|OPTIONS) /proxy\?url=(?<url>[^\s]+)\s+HTTP") {
                $method = $Matches['method']
                $encodedUrl = $Matches['url']
                $targetUrl = [System.Uri]::UnescapeDataString($encodedUrl)
                
                if ($method -eq "OPTIONS") {
                    Write-Host "Responding to preflight OPTIONS request for: $targetUrl"
                    $CRLF = [char]13 + [char]10
                    $headers = 'HTTP/1.1 204 No Content' + $CRLF +
                               'Access-Control-Allow-Origin: *' + $CRLF +
                               'Access-Control-Allow-Methods: GET, OPTIONS' + $CRLF +
                               'Access-Control-Allow-Headers: Content-Type, Authorization, token' + $CRLF +
                               'Access-Control-Max-Age: 86400' + $CRLF +
                               'Connection: close' + $CRLF + $CRLF
                    $headersBytes = [System.Text.Encoding]::UTF8.GetBytes($headers)
                    $stream.Write($headersBytes, 0, $headersBytes.Length)
                    $stream.Close()
                    $client.Close()
                    continue
                }
                
                Write-Host "Proxying request to: $targetUrl"
                
                # Extract request headers we need to forward
                $targetHeaders = @{}
                foreach ($line in $lines) {
                    if ($line -match "^Authorization:\s*(?<val>.*)$") {
                        $targetHeaders["Authorization"] = $Matches['val'].Trim()
                    }
                    if ($line -match "^token:\s*(?<val>.*)$") {
                        $targetHeaders["token"] = $Matches['val'].Trim()
                    }
                }
                
                # Fetch target API directly from computer (using domestic Chinese IP)
                try {
                    $webResponse = Invoke-WebRequest -Uri $targetUrl -Headers $targetHeaders -Method Get -UseBasicParsing -TimeoutSec 10
                    $resBody = $webResponse.Content
                    $resBodyBytes = [System.Text.Encoding]::UTF8.GetBytes($resBody)
                    
                    $CRLF = [char]13 + [char]10
                    $headers = 'HTTP/1.1 200 OK' + $CRLF +
                               'Content-Type: application/json; charset=utf-8' + $CRLF +
                               'Content-Length: ' + $resBodyBytes.Length + $CRLF +
                               'Access-Control-Allow-Origin: *' + $CRLF +
                               'Connection: close' + $CRLF + $CRLF
                    $headersBytes = [System.Text.Encoding]::UTF8.GetBytes($headers)
                    
                    $stream.Write($headersBytes, 0, $headersBytes.Length)
                    $stream.Write($resBodyBytes, 0, $resBodyBytes.Length)
                } catch {
                    Write-Host "Proxy error: $_"
                    $errMsg = '{"error": "Proxy request failed", "message": "' + $_.Exception.Message.Replace('"', '\"') + '"}'
                    $errBytes = [System.Text.Encoding]::UTF8.GetBytes($errMsg)
                    
                    $CRLF = [char]13 + [char]10
                    $headers = 'HTTP/1.1 500 Internal Server Error' + $CRLF +
                               'Content-Type: application/json; charset=utf-8' + $CRLF +
                               'Content-Length: ' + $errBytes.Length + $CRLF +
                               'Access-Control-Allow-Origin: *' + $CRLF +
                               'Connection: close' + $CRLF + $CRLF
                    $headersBytes = [System.Text.Encoding]::UTF8.GetBytes($headers)
                    $stream.Write($headersBytes, 0, $headersBytes.Length)
                    $stream.Write($errBytes, 0, $errBytes.Length)
                }
            } else {
                # Serve the index.html content directly
                $filePath = Join-Path $PSScriptRoot "index.html"
                if (Test-Path $filePath) {
                    $html = [System.IO.File]::ReadAllText($filePath)
                    $htmlBytes = [System.Text.Encoding]::UTF8.GetBytes($html)
                    
                    $CRLF = [char]13 + [char]10
                    $headers = 'HTTP/1.1 200 OK' + $CRLF +
                               'Content-Type: text/html; charset=utf-8' + $CRLF +
                               'Content-Length: ' + $htmlBytes.Length + $CRLF +
                               'Access-Control-Allow-Origin: *' + $CRLF +
                               'Connection: close' + $CRLF + $CRLF
                    $headersBytes = [System.Text.Encoding]::UTF8.GetBytes($headers)
                    
                    $stream.Write($headersBytes, 0, $headersBytes.Length)
                    $stream.Write($htmlBytes, 0, $htmlBytes.Length)
                } else {
                    $CRLF = [char]13 + [char]10
                    $err = 'HTTP/1.1 404 Not Found' + $CRLF + 'Content-Length: 14' + $CRLF + 'Connection: close' + $CRLF + $CRLF + 'File not found'
                    $errBytes = [System.Text.Encoding]::UTF8.GetBytes($err)
                    $stream.Write($errBytes, 0, $errBytes.Length)
                }
            }
            
            $stream.Close()
            $client.Close()
        } catch {
            Write-Host "TCP Connection error: $_"
            if ($null -ne $client) { $client.Close() }
        }
    }
} catch {
    Write-Error $_
} finally {
    $listener.Stop()
}
