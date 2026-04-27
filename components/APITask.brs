' APITask — handles all network calls off the render thread.

sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    request = m.top.request
    if request = "activate"
        doActivate()
    else if request = "poll"
        doPoll()
    else if request = "catalog"
        doCatalog()
    else if request = "stream"
        doStream()
    else
        m.top.result = { success: false, error: "unknown request: " + request }
    end if
end sub

sub doActivate()
    response = httpRequest("POST", "https://api.streamspindle.com/devices/activate", "", "{}")
    if response.success = false
        m.top.result = response
        return
    end if
    data = ParseJSON(response.body)
    if data <> invalid and data.code <> invalid
        m.top.result = { success: true, code: data.code }
    else
        m.top.result = { success: false, error: "activate failed: " + response.body }
    end if
end sub

sub doPoll()
    code = m.top.code
    if code = "" then m.top.result = { success: false, error: "missing code" } : return
    response = httpRequest("GET", "https://api.streamspindle.com/devices/activation/" + code, "", "")
    if response.success = false
        m.top.result = response
        return
    end if
    data = ParseJSON(response.body)
    if data <> invalid
        m.top.result = { success: true, status: data.status, device_token: data.device_token, channel_name: data.label_name }
    else
        m.top.result = { success: false, error: "poll failed" }
    end if
end sub

sub doCatalog()
    token = m.top.token
    if token = "" then m.top.result = { success: false, error: "missing token" } : return
    response = httpRequestDevice("GET", "https://api.streamspindle.com/devices/catalog", token)
    if response.success = false
        m.top.result = response
        return
    end if
    data = ParseJSON(response.body)
    if data <> invalid and data.catalog <> invalid
        m.top.result = { success: true, catalog: data.catalog, channel_name: data.channel_name, channel_color: data.channel_color }
    else
        m.top.result = { success: false, error: "catalog failed: " + response.body }
    end if
end sub

sub doStream()
    token = m.top.token
    catalogId = m.top.catalog_id
    if token = "" then return
    body = FormatJSON({ catalog_id: catalogId, event_type: "play" })
    httpRequestDevice("POST", "https://api.streamspindle.com/devices/stream", token, body)
    m.top.result = { success: true }
end sub

function httpRequest(method as string, url as string, token as string, body as string) as object
    port = CreateObject("roMessagePort")
    req = CreateObject("roUrlTransfer")
    req.SetUrl(url)
    req.SetPort(port)
    req.AddHeader("Accept", "application/json")
    req.EnableEncodings(true)
    req.SetCertificatesFile("common:/certs/ca-bundle.crt")
    req.InitClientCertificates()
    if token <> ""
        req.AddHeader("Authorization", "Bearer " + token)
    end if
    req.SetRequest(method)
    if method = "POST" or method = "PUT"
        req.AddHeader("Content-Type", "application/json")
        ok = req.AsyncPostFromString(body)
    else
        ok = req.AsyncGetToString()
    end if
    if not ok then return { success: false, error: "request start failed" }
    msg = wait(15000, port)
    if type(msg) <> "roUrlEvent" then req.AsyncCancel() : return { success: false, error: "timeout" }
    code = msg.GetResponseCode()
    if code < 200 or code >= 300 then return { success: false, error: "http " + code.toStr() }
    return { success: true, body: msg.GetString() }
end function

function httpRequestDevice(method as string, url as string, deviceToken as string, body = "" as string) as object
    port = CreateObject("roMessagePort")
    req = CreateObject("roUrlTransfer")
    req.SetUrl(url)
    req.SetPort(port)
    req.AddHeader("Accept", "application/json")
    req.AddHeader("Authorization", "Device " + deviceToken)
    req.EnableEncodings(true)
    req.SetCertificatesFile("common:/certs/ca-bundle.crt")
    req.InitClientCertificates()
    req.SetRequest(method)
    if method = "POST"
        req.AddHeader("Content-Type", "application/json")
        ok = req.AsyncPostFromString(body)
    else
        ok = req.AsyncGetToString()
    end if
    if not ok then return { success: false, error: "request start failed" }
    msg = wait(15000, port)
    if type(msg) <> "roUrlEvent" then req.AsyncCancel() : return { success: false, error: "timeout" }
    code = msg.GetResponseCode()
    if code < 200 or code >= 300 then return { success: false, error: "http " + code.toStr() }
    return { success: true, body: msg.GetString() }
end function
