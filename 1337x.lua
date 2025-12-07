--1.22
local VERSION = "1.0"
client.auto_script_update("https://raw.githubusercontent.com/Y0URD34TH/Project-GLD/refs/heads/main/Scripts/1337x.lua", VERSION)

local function endsWith(str, pattern)
    return string.sub(str, -string.len(pattern)) == pattern
end

local function substituteRomanNumerals(gameName)
    local romans = {
        [" I"] = " 1",
        [" II"] = " 2",
        [" III"] = " 3",
        [" IV"] = " 4",
        [" V"] = " 5",
        [" VI"] = " 6",
        [" VII"] = " 7",
        [" VIII"] = " 8",
        [" IX"] = " 9",
        [" X"] = " 10"
    }

    for numeral, substitution in pairs(romans) do
        if endsWith(gameName, numeral) then
            gameName = string.sub(gameName, 1, -string.len(numeral) - 1) .. substitution
        end
    end

    return gameName
end

local regex = ""
local magnetRegex = "href%s*=%s*\"(magnet:[^\"]+)\""
local provider = 0
local searchprovider = ""
local version = client.GetVersionDouble()
local cfCookies1337x = ""  -- Renamed to match reference pattern

local headers = {
    ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 ProjectGLD/2.15"
}

if version < 3.52 then
    Notifications.push_error("Lua Script", "Program is outdated. Please update the app to use this script!")
else
    Notifications.push_success("Lua Script", "1337x script is loaded and working!")
    Notifications.push_warning("1337x Script", "1337x is marked as unsafe by many sources, so only use trusted uploaders from here. You have been warned!")
    
    menu.add_check_box("Roman Numbers Conversion 1337x")
    local romantonormalnumbers = true
    menu.set_bool("Roman Numbers Conversion 1337x", true)

    local function checkboxcall()
        regex = "<a href%s*=%s*\"(/torrent/[^\"]+)\""
        searchprovider = "1337x.to"
        romantonormalnumbers = menu.get_bool("Roman Numbers Conversion 1337x")
    end

    local function cfcallback(cookie, url)
        if url == "https://".. searchprovider then
            cfCookies1337x = cookie
            local cfclearence = "cf_clearance=" .. tostring(cfCookies1337x)
            headers = {
                ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 ProjectGLD/2.15",
                ["Cookie"] = cfclearence
            }
            communication.RefreshScriptResults()
        end
    end

    -- List of allowed uploaders
    local allowedUploaders = {
        ["/user/FitGirl/"] = true,
        ["/user/DODI/"] = true,
        ["/user/johncena141/"] = true,
        ["/user/KaOsKrew/"] = true
    }

    local function request1337x()
        if cfCookies1337x == nil or cfCookies1337x == "" then
            http.CloudFlareSolver("https://".. searchprovider)
            return
        end
        
        local gamename = game.getgamename()
        if not gamename then
            return
        end

        if romantonormalnumbers then
            gamename = substituteRomanNumerals(gamename)
        end

        -- Updated search URL format
        local urlrequest = "https://" .. searchprovider .. "/category-search/" .. tostring(gamename):gsub(" ", "+") .. "/Games/1/"
        local htmlContent = http.get(urlrequest, headers)

        if not htmlContent then
            return
        end

        local results = {}
        
        -- Parse each torrent result
        local currentPos = 1
        while true do
            -- Find the next torrent row
            local rowStart = htmlContent:find('<tr>', currentPos)
            if not rowStart then break end
            
            local rowEnd = htmlContent:find('</tr>', rowStart)
            if not rowEnd then break end
            
            local rowContent = htmlContent:sub(rowStart, rowEnd)
            currentPos = rowEnd
            
            -- Check if this row has the specific uploader cell
            local uploaderFound = false
            local tdStart = rowContent:find('<td class="coll%-5 vip">')
            if tdStart then
                local tdEnd = rowContent:find('</td>', tdStart)
                if tdEnd then
                    local tdContent = rowContent:sub(tdStart, tdEnd)
                    
                    -- Check if this specific cell contains an allowed uploader
                    for uploaderPattern, _ in pairs(allowedUploaders) do
                        if tdContent:find(uploaderPattern) then
                            uploaderFound = true
                            break
                        end
                    end
                end
            end
            
            if uploaderFound then
                -- Extract torrent link
                local torrentLink = rowContent:match(regex)
                if torrentLink then
                    local url = "https://" .. searchprovider .. torrentLink
                    
                    local torrentName = url:match("/([^/]+)/$")
                    if torrentName then
                        local htmlContent2 = http.get(url, headers)
                        
                        if htmlContent2 then
                            local searchResult = {
                                name = torrentName,
                                links = {},
                                ScriptName = "1337x"
                            }
                            
                            for magnetMatch in htmlContent2:gmatch(magnetRegex) do
                                searchResult.links[#searchResult.links + 1] = {
                                    name = "Download",
                                    link = magnetMatch,
                                    addtodownloadlist = true
                                }
                                break
                            end
                            
                            if next(searchResult.links) == nil then
                                searchResult.links[#searchResult.links + 1] = {
                                    name = "Download",
                                    link = url
                                }
                            end
                            
                            results[#results + 1] = searchResult
                        end
                    end
                end
            end
        end

        if next(results) ~= nil then
            communication.receiveSearchResults(results)
        else
            Notifications.push("Results Search", "No results found from trusted uploaders.")
        end
    end

    client.add_callback("on_scriptselected", request1337x)
    client.add_callback("on_present", checkboxcall)
    client.add_callback("on_cfdone", cfcallback)
end
