' HomeScene — StreamSpindle / SpindleCast Roku channel
' Uses device-activation flow — no passwords stored on device.

sub init()
    m.top.setFocus(true)
    m.list       = m.top.findNode("contentList")
    m.loadingLabel = m.top.findNode("loadingLabel")
    m.codeLabel  = m.top.findNode("codeLabel")
    m.videoPlayer = m.top.findNode("videoPlayer")
    m.videoPlayer.observeField("state", "onVideoStateChange")
    m.deviceToken = ""
    m.channelName = "StreamSpindle"
    m.pollTimer  = CreateObject("roSGNode", "Timer")
    m.pollTimer.duration = 5
    m.pollTimer.repeat = true
    m.pollTimer.observeField("fire", "onPollTimer")
    checkActivation()
end sub

' ── ACTIVATION ────────────────────────────────────────────────────────────────

function readToken() as string
    section = CreateObject("roRegistrySection", "StreamSpindle_Device")
    if section.Exists("device_token") then return section.Read("device_token")
    return ""
end function

sub saveToken(token as string)
    section = CreateObject("roRegistrySection", "StreamSpindle_Device")
    section.Write("device_token", token)
    section.Flush()
end sub

sub checkActivation()
    token = readToken()
    if token <> ""
        m.deviceToken = token
        loadCatalog()
    else
        requestActivationCode()
    end if
end sub

sub requestActivationCode()
    m.loadingLabel.visible = false
    m.task = CreateObject("roSGNode", "APITask")
    m.task.observeField("result", "onActivateResult")
    m.task.request = "activate"
    m.task.control = "RUN"
end sub

sub onActivateResult()
    result = m.task.result
    if result.success <> true
        m.loadingLabel.text = "Could not connect: " + result.error
        m.loadingLabel.visible = true
        return
    end if
    m.activationCode = result.code
    m.codeLabel.text = "Visit portal.streamspindle.com" + chr(10) + "Enter code: " + result.code
    m.codeLabel.visible = true
    m.pollTimer.control = "start"
end sub

sub onPollTimer()
    if m.activationCode = invalid or m.activationCode = "" then return
    m.pollTask = CreateObject("roSGNode", "APITask")
    m.pollTask.observeField("result", "onPollResult")
    m.pollTask.request = "poll"
    m.pollTask.code = m.activationCode
    m.pollTask.control = "RUN"
end sub

sub onPollResult()
    result = m.pollTask.result
    if result.success <> true then return
    if result.status = "paired"
        m.pollTimer.control = "stop"
        m.codeLabel.visible = false
        saveToken(result.device_token)
        m.deviceToken = result.device_token
        if result.channel_name <> invalid and result.channel_name <> ""
            m.top.findNode("channelTitle").text = result.channel_name
        end if
        loadCatalog()
    end if
end sub

' ── CATALOG ───────────────────────────────────────────────────────────────────

sub loadCatalog()
    m.loadingLabel.text = "Loading..."
    m.loadingLabel.visible = true
    m.catalogTask = CreateObject("roSGNode", "APITask")
    m.catalogTask.observeField("result", "onCatalogResult")
    m.catalogTask.token = m.deviceToken
    m.catalogTask.request = "catalog"
    m.catalogTask.control = "RUN"
end sub

sub onCatalogResult()
    result = m.catalogTask.result
    if result.success <> true
        m.loadingLabel.text = "Could not load content: " + result.error
        return
    end if
    if result.channel_name <> invalid and result.channel_name <> ""
        m.top.findNode("channelTitle").text = result.channel_name
    end if
    contentNode = CreateObject("roSGNode", "ContentNode")
    items = result.catalog
    if items = invalid or items.Count() = 0
        m.loadingLabel.text = "No content available yet."
        return
    end if
    for each track in items
        item = CreateObject("roSGNode", "ContentNode")
        if track.title <> invalid then item.title = track.title
        if track.description <> invalid then item.description = track.description
        if track.artwork_url <> invalid then item.hdPosterUrl = track.artwork_url
        if track.stream_url <> invalid
            item.url = track.stream_url
            item.streamFormat = "hls"
        else if track.audio_url <> invalid
            item.url = track.audio_url
            item.streamFormat = "mp4"
        end if
        if track.artist <> invalid then item.shortDescriptionLine2 = track.artist
        contentNode.appendChild(item)
    end for
    m.list.content = contentNode
    m.list.visible = true
    m.loadingLabel.visible = false
    m.list.setFocus(true)
end sub

' ── PLAYBACK ──────────────────────────────────────────────────────────────────

sub onVideoStateChange()
    state = m.videoPlayer.state
    if state = "finished" or state = "error"
        m.videoPlayer.visible = false
        m.videoPlayer.control = "stop"
        m.list.visible = true
        m.list.setFocus(true)
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if press then
        if m.videoPlayer.visible = true
            if key = "back"
                m.videoPlayer.visible = false
                m.videoPlayer.control = "stop"
                m.list.visible = true
                m.list.setFocus(true)
                return true
            end if
        else
            if key = "OK" or key = "play"
                selectedItem = m.list.content.getChild(m.list.itemFocused)
                if selectedItem <> invalid and selectedItem.url <> ""
                    videoContent = CreateObject("roSGNode", "ContentNode")
                    videoContent.url = selectedItem.url
                    videoContent.streamFormat = selectedItem.streamFormat
                    videoContent.title = selectedItem.title
                    m.videoPlayer.content = videoContent
                    m.videoPlayer.visible = true
                    m.videoPlayer.control = "play"
                    reportStream(selectedItem)
                    m.videoPlayer.setFocus(true)
                    m.list.visible = false
                end if
                return true
            end if
        end if
    end if
    return false
end function

sub reportStream(item as object)
    if m.deviceToken = "" or item = invalid then return
    m.streamTask = CreateObject("roSGNode", "APITask")
    m.streamTask.token = m.deviceToken
    m.streamTask.catalog_id = item.id
    m.streamTask.request = "stream"
    m.streamTask.control = "RUN"
end sub
